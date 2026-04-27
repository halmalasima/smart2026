from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MaxLengthValidator
from courts.models import Court


class Case(models.Model):
    """Case (قضية) - represents the main case file, separate from individual lawsuits/procedures."""

    # Case status choices
    STATUS_NEW = 'جديد'
    STATUS_UNDER_REVIEW = 'قيد_النظر'
    STATUS_COMPLETED = 'مكتمل'
    STATUS_CLOSED = 'مغلق'

    STATUS_CHOICES = [
        (STATUS_NEW, 'جديد'),
        (STATUS_UNDER_REVIEW, 'قيد النظر'),
        (STATUS_COMPLETED, 'مكتمل'),
        (STATUS_CLOSED, 'مغلق'),
    ]

    # Case type choices (main types only – subtypes stored as free text)
    CASE_TYPE_CIVIL = 'مدنية'
    CASE_TYPE_CRIMINAL = 'جزائية'
    CASE_TYPE_PERSONAL = 'شخصية'
    CASE_TYPE_ADMINISTRATIVE = 'إدارية'
    CASE_TYPE_COMMERCIAL = 'تجارية'
    CASE_TYPE_EXECUTION = 'تنفيذ'

    CASE_TYPE_CHOICES = [
        (CASE_TYPE_CIVIL, 'مدنية'),
        (CASE_TYPE_CRIMINAL, 'جزائية'),
        (CASE_TYPE_PERSONAL, 'شخصية'),
        (CASE_TYPE_ADMINISTRATIVE, 'إدارية'),
        (CASE_TYPE_COMMERCIAL, 'تجارية'),
        (CASE_TYPE_EXECUTION, 'تنفيذ'),
    ]

    case_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
        verbose_name='رقم القضية'
    )

    filing_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='تاريخ الورود'
    )

    gregorian_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='التاريخ الميلادي'
    )

    hijri_date = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='التاريخ الهجري'
    )

    case_year_hijri = models.PositiveSmallIntegerField(
        blank=True,
        null=True,
        verbose_name='سنة القضية (هجري)'
    )

    case_status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default=STATUS_NEW,
        verbose_name='حالة القضية'
    )

    case_type = models.CharField(
        max_length=50,
        choices=CASE_TYPE_CHOICES,
        default=CASE_TYPE_CIVIL,
        verbose_name='نوع القضية'
    )

    case_subtype = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='النوع الفرعي'
    )

    governorate = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='المحافظة'
    )

    court_fk = models.ForeignKey(
        Court,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cases',
        verbose_name='المحكمة'
    )

    court = models.CharField(
        max_length=200,
        blank=True,
        null=True,
        verbose_name='المحكمة (نص)'
    )

    subject = models.CharField(
        max_length=150,
        validators=[MaxLengthValidator(150)],
        verbose_name='موضوع القضية'
    )

    description = models.TextField(
        blank=True,
        null=True,
        verbose_name='الوصف'
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_cases',
        verbose_name='أنشأ بواسطة'
    )

    client = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='client_cases',
        verbose_name='الموكل'
    )

    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='تاريخ التحديث')

    class Meta:
        verbose_name = 'قضية'
        verbose_name_plural = 'قضايا'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['case_number']),
            models.Index(fields=['case_status']),
            models.Index(fields=['governorate']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f'{self.case_number} - {self.subject}'


class CaseParty(models.Model):
    """Party in a case – الطرف في القضية (موكل أو خصم، شخص أو مؤسسة)"""

    ROLE_CLIENT = 'client'
    ROLE_OPPONENT = 'opponent'
    ROLE_CHOICES = [
        (ROLE_CLIENT, 'موكل (طرف أول)'),
        (ROLE_OPPONENT, 'خصم (طرف ثاني)'),
    ]

    ENTITY_PERSON = 'person'
    ENTITY_ORGANIZATION = 'organization'
    ENTITY_CHOICES = [
        (ENTITY_PERSON, 'شخص'),
        (ENTITY_ORGANIZATION, 'مؤسسة / شركة'),
    ]

    case = models.ForeignKey(
        Case,
        on_delete=models.CASCADE,
        related_name='parties',
        verbose_name='القضية'
    )

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, verbose_name='الدور')
    entity_type = models.CharField(max_length=20, choices=ENTITY_CHOICES, default=ENTITY_PERSON, verbose_name='نوع الطرف')

    name = models.CharField(max_length=200, verbose_name='الاسم')
    phone = models.CharField(max_length=20, blank=True, null=True, verbose_name='الهاتف')
    id_number = models.CharField(max_length=50, blank=True, null=True, verbose_name='رقم الهوية / السجل')
    id_issued_from = models.CharField(max_length=100, blank=True, null=True, verbose_name='جهة الإصدار')
    id_date = models.DateField(blank=True, null=True, verbose_name='تاريخ الإصدار')
    address = models.TextField(blank=True, null=True, verbose_name='العنوان')
    nationality = models.CharField(max_length=100, blank=True, null=True, verbose_name='الجنسية')

    # Auto-created user account (only for clients/الموكل)
    user_account = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='case_party_account',
        verbose_name='حساب المستخدم'
    )

    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإنشاء')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='تاريخ التحديث')

    class Meta:
        verbose_name = 'طرف القضية'
        verbose_name_plural = 'أطراف القضية'
        ordering = ['role', 'name']

    def __str__(self):
        return f'{self.get_role_display()} - {self.name}'


