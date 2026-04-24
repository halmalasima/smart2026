from django.db import models
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit


class Judgment(models.Model):
    """
    Judgment Model - represents court judgments/verdicts
    Supports multiple judgments for the same lawsuit
    """
    
    # Judgment type choices
    JUDGMENT_TYPE_PRIMARY = 'primary'
    JUDGMENT_TYPE_APPEAL = 'appeal'
    JUDGMENT_TYPE_FINAL = 'final'
    
    JUDGMENT_TYPE_CHOICES = [
        (JUDGMENT_TYPE_PRIMARY, 'ابتدائي'),
        (JUDGMENT_TYPE_APPEAL, 'استئناف'),
        (JUDGMENT_TYPE_FINAL, 'بات'),
    ]
    
    # ForeignKey to Lawsuit
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='judgments',
        verbose_name='الدعوى'
    )
    
    # Judgment type
    judgment_type = models.CharField(
        max_length=50,
        choices=JUDGMENT_TYPE_CHOICES,
        default=JUDGMENT_TYPE_PRIMARY,
        verbose_name='نوع الحكم'
    )
    
    # Judgment number
    judgment_number = models.CharField(
        max_length=100,
        verbose_name='رقم الحكم'
    )
    
    # Judgment date
    judgment_date = models.DateField(
        verbose_name='تاريخ الحكم'
    )
    
    # Hijri date (optional)
    hijri_date = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='التاريخ الهجري'
    )
    
    # Judgment text/content
    judgment_text = models.TextField(
        verbose_name='نص الحكم'
    )
    
    # Judgment summary (optional)
    summary = models.TextField(
        blank=True,
        null=True,
        verbose_name='ملخص الحكم'
    )
    
    # Judge name
    judge_name = models.CharField(
        max_length=200,
        verbose_name='اسم القاضي'
    )
    
    # ForeignKey to User (judge - optional)
    judge = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='issued_judgments',
        verbose_name='القاضي'
    )
    
    # Court name
    court_name = models.CharField(
        max_length=200,
        verbose_name='اسم المحكمة'
    )
    
    # Judgment status (optional)
    STATUS_PENDING = 'pending'
    STATUS_EXECUTABLE = 'executable'
    STATUS_APPEALED = 'appealed'
    STATUS_FINAL = 'final'
    STATUS_EXECUTED = 'executed'
    
    STATUS_CHOICES = [
        (STATUS_PENDING, 'قيد الانتظار'),
        (STATUS_EXECUTABLE, 'قابل للتنفيذ'),
        (STATUS_APPEALED, 'تم الطعن'),
        (STATUS_FINAL, 'بات'),
        (STATUS_EXECUTED, 'تم التنفيذ'),
    ]
    
    status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
        verbose_name='حالة الحكم'
    )
    
    # Created by
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_judgments',
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
    
    class Meta:
        verbose_name = 'حكم'
        verbose_name_plural = 'أحكام'
        ordering = ['-judgment_date', '-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['judgment_type']),
            models.Index(fields=['judgment_date']),
            models.Index(fields=['status']),
            models.Index(fields=['judge']),
        ]
        # Allow multiple judgments for the same lawsuit
        unique_together = [['lawsuit', 'judgment_number']]
    
    def __str__(self):
        return f'{self.judgment_number} - {self.lawsuit.case_number} - {self.get_judgment_type_display()}'
