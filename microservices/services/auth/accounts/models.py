import random
import string
from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone


class UserProfile(models.Model):
    """
    User Profile Model - extends Django User with additional information
    """
    
    # Role choices
    ROLE_JUDGE = 'judge'
    ROLE_LAWYER = 'lawyer'
    ROLE_NOTARY = 'notary'
    ROLE_CITIZEN = 'citizen'
    ROLE_ASSISTANT = 'assistant'
    ROLE_ADMIN = 'admin'
    
    ROLE_CHOICES = [
        (ROLE_JUDGE, 'قاضي'),
        (ROLE_LAWYER, 'محامي'),
        (ROLE_ASSISTANT, 'معاون محامي'),
        (ROLE_NOTARY, 'كاتب عدل'),
        (ROLE_CITIZEN, 'مواطن'),
        (ROLE_ADMIN, 'مدير'),
    ]
    
    # OneToOne relationship with User
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile',
        verbose_name='المستخدم'
    )
    
    # Role field
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default=ROLE_CITIZEN,
        verbose_name='الدور'
    )
    
    # Additional fields
    phone_number = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        unique=True,
        verbose_name='رقم الهاتف'
    )
    
    national_id = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        unique=True,
        verbose_name='الرقم الوطني'
    )
    
    supervisor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='supervised_accounts',
        verbose_name='المسؤول (المحامي)'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='تاريخ الإنشاء'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='تاريخ التحديث'
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name='نشط'
    )

    subscription_plan = models.CharField(
        max_length=50,
        default='free',
        choices=[('free','مجاني'),('starter','مبتدئ'),('professional','احترافي'),('enterprise','مؤسسي')],
        verbose_name='باقة الاشتراك'
    )

    is_trial = models.BooleanField(
        default=True,
        verbose_name='فترة تجريبية'
    )

    subscription_expiry = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='انتهاء الاشتراك'
    )
    
    class Meta:
        verbose_name = 'ملف المستخدم'
        verbose_name_plural = 'ملفات المستخدمين'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['role']),
            models.Index(fields=['national_id']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        return f'{self.user.username} - {self.get_role_display()}'
    
    @property
    def is_judge(self):
        return self.role == self.ROLE_JUDGE
    
    @property
    def is_lawyer(self):
        return self.role == self.ROLE_LAWYER
    
    @property
    def is_notary(self):
        return self.role == self.ROLE_NOTARY
    
    @property
    def is_citizen(self):
        return self.role == self.ROLE_CITIZEN
    
    @property
    def is_admin_role(self):
        return self.role == self.ROLE_ADMIN
    
    # NOTE: user_sessions, search_logs, ai_chat_logs are owned by search-service.
    # Query them via the search-service internal API, not here.


class OTPCode(models.Model):
    """
    OTP Code Model - رمز التحقق عبر البريد الإلكتروني
    يُستخدم لتفعيل الحساب واستعادة كلمة المرور
    """
    PURPOSE_VERIFY_EMAIL = 'verify_email'
    PURPOSE_RESET_PASSWORD = 'reset_password'
    PURPOSE_CHOICES = [
        (PURPOSE_VERIFY_EMAIL, 'تفعيل البريد الإلكتروني'),
        (PURPOSE_RESET_PASSWORD, 'استعادة كلمة المرور'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='otp_codes')
    code = models.CharField(max_length=6, verbose_name='رمز التحقق')
    purpose = models.CharField(max_length=20, choices=PURPOSE_CHOICES)
    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'رمز تحقق'
        verbose_name_plural = 'رموز التحقق'

    def __str__(self):
        return f'{self.user.username} - {self.code} ({self.purpose})'

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    @property
    def is_valid(self):
        return not self.is_used and not self.is_expired

    @staticmethod
    def generate_code(length=6):
        return ''.join(random.choices(string.digits, k=length))

    @classmethod
    def create_otp(cls, user, purpose, minutes=10):
        # Invalidate previous unused OTPs for same purpose
        cls.objects.filter(user=user, purpose=purpose, is_used=False).update(is_used=True)
        code = cls.generate_code()
        otp = cls.objects.create(
            user=user,
            code=code,
            purpose=purpose,
            expires_at=timezone.now() + timezone.timedelta(minutes=minutes),
        )
        return otp


# Signal to create UserProfile automatically when User is created
@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """
    Signal receiver to automatically create UserProfile when User is created
    """
    if created:
        # Default role is citizen, but superuser gets admin role
        role = UserProfile.ROLE_ADMIN if instance.is_superuser else UserProfile.ROLE_CITIZEN
        UserProfile.objects.get_or_create(
            user=instance,
            defaults={'role': role}
        )
    elif instance.is_superuser:
        # Optional: ensure existing superusers have admin role
        profile, _ = UserProfile.objects.get_or_create(user=instance)
        if profile.role != UserProfile.ROLE_ADMIN:
            profile.role = UserProfile.ROLE_ADMIN
            profile.save()
