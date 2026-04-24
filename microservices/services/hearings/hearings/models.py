from django.db import models
from django.contrib.auth.models import User


class Hearing(models.Model):
    """
    Hearing Model - represents court hearings/sessions
    """
    
    # Cross-service reference — stored as plain integer (no DB-level FK)
    lawsuit_id = models.BigIntegerField(
        db_index=True,
        verbose_name='رقم معرف الدعوى'
    )
    lawsuit_case_number = models.CharField(
        max_length=100,
        blank=True,
        default='',
        verbose_name='رقم ملف القضية'
    )
    
    # Hearing date
    hearing_date = models.DateField(
        verbose_name='تاريخ الجلسة'
    )
    
    # Hijri date (optional)
    hijri_date = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='التاريخ الهجري'
    )
    
    # Hearing time (optional)
    hearing_time = models.TimeField(
        blank=True,
        null=True,
        verbose_name='وقت الجلسة'
    )
    
    # Notes/remarks
    notes = models.TextField(
        verbose_name='ملاحظات الجلسة'
    )
    
    # Judge name (optional)
    judge_name = models.CharField(
        max_length=200,
        blank=True,
        null=True,
        verbose_name='اسم القاضي'
    )
    
    # ForeignKey to User (judge - optional)
    judge = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='presided_hearings',
        verbose_name='القاضي'
    )
    
    # Cross-service reference to Case (optional)
    case_id = models.BigIntegerField(
        null=True,
        blank=True,
        db_index=True,
        verbose_name='رقم معرف القضية'
    )

    # Hearing type/status (optional)
    HEARING_TYPE_PRELIMINARY = 'preliminary'
    HEARING_TYPE_MAIN = 'main'
    HEARING_TYPE_DECISION = 'decision'
    HEARING_TYPE_ADJOURNED = 'adjourned'
    HEARING_TYPE_OTHER = 'other'
    
    HEARING_TYPE_CHOICES = [
        (HEARING_TYPE_PRELIMINARY, 'تمهيدية'),
        (HEARING_TYPE_MAIN, 'رئيسية'),
        (HEARING_TYPE_DECISION, 'قرار'),
        (HEARING_TYPE_ADJOURNED, 'مؤجلة'),
        (HEARING_TYPE_OTHER, 'أخرى'),
    ]
    
    hearing_type = models.CharField(
        max_length=50,
        choices=HEARING_TYPE_CHOICES,
        default=HEARING_TYPE_MAIN,
        verbose_name='نوع الجلسة'
    )

    # Session management fields
    SESSION_TYPE_UPCOMING = 'upcoming'
    SESSION_TYPE_PREVIOUS = 'previous'

    SESSION_TYPE_CHOICES = [
        (SESSION_TYPE_UPCOMING, 'قادمة'),
        (SESSION_TYPE_PREVIOUS, 'سابقة'),
    ]

    session_type = models.CharField(
        max_length=20,
        choices=SESSION_TYPE_CHOICES,
        default=SESSION_TYPE_UPCOMING,
        verbose_name='نوع الجلسة (قادمة/سابقة)'
    )

    TIME_OF_DAY_MORNING = 'morning'
    TIME_OF_DAY_EVENING = 'evening'

    TIME_OF_DAY_CHOICES = [
        (TIME_OF_DAY_MORNING, 'صباحية'),
        (TIME_OF_DAY_EVENING, 'مسائية'),
    ]

    time_of_day = models.CharField(
        max_length=20,
        choices=TIME_OF_DAY_CHOICES,
        default=TIME_OF_DAY_MORNING,
        blank=True,
        verbose_name='فترة الجلسة'
    )

    requirements = models.TextField(
        blank=True,
        default='',
        verbose_name='المطلوب في الجلسة'
    )

    court_decision = models.TextField(
        blank=True,
        null=True,
        verbose_name='قرار المحكمة'
    )

    next_session_date = models.DateField(
        blank=True,
        null=True,
        verbose_name='موعد الجلسة القادمة'
    )
    
    # Created by
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_hearings',
        verbose_name='منشئ السجل'
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
        related_name='archived_hearings',
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
    
    class Meta:
        verbose_name = 'جلسة'
        verbose_name_plural = 'جلسات'
        ordering = ['-hearing_date', '-hearing_time']
        indexes = [
            models.Index(fields=['lawsuit_id']),
            models.Index(fields=['case_id']),
            models.Index(fields=['hearing_date']),
            models.Index(fields=['hearing_type']),
            models.Index(fields=['session_type']),
            models.Index(fields=['judge']),
            models.Index(fields=['archive_status']),
            models.Index(fields=['is_deleted']),
        ]
    
    def __str__(self):
        return f'جلسة - {self.lawsuit_case_number or self.lawsuit_id} - {self.hearing_date}'
