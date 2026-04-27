from django.contrib import admin
from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    """
    Admin interface for AuditLog
    All fields are readonly - audit logs cannot be modified
    """
    list_display = ('action_type', 'lawsuit', 'user', 'timestamp', 'get_description_preview')
    list_filter = ('action_type', 'timestamp')
    search_fields = ('description', 'lawsuit__case_number', 'user__username', 'user__email')
    readonly_fields = ('action_type', 'user', 'lawsuit', 'description', 'metadata', 'ip_address', 'timestamp')
    date_hierarchy = 'timestamp'
    
    fieldsets = (
        ('معلومات الإجراء', {
            'fields': ('action_type', 'timestamp')
        }),
        ('المستخدم والدعوى', {
            'fields': ('user', 'lawsuit')
        }),
        ('تفاصيل الإجراء', {
            'fields': ('description', 'metadata')
        }),
        ('معلومات إضافية', {
            'fields': ('ip_address',),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-timestamp',)
    
    def get_description_preview(self, obj):
        """
        Show a preview of the description (first 100 characters)
        """
        if obj.description:
            return obj.description[:100] + '...' if len(obj.description) > 100 else obj.description
        return '-'
    get_description_preview.short_description = 'وصف الإجراء'
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('user', 'lawsuit')
    
    def has_add_permission(self, request):
        """
        Prevent manual addition of audit logs
        """
        return False
    
    def has_change_permission(self, request, obj=None):
        """
        Prevent modification of audit logs
        """
        return False
    
    def has_delete_permission(self, request, obj=None):
        """
        Prevent deletion of audit logs
        """
        return False
