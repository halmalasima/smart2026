from django.db import models
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit


class Appeal(models.Model):
    """
    Appeal Model - represents appeals against judgments
    """
    
    # Appeal type choices
    APPEAL_TYPE_PRIMARY = 'primary'
    APPEAL_TYPE_APPEAL = 'appeal'
    APPEAL_TYPE_CASSATION = 'cassation'
    APPEAL_TYPE_CONSTITUTIONAL = 'constitutional'
    APPEAL_TYPE_OTHER = 'other'
    
    APPEAL_TYPE_CHOICES = [
        (APPEAL_TYPE_PRIMARY, 'ابتدائي'),
        (APPEAL_TYPE_APPEAL, 'استئناف'),
        (APPEAL_TYPE_CASSATION, 'تمييز'),
        (APPEAL_TYPE_CONSTITUTIONAL, 'دستوري'),
        (APPEAL_TYPE_OTHER, 'أخرى'),
    ]
    
    # Appeal status choices
    STATUS_PENDING = 'pending'
    STATUS_UNDER_REVIEW = 'under_review'
    STATUS_ACCEPTED = 'accepted'
    STATUS_REJECTED = 'rejected'
    STATUS_WITHDRAWN = 'withdrawn'
    STATUS_CLOSED = 'closed'
    
    STATUS_CHOICES = [
        (STATUS_PENDING, 'قيد الانتظار'),
        (STATUS_UNDER_REVIEW, 'قيد المراجعة'),
        (STATUS_ACCEPTED, 'مقبول'),
        (STATUS_REJECTED, 'مرفوض'),
        (STATUS_WITHDRAWN, 'مسحوب'),
        (STATUS_CLOSED, 'مغلق'),
    ]
    
    # ForeignKey to Lawsuit
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='appeals',
        verbose_name='الدعوى'
    )
    
    # Appeal type
    appeal_type = models.CharField(
        max_length=50,
        choices=APPEAL_TYPE_CHOICES,
        default=APPEAL_TYPE_APPEAL,
        verbose_name='نوع الطعن'
    )
    
    # Appeal number
    appeal_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
        verbose_name='رقم الطعن'
    )
    
    # Appeal reasons/causes
    appeal_reasons = models.TextField(
        verbose_name='أسباب الطعن'
    )
    
    # Appeal requests
    appeal_requests = models.TextField(
        blank=True,
        null=True,
        verbose_name='طلبات الطعن'
    )
    
    # Higher court
    higher_court = models.CharField(
        max_length=200,
        verbose_name='المحكمة الأعلى'
    )
    
    # Status
    status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
        verbose_name='حالة الطعن'
    )
    
    # Dates
    appeal_date = models.DateField(
        verbose_name='تاريخ الطعن'
    )
    
    hijri_date = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='التاريخ الهجري'
    )
    
    # Submitted by
    submitted_by = models.CharField(
        max_length=200,
        verbose_name='مقدم الطعن'
    )
    
    # ForeignKey to User (optional)
    submitted_by_user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='submitted_appeals',
        verbose_name='المستخدم المقدم'
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
        verbose_name = 'طعن'
        verbose_name_plural = 'طعون'
        ordering = ['-appeal_date', '-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['appeal_number']),
            models.Index(fields=['appeal_type']),
            models.Index(fields=['status']),
            models.Index(fields=['appeal_date']),
        ]
    
    def __str__(self):
        return f'{self.appeal_number} - {self.lawsuit.case_number} - {self.get_appeal_type_display()}'
    
    def get_submitted_by_display(self):
        """
        Return submitted_by_user if available, otherwise return submitted_by text
        """
        if self.submitted_by_user:
            return self.submitted_by_user.get_full_name() or self.submitted_by_user.username
        return self.submitted_by
