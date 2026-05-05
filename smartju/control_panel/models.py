from django.conf import settings
from django.db import models


class ActivityLog(models.Model):
    """Lightweight activity log captured by the control panel."""

    ACTION_CHOICES = [
        ("login", "تسجيل دخول"),
        ("logout", "تسجيل خروج"),
        ("create", "إنشاء"),
        ("update", "تعديل"),
        ("delete", "حذف"),
        ("view", "استعراض"),
        ("other", "أخرى"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="cp_activities",
    )
    action = models.CharField(max_length=32, choices=ACTION_CHOICES, default="other")
    target = models.CharField(max_length=255, blank=True, default="")
    description = models.TextField(blank=True, default="")
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=512, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "سجل نشاط"
        verbose_name_plural = "سجلات النشاط"

    def __str__(self) -> str:  # pragma: no cover
        who = self.user.get_username() if self.user else "—"
        return f"{who} · {self.get_action_display()} · {self.target}"


class ServiceDefinition(models.Model):
    """
    Defines a service/screen available in the application.
    Each service maps to a route in the Flutter app and can be controlled
    per role via RoleServicePermission.
    """
    key = models.CharField(
        max_length=100,
        unique=True,
        verbose_name='مفتاح الخدمة',
        help_text='المسار أو المعرف الفريد للخدمة (مثل: /lawsuits, /chat, /inheritance)'
    )
    name_ar = models.CharField(max_length=200, verbose_name='اسم الخدمة (عربي)')
    name_en = models.CharField(max_length=200, blank=True, verbose_name='اسم الخدمة (إنجليزي)')
    description = models.TextField(blank=True, verbose_name='وصف الخدمة')
    icon = models.CharField(
        max_length=100,
        blank=True,
        default='settings',
        verbose_name='أيقونة',
        help_text='اسم أيقونة Material Icons'
    )
    category = models.CharField(
        max_length=50,
        blank=True,
        default='general',
        verbose_name='التصنيف',
        choices=[
            ('legal', 'قانوني'),
            ('financial', 'مالي'),
            ('ai', 'ذكاء اصطناعي'),
            ('admin', 'إداري'),
            ('general', 'عام'),
            ('communication', 'تواصل'),
        ]
    )
    is_active = models.BooleanField(default=True, verbose_name='مفعّلة')
    is_premium = models.BooleanField(default=False, verbose_name='مميزة (Premium)')
    sort_order = models.IntegerField(default=0, verbose_name='ترتيب العرض')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['sort_order', 'name_ar']
        verbose_name = 'خدمة'
        verbose_name_plural = 'الخدمات'

    def __str__(self):
        return self.name_ar


class RoleServicePermission(models.Model):
    """
    Controls which services are accessible to which role.
    Admin can configure this from the control panel.
    """
    ROLE_CHOICES = [
        ('judge', 'قاضي'),
        ('lawyer', 'محامي'),
        ('assistant', 'معاون محامي'),
        ('notary', 'كاتب عدل'),
        ('citizen', 'مواطن'),
        ('admin', 'مدير'),
    ]

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, verbose_name='الدور')
    service = models.ForeignKey(
        ServiceDefinition,
        on_delete=models.CASCADE,
        related_name='permissions',
        verbose_name='الخدمة'
    )
    is_enabled = models.BooleanField(default=True, verbose_name='مفعّلة لهذا الدور')
    max_daily_uses = models.IntegerField(
        default=0,
        verbose_name='حد الاستخدام اليومي',
        help_text='0 = بلا حدود'
    )
    max_monthly_uses = models.IntegerField(
        default=0,
        verbose_name='حد الاستخدام الشهري',
        help_text='0 = بلا حدود'
    )

    class Meta:
        unique_together = ('role', 'service')
        ordering = ['role', 'service__sort_order']
        verbose_name = 'صلاحية خدمة لدور'
        verbose_name_plural = 'صلاحيات الخدمات حسب الأدوار'

    def __str__(self):
        return f"{self.get_role_display()} -> {self.service.name_ar}"


class ServiceUsageLog(models.Model):
    """
    Tracks every time a user accesses a service.
    Used for analytics, billing, and usage limits enforcement.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='service_usage_logs',
        verbose_name='المستخدم'
    )
    service = models.ForeignKey(
        ServiceDefinition,
        on_delete=models.CASCADE,
        related_name='usage_logs',
        verbose_name='الخدمة'
    )
    accessed_at = models.DateTimeField(auto_now_add=True, verbose_name='وقت الوصول')
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    device_type = models.CharField(max_length=20, blank=True, default='', verbose_name='نوع الجهاز')
    duration_seconds = models.IntegerField(default=0, verbose_name='مدة الاستخدام (ثواني)')

    class Meta:
        ordering = ['-accessed_at']
        verbose_name = 'سجل استخدام خدمة'
        verbose_name_plural = 'سجلات استخدام الخدمات'
        indexes = [
            models.Index(fields=['user', 'service', 'accessed_at']),
            models.Index(fields=['service', 'accessed_at']),
        ]

    def __str__(self):
        who = self.user.get_username() if self.user else "—"
        return f"{who} -> {self.service.name_ar} @ {self.accessed_at}"