class LegalTemplate(models.Model):
    """
    Legal Template Model - stores default legal texts for different case types
    """
    
    # Case type choices (matching SQL file)
    CASE_TYPE_PAYMENT_ORDER = 'امر_اداء'
    CASE_TYPE_LAWSUIT = 'دعوى'
    CASE_TYPE_REPLY = 'رد_على_دعوى'
    CASE_TYPE_APPEAL = 'استئناف'
    CASE_TYPE_CHALLENGE = 'طعن'
    
    CASE_TYPE_CHOICES = [
        (CASE_TYPE_PAYMENT_ORDER, 'أمر أداء'),
        (CASE_TYPE_LAWSUIT, 'دعوى'),
        (CASE_TYPE_REPLY, 'رد على دعوى'),
        (CASE_TYPE_APPEAL, 'استئناف'),
        (CASE_TYPE_CHALLENGE, 'طعن'),
    ]
    
    case_type = models.CharField(
        max_length=50,
        choices=CASE_TYPE_CHOICES,
        verbose_name='نوع القضية'
    )
    
    section_key = models.CharField(
        max_length=50,
        verbose_name='مفتاح القسم'
    )
    
    section_title = models.CharField(
        max_length=100,
        verbose_name='عنوان القسم'
    )
    
    default_text = models.TextField(
        verbose_name='النص الافتراضي'
    )
    
    is_required = models.BooleanField(
        default=True,
        verbose_name='إجباري'
    )
    
    class Meta:
        verbose_name = 'نص قانوني'
        verbose_name_plural = 'نصوص قانونية'
        unique_together = [['case_type', 'section_key']]
        indexes = [
            models.Index(fields=['case_type']),
            models.Index(fields=['section_key']),
        ]
    
    def __str__(self):
        return f'{self.get_case_type_display()} - {self.section_title}'


