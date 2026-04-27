from django.db import models
from django.contrib.auth.models import User


class UserSession(models.Model):
    """
    User Session Model - جلسات المستخدمين
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sessions',
        verbose_name='المستخدم'
    )
    
    device_type = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='نوع الجهاز'
    )
    
    browser = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='المتصفح'
    )
    
    ip_address = models.GenericIPAddressField(
        blank=True,
        null=True,
        verbose_name='عنوان IP'
    )
    
    country = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='الدولة'
    )
    
    governorate = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='المحافظة'
    )
    
    city = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='المدينة'
    )
    
    login_time = models.DateTimeField(
        auto_now_add=True,
        verbose_name='وقت تسجيل الدخول'
    )
    
    logout_time = models.DateTimeField(
        blank=True,
        null=True,
        verbose_name='وقت تسجيل الخروج'
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name='نشط'
    )
    
    class Meta:
        verbose_name = 'جلسة مستخدم'
        verbose_name_plural = 'جلسات المستخدمين'
        ordering = ['-login_time']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['login_time']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        return f'{self.user.username} - {self.login_time}'


class SearchLog(models.Model):
    """
    Search Log Model - سجل البحث
    """
    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='search_logs',
        verbose_name='المستخدم'
    )
    
    search_query = models.TextField(
        verbose_name='استعلام البحث'
    )
    
    search_date = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ البحث'
    )
    
    # Optional: store search results count
    results_count = models.PositiveIntegerField(
        blank=True,
        null=True,
        verbose_name='عدد النتائج'
    )
    
    class Meta:
        verbose_name = 'سجل بحث'
        verbose_name_plural = 'سجلات البحث'
        ordering = ['-search_date']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['search_date']),
        ]
    
    def __str__(self):
        return f'{self.search_query[:50]}... - {self.search_date}'


class AIChatLog(models.Model):
    """
    AI Chat Log Model - سجل محادثات AI
    """
    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='ai_chat_logs',
        verbose_name='المستخدم'
    )
    
    question = models.TextField(
        verbose_name='السؤال'
    )
    
    answer = models.TextField(
        verbose_name='الإجابة'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    # Optional: store model/version used
    model_version = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='إصدار النموذج'
    )
    
    class Meta:
        verbose_name = 'سجل محادثة AI'
        verbose_name_plural = 'سجلات محادثات AI'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f'{self.question[:50]}... - {self.created_at}'

