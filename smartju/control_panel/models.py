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