class Lawsuit(models.Model):
    """
    Lawsuit Model - represents a legal case
    Updated to support new case types from SQL file
    """
    
    # Case status choices (updated to match SQL)
    STATUS_NEW = 'جديد'
    STATUS_UNDER_REVIEW = 'قيد_النظر'
    STATUS_COMPLETED = 'مكتمل'
    STATUS_CLOSED = 'مغلق'
    
    STATUS_CHOICES = [
        (STATUS_NEW, 'جديد'),
        (STATUS_UNDER_REVIEW, 'قيد النظر'),
        (STATUS_COMPLETED, 'مكتمل'),
        (STATUS_CLOSED, 'مغلق'),
    ]
    
    # Case type choices (updated to match SQL file)
    CASE_TYPE_PAYMENT_ORDER = 'امر_اداء'
    CASE_TYPE_LAWSUIT = 'دعوى'
    CASE_TYPE_REPLY = 'رد_على_دعوى'
    CASE_TYPE_APPEAL = 'استئناف'
    CASE_TYPE_CHALLENGE = 'طعن'
    
    # Legacy case types (keeping for backward compatibility)
    CASE_TYPE_CIVIL = 'civil'
    CASE_TYPE_COMMERCIAL = 'commercial'
    CASE_TYPE_CRIMINAL = 'criminal'
    CASE_TYPE_PERSONAL_STATUS = 'personal_status'
    CASE_TYPE_LABOR = 'labor'
    CASE_TYPE_ADMINISTRATIVE = 'administrative'
    CASE_TYPE_OTHER = 'other'
    
    CASE_TYPE_CHOICES = [
        # New types from SQL
        (CASE_TYPE_PAYMENT_ORDER, 'أمر أداء'),
        (CASE_TYPE_LAWSUIT, 'دعوى'),
        (CASE_TYPE_REPLY, 'رد على دعوى'),
        (CASE_TYPE_APPEAL, 'استئناف'),
        (CASE_TYPE_CHALLENGE, 'طعن'),
        # Legacy types
        (CASE_TYPE_CIVIL, 'مدني'),
        (CASE_TYPE_COMMERCIAL, 'تجاري'),
        (CASE_TYPE_CRIMINAL, 'جنائي'),
        (CASE_TYPE_PERSONAL_STATUS, 'أحوال شخصية'),
        (CASE_TYPE_LABOR, 'عمل'),
        (CASE_TYPE_ADMINISTRATIVE, 'إداري'),
        (CASE_TYPE_OTHER, 'أخرى'),
    ]
    
    # Case number - unique identifier
    case_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
        verbose_name='رقم الدعوى'
    )

    case = models.ForeignKey(
        Case,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='lawsuits',
        verbose_name='القضية'
    )
    
    # Filing date (from SQL: submit_date_gregorian)
    filing_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='تاريخ رفع الدعوى'
    )
    
    # Dates (legacy fields - keeping for backward compatibility)
    gregorian_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='التاريخ الميلادي'
    )
    
    hijri_date = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='التاريخ الهجري'
    )

    case_year_hijri = models.PositiveSmallIntegerField(
        blank=True,
        null=True,
        verbose_name='سنة القضية (هجري)'
    )
    
    # Case type
    case_type = models.CharField(
        max_length=50,
        choices=CASE_TYPE_CHOICES,
        default=CASE_TYPE_LAWSUIT,
        verbose_name='نوع الدعوى'
    )

    case_subtype = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='النوع الفرعي'
    )
    
    # Case status
    case_status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default=STATUS_NEW,
        verbose_name='حالة القضية'
    )
    
    # Governorate (from SQL)
    governorate = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='المحافظة'
    )
    
    # Court - ForeignKey to Court model (new)
    court_fk = models.ForeignKey(
        Court,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='lawsuits',
        verbose_name='المحكمة'
    )
    
    # Court - CharField (legacy - for backward compatibility)
    court = models.CharField(
        max_length=200,
        blank=True,
        null=True,
        verbose_name='المحكمة (نص)'
    )
    
    # Subject - limited to 150 characters
    subject = models.CharField(
        max_length=150,
        validators=[MaxLengthValidator(150)],
        verbose_name='موضوع الدعوى'
    )
    
    # Description (from SQL: can be used for general description)
    description = models.TextField(
        blank=True,
        null=True,
        verbose_name='الوصف'
    )
    
    # Case facts (from SQL: Lawsuit_Facts.Facts)
    facts = models.TextField(
        blank=True,
        null=True,
        verbose_name='وقائع الدعوى'
    )
    
    # Legal basis (from SQL: Lawsuit_Facts.LegalBasis)
    legal_basis = models.TextField(
        blank=True,
        null=True,
        verbose_name='الأساس القانوني'
    )
    
    # Legal reasons (from SQL: legal_reasons)
    legal_reasons = models.TextField(
        blank=True,
        null=True,
        verbose_name='الأسباب القانونية'
    )
    
    # Reasons and legal basis (legacy field)
    reasons = models.TextField(
        blank=True,
        null=True,
        verbose_name='الأسباب والأسانيد'
    )
    
    # Requests
    requests = models.TextField(
        blank=True,
        null=True,
        verbose_name='الطلبات'
    )
    
    # Status (legacy - keeping for backward compatibility)
    status = models.CharField(
        max_length=50,
        choices=[
            ('pending', 'قيد الانتظار'),
            ('in_progress', 'قيد النظر'),
            ('under_review', 'قيد المراجعة'),
            ('judged', 'تم الحكم'),
            ('appealed', 'تم الطعن'),
            ('closed', 'مغلقة'),
        ],
        default='pending',
        verbose_name='الحالة (قديم)'
    )
    
    # Notes (from SQL)
    notes = models.TextField(
        blank=True,
        null=True,
        verbose_name='ملاحظات'
    )
    
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_lawsuits',
        verbose_name='منشئ الدعوى'
    )
    
    # Client - the person who owns the case
    client = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='owned_lawsuits',
        verbose_name='الموكل'
    )
    
    # ========== Archive Lifecycle Fields ==========
    
    # Archive status
    ARCHIVE_ACTIVE = 'active'
    ARCHIVE_SEMI_ACTIVE = 'semi_active'
    ARCHIVE_ARCHIVED = 'archived'
    
    ARCHIVE_STATUS_CHOICES = [
        (ARCHIVE_ACTIVE, 'نشط'),
        (ARCHIVE_SEMI_ACTIVE, 'شبه نشط'),
        (ARCHIVE_ARCHIVED, 'محفوظ'),
    ]
    
    archive_status = models.CharField(
        max_length=20,
        choices=ARCHIVE_STATUS_CHOICES,
        default=ARCHIVE_ACTIVE,
        verbose_name='حالة الأرشفة'
    )
    
    archive_date = models.DateTimeField(
        blank=True,
        null=True,
        verbose_name='تاريخ الأرشفة'
    )
    
    archive_reason = models.TextField(
        blank=True,
        null=True,
        verbose_name='سبب الأرشفة'
    )
    
    archived_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='archived_lawsuits',
        verbose_name='أرشف بواسطة'
    )
    
    # Soft delete
    is_deleted = models.BooleanField(
        default=False,
        verbose_name='محذوف'
    )
    
    deleted_at = models.DateTimeField(
        blank=True,
        null=True,
        verbose_name='تاريخ الحذف'
    )
    
    # Related lawsuit (for appeals/challenges linking)
    parent_lawsuit = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='child_lawsuits',
        verbose_name='الدعوى الأصلية'
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    class Meta:
        verbose_name = 'دعوى'
        verbose_name_plural = 'دعاوى'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['case_number']),
            models.Index(fields=['case_status']),
            models.Index(fields=['status']),
            models.Index(fields=['case_type']),
            models.Index(fields=['created_at']),
            models.Index(fields=['filing_date']),
            models.Index(fields=['court_fk']),
            models.Index(fields=['created_by']),
            models.Index(fields=['archive_status']),
            models.Index(fields=['is_deleted']),
            models.Index(fields=['parent_lawsuit']),
        ]
    
    # Mapping between case_status (Arabic) and status (English/legacy)
    _STATUS_AR_TO_EN = {
        'جديد': 'pending',
        'قيد_النظر': 'in_progress',
        'مكتمل': 'closed',
        'مغلق': 'closed',
    }
    _STATUS_EN_TO_AR = {
        'pending': 'جديد',
        'in_progress': 'قيد_النظر',
        'under_review': 'قيد_النظر',
        'judged': 'مكتمل',
        'appealed': 'قيد_النظر',
        'closed': 'مغلق',
    }

    def save(self, *args, **kwargs):
        # Sync case_status → status when case_status is explicitly set
        if self.case_status and self.case_status in self._STATUS_AR_TO_EN:
            expected_en = self._STATUS_AR_TO_EN[self.case_status]
            if self.status != expected_en:
                self.status = expected_en
        # Sync status → case_status when status is explicitly set but case_status is default
        elif self.status and self.status in self._STATUS_EN_TO_AR:
            expected_ar = self._STATUS_EN_TO_AR[self.status]
            if self.case_status != expected_ar:
                self.case_status = expected_ar

        # Sync court CharField from court_fk (keep legacy field in sync)
        if self.court_fk_id and self.court_fk:
            court_name = str(self.court_fk)
            if self.court != court_name:
                self.court = court_name

        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.case_number} - {self.subject}'


