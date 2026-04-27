from rest_framework import serializers
from .models import LegalCategory, Law, LawChapter, LawSection, LawArticle, CaseLegalReference, LegalArticleFlat, LegalProcedureNode
from lawsuits.serializers import LawsuitSerializer
from smartju.common_fields import LawsuitPrimaryKeyField


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
        fields = ('id', 'name', 'description', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class LawSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    
    class Meta:
        model = Law
        fields = ('id', 'category', 'category_name', 'name', 'issue_year', 'description', 'created_at', 'updated_at')
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
    lawsuit_detail = LawsuitSerializer(source='lawsuit', read_only=True)
    lawsuit_id = LawsuitPrimaryKeyField(
        source='lawsuit',
        write_only=True,
        required=False,
        allow_null=True
    )
    article_detail = LawArticleSerializer(source='article', read_only=True)
    
    class Meta:
        model = CaseLegalReference
        fields = (
            'id', 'lawsuit', 'lawsuit_detail', 'lawsuit_id',
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

