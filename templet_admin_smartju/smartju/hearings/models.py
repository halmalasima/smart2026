from django.db import models
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit


class Hearing(models.Model):
    """
    Hearing Model - represents court hearings/sessions
    """
    
    # ForeignKey to Lawsuit
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='hearings',
        verbose_name='الدعوى'
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
            models.Index(fields=['lawsuit']),
            models.Index(fields=['hearing_date']),
            models.Index(fields=['hearing_type']),
            models.Index(fields=['judge']),
            models.Index(fields=['archive_status']),
            models.Index(fields=['is_deleted']),
        ]
    
    def __str__(self):
        return f'جلسة - {self.lawsuit.case_number} - {self.hearing_date}'