class FinancialClaim(models.Model):
    """
    Financial Claim Model - stores financial claims for lawsuits
    """
    
    CURRENCY_YER = 'YER'
    CURRENCY_USD = 'USD'
    CURRENCY_SAR = 'SAR'
    CURRENCY_EGP = 'EGP'
    
    CURRENCY_CHOICES = [
        (CURRENCY_YER, 'ريال يمني'),
        (CURRENCY_USD, 'دولار أمريكي'),
        (CURRENCY_SAR, 'ريال سعودي'),
        (CURRENCY_EGP, 'جنيه مصري'),
    ]
    
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='financial_claims',
        verbose_name='الدعوى'
    )
    
    amount = models.DecimalField(
        max_digits=18,
        decimal_places=2,
        blank=True,
        null=True,
        verbose_name='المبلغ'
    )
    
    currency = models.CharField(
        max_length=3,
        choices=CURRENCY_CHOICES,
        default=CURRENCY_YER,
        verbose_name='العملة'
    )
    
    due_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='تاريخ الاستحقاق'
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
    
    class Meta:
        verbose_name = 'مطالبة مالية'
        verbose_name_plural = 'مطالبات مالية'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['amount']),
        ]
    
    def __str__(self):
        return f'{self.lawsuit.case_number} - {self.amount} {self.get_currency_display()}'


# Import CaseFileItem so Django discovers it
from .models_casefile import CaseFileItem  # noqa: E402, F401
