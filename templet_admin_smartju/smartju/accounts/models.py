from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver


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
    
    @property
    def user_sessions(self):
        """
        Get all user sessions
        """
        return self.user.sessions.all()
    
    @property
    def active_sessions(self):
        """
        Get active user sessions
        """
        return self.user.sessions.filter(is_active=True)
    
    @property
    def search_logs(self):
        """
        Get all search logs for this user
        """
        return self.user.search_logs.all()
    
    @property
    def ai_chat_logs(self):
        """
        Get all AI chat logs for this user
        """
        return self.user.ai_chat_logs.all()


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
