from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.db.models import Q, Count
from django.db.models.functions import Length
from .models import LegalCategory, Law, LawChapter, LawSection, LawArticle, CaseLegalReference, LegalArticleFlat, LegalProcedureNode
from .serializers import (
    LegalCategorySerializer, LawSerializer, LawChapterSerializer,
    LawSectionSerializer, LawArticleSerializer, CaseLegalReferenceSerializer,
    LegalArticleFlatSerializer, LegalArticleFlatListSerializer, LegalProcedureNodeSerializer
)
import re


class LegalArticleFlatViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet للمكتبة القانونية مع Full-Text Search متقدم
    
    يدعم:
    - البحث في نص المادة ورقمها
    - الفلترة حسب المصدر/الكتاب/القسم/الفصل/الفرع
    - ترتيب النتائج
    - الحصول على قائمة المصادر المتاحة
    """
    queryset = LegalArticleFlat.objects.all()
    permission_classes = [AllowAny]  # السماح بالوصول العام للمكتبة القانونية
    
    def get_serializer_class(self):
        """استخدام serializer مختصر للقوائم وكامل للتفاصيل"""
        if self.action == 'list':
            return LegalArticleFlatListSerializer
        return LegalArticleFlatSerializer
    
    def get_queryset(self):
        """
        تطبيق Full-Text Search والفلترة
        """
        queryset = LegalArticleFlat.objects.all()
        
        # الحصول على معاملات البحث
        search_query = self.request.query_params.get('q', '').strip()
        source_title = self.request.query_params.get('source', '')
        book_title = self.request.query_params.get('book', '')
        section_title = self.request.query_params.get('section', '')
        chapter_title = self.request.query_params.get('chapter', '')
        branch_title = self.request.query_params.get('branch', '')
        article_number = self.request.query_params.get('article_number', '')
        
        # تطبيق Full-Text Search
        if search_query:
            # تقسيم الاستعلام إلى كلمات للبحث المتعدد
            search_terms = search_query.split()
            
            # بناء استعلام Q للبحث في جميع الكلمات
            query = Q()
            for term in search_terms:
                term_query = (
                    Q(article_text__icontains=term) |
                    Q(article_number__icontains=term) |
                    Q(source_title__icontains=term) |
                    Q(book_title__icontains=term) |
                    Q(section_title__icontains=term) |
                    Q(chapter_title__icontains=term) |
                    Q(branch_title__icontains=term)
                )
                query &= term_query
            
            queryset = queryset.filter(query)
        
        # تطبيق الفلاتر
        if source_title:
            queryset = queryset.filter(source_title__icontains=source_title)
        if book_title:
            queryset = queryset.filter(book_title__icontains=book_title)
        if section_title:
            queryset = queryset.filter(section_title__icontains=section_title)
        if chapter_title:
            queryset = queryset.filter(chapter_title__icontains=chapter_title)
        if branch_title:
            queryset = queryset.filter(branch_title__icontains=branch_title)
        if article_number:
            queryset = queryset.filter(article_number__icontains=article_number)
        
        # الترتيب
        ordering = self.request.query_params.get('ordering', 'source_title,article_number')
        if ordering:
            order_fields = [f.strip() for f in ordering.split(',') if f.strip()]
            if order_fields:
                queryset = queryset.order_by(*order_fields)
        
        return queryset
    
    @action(detail=False, methods=['get'])
    def sources(self, request):
        """
        الحصول على قائمة جميع المصادر القانونية المتاحة مع عدد المواد لكل منها
        """
        sources = LegalArticleFlat.objects.values('source_title').annotate(
            articles_count=Count('id')
        ).order_by('source_title')
        
        return Response({
            'count': len(sources),
            'sources': list(sources)
        })
    
    @action(detail=False, methods=['get'])
    def books(self, request):
        """
        الحصول على قائمة الكتب لمصدر معين
        """
        source = request.query_params.get('source', '')
        queryset = LegalArticleFlat.objects.all()
        
        if source:
            queryset = queryset.filter(source_title__icontains=source)
        
        books = queryset.exclude(book_title__isnull=True).exclude(book_title='').values(
            'source_title', 'book_title'
        ).annotate(
            articles_count=Count('id')
        ).order_by('source_title', 'book_title')
        
        return Response({
            'count': len(books),
            'books': list(books)
        })
    
    @action(detail=False, methods=['get'])
    def chapters(self, request):
        """
        الحصول على قائمة الفصول لمصدر/كتاب معين
        """
        source = request.query_params.get('source', '')
        book = request.query_params.get('book', '')
        queryset = LegalArticleFlat.objects.all()
        
        if source:
            queryset = queryset.filter(source_title__icontains=source)
        if book:
            queryset = queryset.filter(book_title__icontains=book)
        
        chapters = queryset.exclude(chapter_title__isnull=True).exclude(chapter_title='').values(
            'source_title', 'book_title', 'chapter_title'
        ).annotate(
            articles_count=Count('id')
        ).order_by('source_title', 'book_title', 'chapter_title')
        
        return Response({
            'count': len(chapters),
            'chapters': list(chapters)
        })
    
    @action(detail=False, methods=['get'])
    def search(self, request):
        """
        بحث متقدم مع تمييز النتائج (highlighting)
        """
        query = request.query_params.get('q', '').strip()
        
        if not query:
            return Response({
                'error': 'يجب توفير معامل البحث q',
                'example': '/api/legal-library/search/?q=المسؤولية الجزائية'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        queryset = self.get_queryset()
        
        # تقليل العدد للأداء
        results = queryset[:100]
        
        # تمييز النتائج
        highlighted_results = []
        search_terms = query.split()
        
        for article in results:
            result = LegalArticleFlatSerializer(article).data
            
            # تمييز الكلمات في نص المادة
            highlighted_text = article.article_text or ''
            for term in search_terms:
                pattern = re.compile(f'({re.escape(term)})', re.IGNORECASE)
                highlighted_text = pattern.sub(r'<mark>\1</mark>', highlighted_text)
            
            result['article_text_highlighted'] = highlighted_text
            highlighted_results.append(result)
        
        return Response({
            'query': query,
            'count': queryset.count(),
            'results_shown': len(highlighted_results),
            'results': highlighted_results
        })
    
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """
        إحصائيات المكتبة القانونية
        """
        total_articles = LegalArticleFlat.objects.count()
        sources_count = LegalArticleFlat.objects.values('source_title').distinct().count()
        
        # أكبر 10 مصادر
        top_sources = LegalArticleFlat.objects.values('source_title').annotate(
            count=Count('id')
        ).order_by('-count')[:10]
        
        return Response({
            'total_articles': total_articles,
            'total_sources': sources_count,
            'top_sources': list(top_sources)
        })


class LegalCategoryViewSet(viewsets.ModelViewSet):
    queryset = LegalCategory.objects.all()
    serializer_class = LegalCategorySerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = []
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']


class LawViewSet(viewsets.ModelViewSet):
    queryset = Law.objects.select_related('category').all()
    serializer_class = LawSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['category', 'issue_year']
    search_fields = ['name', 'description']
    ordering_fields = ['category', 'issue_year', 'name', 'created_at']
    ordering = ['category', 'issue_year', 'name']


class LawChapterViewSet(viewsets.ModelViewSet):
    queryset = LawChapter.objects.select_related('law').all()
    serializer_class = LawChapterSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['law']
    search_fields = ['title', 'law__name']
    ordering_fields = ['law', 'order', 'created_at']
    ordering = ['law', 'order']


class LawSectionViewSet(viewsets.ModelViewSet):
    queryset = LawSection.objects.select_related('chapter', 'chapter__law').all()
    serializer_class = LawSectionSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['chapter']
    search_fields = ['title']
    ordering_fields = ['chapter', 'order', 'created_at']
    ordering = ['chapter', 'order']


class LawArticleViewSet(viewsets.ModelViewSet):
    queryset = LawArticle.objects.select_related('section', 'section__chapter', 'section__chapter__law').all()
    serializer_class = LawArticleSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['section']
    search_fields = ['article_number', 'article_text']
    ordering_fields = ['section', 'order', 'article_number', 'created_at']
    ordering = ['section', 'order']


class CaseLegalReferenceViewSet(viewsets.ModelViewSet):
    queryset = CaseLegalReference.objects.select_related('lawsuit', 'article').all()
    serializer_class = CaseLegalReferenceSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['lawsuit', 'article', 'is_ai']
    search_fields = ['notes']
    ordering_fields = ['confidence_score', 'created_at']
    ordering = ['-confidence_score', '-created_at']


class LegalProcedureViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet لدليل الإجراءات (الكتب) مع دعم البحث المتقدم Full-Text Search
    """
    queryset = LegalProcedureNode.objects.all()
    serializer_class = LegalProcedureNodeSerializer
    permission_classes = [AllowAny]
    
    def get_queryset(self):
        queryset = LegalProcedureNode.objects.all()
        
        # Search parameters
        search_query = self.request.query_params.get('q', '').strip()
        level = self.request.query_params.get('level', '')
        source_title = self.request.query_params.get('source', '')
        parent_id = self.request.query_params.get('parent', '')
        
        # Full Text Search
        if search_query:
            search_terms = search_query.split()
            query = Q()
            for term in search_terms:
                term_query = (
                    Q(title__icontains=term) |
                    Q(body__icontains=term) |
                    Q(source_title__icontains=term)
                )
                query &= term_query
            queryset = queryset.filter(query)
            
        # Filters
        if level:
            queryset = queryset.filter(level=level)
        if source_title:
            queryset = queryset.filter(source_title=source_title)
        if parent_id:
            queryset = queryset.filter(parent_id=parent_id)
            
        return queryset

    @action(detail=False, methods=['get'])
    def sources(self, request):
        """
        Get unique sources list
        """
        sources = LegalProcedureNode.objects.values('source_title').annotate(
            count=Count('id')
        ).order_by('source_title').distinct()
        
        return Response({
            'count': len(sources),
            'sources': list(sources)
        })

    @action(detail=False, methods=['get'])
    def search(self, request):
        """
        Advanced Full Text Search with highlighting
        """
        query = request.query_params.get('q', '').strip()
        if not query:
            return Response({'error': 'Search query required'}, status=status.HTTP_400_BAD_REQUEST)
            
        queryset = self.get_queryset()
        results = queryset[:50] # Limit for performance
        
        highlighted_results = []
        search_terms = query.split()
        
        for item in results:
            data = LegalProcedureNodeSerializer(item).data
            
            # Highlight in body
            if item.body:
                highlighted_body = item.body
                for term in search_terms:
                    pattern = re.compile(f'({re.escape(term)})', re.IGNORECASE)
                    highlighted_body = pattern.sub(r'<mark>\1</mark>', highlighted_body)
                
                # Create a snippet around the match if body is long
                # Simple logic: find first match and take surrounding text
                match = re.search(r'<mark>', highlighted_body)
                if match:
                    start = max(0, match.start() - 100)
                    end = min(len(highlighted_body), match.end() + 300)
                    snippet = ('...' if start > 0 else '') + highlighted_body[start:end] + ('...' if end < len(highlighted_body) else '')
                    data['body_highlighted'] = snippet
                else:
                    data['body_highlighted'] = highlighted_body[:200]
            
            highlighted_results.append(data)
            
        return Response({
            'count': queryset.count(),
            'results': highlighted_results
        })
