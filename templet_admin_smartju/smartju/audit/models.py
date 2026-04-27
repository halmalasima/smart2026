from django.db import models
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit


class AuditLog(models.Model):
    """
    AuditLog Model - records all judicial actions automatically
    Non-editable log for tracking all actions in the system
    """
    
    # Action type choices
    ACTION_LAWSUIT_CREATED = 'lawsuit_created'
    ACTION_PARTY_ADDED = 'party_added'
    ACTION_ATTACHMENT_UPLOADED = 'attachment_uploaded'
    ACTION_RESPONSE_SUBMITTED = 'response_submitted'
    ACTION_APPEAL_FILED = 'appeal_filed'
    ACTION_JUDGMENT_ISSUED = 'judgment_issued'
    ACTION_HEARING_SCHEDULED = 'hearing_scheduled'
    ACTION_OTHER = 'other'
    
    ACTION_TYPE_CHOICES = [
        (ACTION_LAWSUIT_CREATED, 'إنشاء دعوى'),
        (ACTION_PARTY_ADDED, 'إضافة طرف'),
        (ACTION_ATTACHMENT_UPLOADED, 'رفع مرفق'),
        (ACTION_RESPONSE_SUBMITTED, 'تقديم رد'),
        (ACTION_APPEAL_FILED, 'تقديم طعن'),
        (ACTION_JUDGMENT_ISSUED, 'إصدار حكم'),
        (ACTION_HEARING_SCHEDULED, 'جدولة جلسة'),
        (ACTION_OTHER, 'أخرى'),
    ]
    
    # Action type
    action_type = models.CharField(
        max_length=50,
        choices=ACTION_TYPE_CHOICES,
        verbose_name='نوع الإجراء'
    )
    
    # ForeignKey to User (who performed the action)
    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='audit_logs',
        verbose_name='المستخدم'
    )
    
    # ForeignKey to Lawsuit (most actions are related to a lawsuit)
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='audit_logs',
        verbose_name='الدعوى'
    )
    
    # Action description/details
    description = models.TextField(
        verbose_name='وصف الإجراء'
    )
    
    # Additional metadata (JSON field for flexibility)
    metadata = models.JSONField(
        default=dict,
        blank=True,
        verbose_name='بيانات إضافية'
    )
    
    # IP address (if available)
    ip_address = models.GenericIPAddressField(
        null=True,
        blank=True,
        verbose_name='عنوان IP'
    )
    
    # Timestamp
    timestamp = models.DateTimeField(
        auto_now_add=True,
        db_index=True,
        verbose_name='الوقت'
    )
    
    class Meta:
        verbose_name = 'سجل إجراء'
        verbose_name_plural = 'سجل الإجراءات'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['action_type']),
            models.Index(fields=['user']),
            models.Index(fields=['lawsuit']),
            models.Index(fields=['timestamp']),
            models.Index(fields=['action_type', 'lawsuit']),
        ]
    
    def __str__(self):
        lawsuit_ref = f' - {self.lawsuit.case_number}' if self.lawsuit else ''
        user_ref = f' - {self.user.username}' if self.user else ''
        return f'{self.get_action_type_display()}{lawsuit_ref}{user_ref} - {self.timestamp}'
    
    def save(self, *args, **kwargs):
        """
        Override save to prevent manual editing
        Audit logs should only be created through signals
        """
        if self.pk:
            # Prevent updating existing logs
            raise ValueError('Audit logs cannot be modified')
        super().save(*args, **kwargs)
    
    def delete(self, *args, **kwargs):
        """
        Override delete to prevent deletion
        Audit logs should not be deleted
        """
        raise ValueError('Audit logs cannot be deleted')
