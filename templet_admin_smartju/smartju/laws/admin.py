from django.contrib import admin
from .models import LegalCategory, Law, LawChapter, LawSection, LawArticle, CaseLegalReference, LegalArticleFlat


@admin.register(LegalCategory)
class LegalCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at')
    search_fields = ('name',)
    ordering = ('name',)


@admin.register(Law)
class LawAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'issue_year', 'created_at')
    list_filter = ('category', 'issue_year')
    search_fields = ('name',)
    ordering = ('category', 'issue_year', 'name')


@admin.register(LawChapter)
class LawChapterAdmin(admin.ModelAdmin):
    list_display = ('title', 'law', 'chapter_number', 'order')
    list_filter = ('law',)
    search_fields = ('title', 'law__name')
    ordering = ('law', 'order')


@admin.register(LawSection)
class LawSectionAdmin(admin.ModelAdmin):
    list_display = ('title', 'chapter', 'section_number', 'order')
    list_filter = ('chapter__law',)
    search_fields = ('title',)
    ordering = ('chapter', 'order')


@admin.register(LawArticle)
class LawArticleAdmin(admin.ModelAdmin):
    list_display = ('article_number', 'section', 'order')
    list_filter = ('section__chapter__law',)
    search_fields = ('article_number', 'article_text')
    ordering = ('section', 'order')


@admin.register(CaseLegalReference)
class CaseLegalReferenceAdmin(admin.ModelAdmin):
    list_display = ('lawsuit', 'article', 'confidence_score', 'is_ai', 'created_at')
    list_filter = ('is_ai', 'article__section__chapter__law')
    search_fields = ('lawsuit__case_number', 'article__article_number')
    ordering = ('-confidence_score', '-created_at')


@admin.register(LegalArticleFlat)
class LegalArticleFlatAdmin(admin.ModelAdmin):
    list_display = ('article_number', 'source_title', 'book_title', 'section_title', 'created_at')
    list_filter = ('source_title', 'book_title')
    search_fields = ('source_title', 'article_number', 'article_text')
    ordering = ('source_title', 'article_number')
