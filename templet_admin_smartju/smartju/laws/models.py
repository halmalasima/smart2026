from django.db import models
from lawsuits.models import Lawsuit


class LegalCategory(models.Model):
    """
    Legal Category Model - الفئات القانونية
    """
    name = models.CharField(
        max_length=150,
        unique=True,
        verbose_name='اسم الفئة'
    )
    
    description = models.TextField(
        blank=True,
        null=True,
        verbose_name='الوصف'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'فئة قانونية'
        verbose_name_plural = 'فئات قانونية'
        ordering = ['name']
        indexes = [
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        return self.name


class Law(models.Model):
    """
    Law Model - القوانين
    """
    category = models.ForeignKey(
        LegalCategory,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='laws',
        verbose_name='الفئة'
    )
    
    name = models.CharField(
        max_length=300,
        verbose_name='اسم القانون'
    )
    
    issue_year = models.IntegerField(
        blank=True,
        null=True,
        verbose_name='سنة الإصدار'
    )
    
    description = models.TextField(
        blank=True,
        null=True,
        verbose_name='الوصف'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'قانون'
        verbose_name_plural = 'قوانين'
        ordering = ['category', 'issue_year', 'name']
        indexes = [
            models.Index(fields=['category']),
            models.Index(fields=['issue_year']),
            models.Index(fields=['name']),
        ]
    
    def __str__(self):
        year = f' ({self.issue_year})' if self.issue_year else ''
        return f'{self.name}{year}'


class LawChapter(models.Model):
    """
    Law Chapter Model - فصول القوانين
    """
    law = models.ForeignKey(
        Law,
        on_delete=models.CASCADE,
        related_name='chapters',
        verbose_name='القانون'
    )
    
    title = models.CharField(
        max_length=300,
        verbose_name='عنوان الفصل'
    )
    
    chapter_number = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='رقم الفصل'
    )
    
    order = models.PositiveIntegerField(
        default=0,
        verbose_name='الترتيب'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'فصل قانون'
        verbose_name_plural = 'فصول القوانين'
        ordering = ['law', 'order', 'chapter_number']
        indexes = [
            models.Index(fields=['law']),
            models.Index(fields=['order']),
        ]
    
    def __str__(self):
        return f'{self.law.name} - {self.title}'


class LawSection(models.Model):
    """
    Law Section Model - أقسام القوانين
    """
    chapter = models.ForeignKey(
        LawChapter,
        on_delete=models.CASCADE,
        related_name='sections',
        verbose_name='الفصل'
    )
    
    title = models.CharField(
        max_length=300,
        verbose_name='عنوان القسم'
    )
    
    section_number = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='رقم القسم'
    )
    
    order = models.PositiveIntegerField(
        default=0,
        verbose_name='الترتيب'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'قسم قانون'
        verbose_name_plural = 'أقسام القوانين'
        ordering = ['chapter', 'order', 'section_number']
        indexes = [
            models.Index(fields=['chapter']),
            models.Index(fields=['order']),
        ]
    
    def __str__(self):
        return f'{self.chapter.title} - {self.title}'


class LawArticle(models.Model):
    """
    Law Article Model - مواد القوانين
    """
    section = models.ForeignKey(
        LawSection,
        on_delete=models.CASCADE,
        related_name='articles',
        verbose_name='القسم'
    )
    
    article_number = models.CharField(
        max_length=50,
        verbose_name='رقم المادة'
    )
    
    article_text = models.TextField(
        verbose_name='نص المادة'
    )
    
    order = models.PositiveIntegerField(
        default=0,
        verbose_name='الترتيب'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'مادة قانون'
        verbose_name_plural = 'مواد القوانين'
        ordering = ['section', 'order', 'article_number']
        indexes = [
            models.Index(fields=['section']),
            models.Index(fields=['article_number']),
            models.Index(fields=['order']),
        ]
        unique_together = [['section', 'article_number']]
    
    def __str__(self):
        return f'مادة {self.article_number} - {self.section.title}'


class CaseLegalReference(models.Model):
    """
    Case Legal Reference Model - المراجع القانونية للدعاوى
    """
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='legal_references',
        verbose_name='الدعوى'
    )
    
    article = models.ForeignKey(
        LawArticle,
        on_delete=models.CASCADE,
        related_name='case_references',
        verbose_name='المادة القانونية'
    )
    
    confidence_score = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        blank=True,
        null=True,
        verbose_name='نقاط الثقة'
    )
    
    is_ai = models.BooleanField(
        default=False,
        verbose_name='من AI'
    )
    
    notes = models.TextField(
        blank=True,
        null=True,
        verbose_name='ملاحظات'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'مرجع قانوني'
        verbose_name_plural = 'مراجع قانونية'
        ordering = ['-confidence_score', '-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['article']),
            models.Index(fields=['confidence_score']),
            models.Index(fields=['is_ai']),
        ]
    
    def __str__(self):
        return f'{self.lawsuit.case_number} - {self.article.article_number}'


class LegalArticleFlat(models.Model):
    """
    Flat Legal Articles model - نسخة مسطحة من المواد القانونية للبحث السريع
    """
    source_title = models.CharField(max_length=255, verbose_name='المصدر')
    book_title = models.CharField(max_length=255, blank=True, null=True, verbose_name='الكتاب')
    section_title = models.CharField(max_length=255, blank=True, null=True, verbose_name='القسم')
    chapter_title = models.CharField(max_length=255, blank=True, null=True, verbose_name='الفصل')
    branch_title = models.CharField(max_length=255, blank=True, null=True, verbose_name='الفرع')
    article_number = models.CharField(max_length=50, verbose_name='رقم المادة')
    article_text = models.TextField(verbose_name='نص المادة')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإضافة')

    class Meta:
        verbose_name = 'مادة قانونية (مسطحة)'
        verbose_name_plural = 'مواد قانونية (مسطحة)'
        db_table = 'legal_articles'  # التزاماً بالاسم المطلوب من المستخدم

    def __str__(self):
        return f"{self.source_title} - مادة {self.article_number}"

class LegalProcedureNode(models.Model):
    """
    Legal Procedure Node Model - عقد دليل الإجراءات
    Matches structure of book_nodes table in old DB
    """
    id = models.BigIntegerField(primary_key=True, verbose_name='المعرف')
    source_title = models.CharField(max_length=255, verbose_name='عنوان المصدر')
    level = models.CharField(max_length=50, verbose_name='المستوى')
    title = models.TextField(verbose_name='العنوان')
    body = models.TextField(verbose_name='المحتوى', blank=True, null=True)
    parent_id = models.BigIntegerField(null=True, blank=True, verbose_name='رقم الأب')
    page_from = models.IntegerField(null=True, blank=True, verbose_name='من صفحة')
    page_to = models.IntegerField(null=True, blank=True, verbose_name='إلى صفحة')

    class Meta:
        db_table = 'book_nodes'
        verbose_name = 'بند دليل الإجراءات'
        verbose_name_plural = 'بنود دليل الإجراءات'
        indexes = [
            models.Index(fields=['title']),
            # models.Index(fields=['body']), # Text fields indexing depends on DB backend
        ]

    def __str__(self):
        return self.title[:50]
