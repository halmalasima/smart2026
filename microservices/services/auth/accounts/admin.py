from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User
from .models import UserProfile


class UserProfileInline(admin.StackedInline):
    """
    Inline admin for UserProfile
    """
    model = UserProfile
    fk_name = 'user'
    can_delete = False
    verbose_name_plural = 'ملف المستخدم'
    fields = ('role', 'phone_number', 'national_id', 'is_active', 'created_at', 'updated_at')
    readonly_fields = ('created_at', 'updated_at')


class UserAdmin(BaseUserAdmin):
    """
    Extended User Admin to include UserProfile
    """
    inlines = (UserProfileInline,)
    
    list_display = ('username', 'email', 'first_name', 'last_name', 'get_role', 'is_staff', 'is_active', 'date_joined')
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'profile__role', 'date_joined')
    
    def get_role(self, obj):
        """
        Get user role from profile
        """
        if hasattr(obj, 'profile'):
            return obj.profile.get_role_display()
        return '-'
    get_role.short_description = 'الدور'
    get_role.admin_order_field = 'profile__role'


# Unregister default User admin and register custom UserAdmin
admin.site.unregister(User)
admin.site.register(User, UserAdmin)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    """
    Admin interface for UserProfile
    """
    list_display = ('user', 'role', 'phone_number', 'national_id', 'is_active', 'created_at')
    list_filter = ('role', 'is_active', 'created_at')
    search_fields = ('user__username', 'user__email', 'user__first_name', 'user__last_name', 'phone_number', 'national_id')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('معلومات المستخدم', {
            'fields': ('user', 'role', 'is_active')
        }),
        ('معلومات الاتصال', {
            'fields': ('phone_number', 'national_id')
        }),
        ('معلومات إضافية', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-created_at',)
