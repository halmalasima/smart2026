from rest_framework import serializers
from .models import LegalCategory, Law, LawChapter, LawSection, LawArticle, CaseLegalReference, LegalArticleFlat, LegalProcedureNode, LawLibrary, Tag


class LegalArticleFlatSerializer(serializers.ModelSerializer):
    """
    Serializer للمواد القانونية المسطحة - للبحث السريع
    """
    class Meta:
        model = LegalArticleFlat
        fields = (
            'id', 'source_title', 'book_title', 'section_title',
            'chapter_title', 'branch_title', 'article_number',
            'article_text', 'created_at'
        )
        read_only_fields = ('id', 'created_at')


class LegalArticleFlatListSerializer(serializers.ModelSerializer):
    """
    Serializer مختصر للقوائم - بدون نص المادة الكامل
    """
    article_text_preview = serializers.SerializerMethodField()
    
    class Meta:
        model = LegalArticleFlat
        fields = (
            'id', 'source_title', 'book_title', 'section_title',
            'chapter_title', 'branch_title', 'article_number',
            'article_text_preview', 'created_at'
        )
        read_only_fields = ('id', 'created_at')
    
    def get_article_text_preview(self, obj):
        """إرجاع أول 200 حرف من نص المادة"""
        if obj.article_text:
            return obj.article_text[:200] + ('...' if len(obj.article_text) > 200 else '')
        return ''


class LegalCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = LegalCategory
        fields = ('id', 'name', 'slug', 'description', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ('id', 'name', 'slug', 'created_at')
        read_only_fields = ('id', 'created_at')


class LawSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_slug = serializers.CharField(source='category.slug', read_only=True)
    tags_list = serializers.StringRelatedField(source='tags', many=True, read_only=True)
    
    class Meta:
        model = Law
        fields = (
            'id', 'category', 'category_name', 'category_slug', 
            'name', 'slug', 'issue_year', 'description', 
            'source_url', 'pdf_link', 'tags', 'tags_list', 
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class LawChapterSerializer(serializers.ModelSerializer):
    law_name = serializers.CharField(source='law.name', read_only=True)
    
    class Meta:
        model = LawChapter
        fields = ('id', 'law', 'law_name', 'title', 'chapter_number', 'order', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class LawSectionSerializer(serializers.ModelSerializer):
    chapter_title = serializers.CharField(source='chapter.title', read_only=True)
    law_name = serializers.CharField(source='chapter.law.name', read_only=True)
    
    class Meta:
        model = LawSection
        fields = ('id', 'chapter', 'chapter_title', 'law_name', 'title', 'section_number', 'order', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class LawArticleSerializer(serializers.ModelSerializer):
    section_title = serializers.CharField(source='section.title', read_only=True)
    law_name = serializers.CharField(source='section.chapter.law.name', read_only=True)
    
    class Meta:
        model = LawArticle
        fields = ('id', 'section', 'section_title', 'law_name', 'article_number', 'article_text', 'order', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class CaseLegalReferenceSerializer(serializers.ModelSerializer):
    article_detail = LawArticleSerializer(source='article', read_only=True)

    class Meta:
        model = CaseLegalReference
        fields = (
            'id', 'lawsuit_id', 'lawsuit_case_number',
            'article', 'article_detail',
            'confidence_score', 'is_ai', 'notes',
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class LegalProcedureNodeSerializer(serializers.ModelSerializer):
    """
    Serializer لدليل الإجراءات
    """
    class Meta:
        model = LegalProcedureNode
        fields = '__all__'


class LawLibrarySerializer(serializers.ModelSerializer):
    """
    Serializer للمكتبة القانونية (كتب) - محول لنموذج Law للحفاظ على التوافقية
    """
    title = serializers.CharField(source='name', read_only=True)
    category = serializers.CharField(source='category.name', read_only=True)
    pdf_url = serializers.URLField(source='pdf_link', read_only=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Law
        fields = ('id', 'title', 'category', 'source_url', 'pdf_url', 'image_url', 'created_at')
        
    def get_image_url(self, obj):
        return None
