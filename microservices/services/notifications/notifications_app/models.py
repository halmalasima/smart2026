from django.db import models
from django.contrib.auth.models import User


class Notification(models.Model):
    """
    Notification Model - إشعارات المستخدمين
    """

    TYPE_HEARING = 'hearing'
    TYPE_LAWSUIT = 'lawsuit'
    TYPE_JUDGMENT = 'judgment'
    TYPE_APPEAL = 'appeal'
    TYPE_PAYMENT = 'payment'
    TYPE_MESSAGE = 'message'
    TYPE_SYSTEM = 'system'

    TYPE_CHOICES = [
        (TYPE_HEARING, 'جلسة'),
        (TYPE_LAWSUIT, 'دعوى'),
        (TYPE_JUDGMENT, 'حكم'),
        (TYPE_APPEAL, 'طعن'),
        (TYPE_PAYMENT, 'دفع'),
        (TYPE_MESSAGE, 'رسالة'),
        (TYPE_SYSTEM, 'نظام'),
    ]

    recipient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='notifications',
        verbose_name='المستلم'
    )

    notification_type = models.CharField(
        max_length=30,
        choices=TYPE_CHOICES,
        default=TYPE_SYSTEM,
        verbose_name='نوع الإشعار'
    )

    title = models.CharField(
        max_length=255,
        verbose_name='العنوان'
    )

    body = models.TextField(
        blank=True,
        default='',
        verbose_name='المحتوى'
    )

    is_read = models.BooleanField(
        default=False,
        verbose_name='تمت القراءة'
    )

    related_object_id = models.PositiveIntegerField(
        blank=True,
        null=True,
        verbose_name='معرف الكيان المرتبط'
    )

    related_object_type = models.CharField(
        max_length=50,
        blank=True,
        default='',
        verbose_name='نوع الكيان المرتبط'
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )

    class Meta:
        verbose_name = 'إشعار'
        verbose_name_plural = 'الإشعارات'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient', 'is_read']),
            models.Index(fields=['recipient', '-created_at']),
            models.Index(fields=['notification_type']),
        ]

    def __str__(self):
        return f'{self.title} → {self.recipient.username}'
