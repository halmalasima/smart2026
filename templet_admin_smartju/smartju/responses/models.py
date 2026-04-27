from django.db import models
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit


class Response(models.Model):
    """
    Response Model - represents responses and memorandums submitted for a lawsuit
    """
    
    # ForeignKey to Lawsuit
    lawsuit = models.ForeignKey(
        Lawsuit,
        on_delete=models.CASCADE,
        related_name='responses',
        verbose_name='الدعوى'
    )
    
    # Response text/content
    response_text = models.TextField(
        verbose_name='نص الرد'
    )
    
    # Submitted by - can be a User or free text
    submitted_by = models.CharField(
        max_length=200,
        verbose_name='مقدم الرد'
    )
    
    # ForeignKey to User (optional - if submitted by a registered user)
    submitted_by_user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='submitted_responses',
        verbose_name='المستخدم المقدم'
    )
    
    # Submission date
    submission_date = models.DateField(
        verbose_name='تاريخ التقديم'
    )
    
    # Hijri date (optional)
    hijri_date = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='التاريخ الهجري'
    )
    
    # Response type (optional - for categorizing responses)
    RESPONSE_TYPE_MEMORANDUM = 'memorandum'
    RESPONSE_TYPE_REPLY = 'reply'
    RESPONSE_TYPE_OBJECTION = 'objection'
    RESPONSE_TYPE_CLARIFICATION = 'clarification'
    RESPONSE_TYPE_OTHER = 'other'
    
    RESPONSE_TYPE_CHOICES = [
        (RESPONSE_TYPE_MEMORANDUM, 'مذكرة'),
        (RESPONSE_TYPE_REPLY, 'رد'),
        (RESPONSE_TYPE_OBJECTION, 'اعتراض'),
        (RESPONSE_TYPE_CLARIFICATION, 'توضيح'),
        (RESPONSE_TYPE_OTHER, 'أخرى'),
    ]
    
    response_type = models.CharField(
        max_length=50,
        choices=RESPONSE_TYPE_CHOICES,
        default=RESPONSE_TYPE_REPLY,
        verbose_name='نوع الرد'
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
        verbose_name = 'رد'
        verbose_name_plural = 'ردود'
        ordering = ['-submission_date', '-created_at']
        indexes = [
            models.Index(fields=['lawsuit']),
            models.Index(fields=['submission_date']),
            models.Index(fields=['response_type']),
            models.Index(fields=['submitted_by_user']),
        ]
    
    def __str__(self):
        return f'{self.get_response_type_display()} - {self.lawsuit.case_number} - {self.submitted_by}'
    
    def get_submitted_by_display(self):
        """
        Return submitted_by_user if available, otherwise return submitted_by text
        """
        if self.submitted_by_user:
            return self.submitted_by_user.get_full_name() or self.submitted_by_user.username
        return self.submitted_by
