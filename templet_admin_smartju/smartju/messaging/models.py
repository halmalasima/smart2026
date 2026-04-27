from django.db import models
from django.contrib.auth.models import User
from lawsuits.models import Lawsuit

class Message(models.Model):
    """
    Message model for lawyer-client communication within a case
    """
    sender = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='sent_messages',
        verbose_name='المرسل'
    )
    recipient = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='received_messages',
        verbose_name='المستقبل'
    )
    lawsuit = models.ForeignKey(
        Lawsuit, 
        on_delete=models.CASCADE, 
        related_name='messages',
        null=True,
        blank=True,
        verbose_name='القضية المرتبطة'
    )
    content = models.TextField(verbose_name='محتوى الرسالة')
    attachment = models.FileField(
        upload_to='messaging/attachments/', 
        null=True, 
        blank=True,
        verbose_name='مرفق'
    )
    is_read = models.BooleanField(default=False, verbose_name='تمت القراءة')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='تاريخ الإرسال')

    class Meta:
        verbose_name = 'رسالة'
        verbose_name_plural = 'الرسائل'
        ordering = ['created_at']

    def __str__(self):
        return f'{self.sender.username} to {self.recipient.username} at {self.created_at}'
