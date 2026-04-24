from django.contrib import admin
from .models import Appeal


@admin.register(Appeal)
class AppealAdmin(admin.ModelAdmin):
    """
    Admin interface for Appeal
    """
    list_display = ('appeal_number', 'lawsuit', 'appeal_type', 'higher_court', 'status', 'appeal_date', 'get_submitted_by_display', 'created_at')
    list_filter = ('appeal_type', 'status', 'appeal_date', 'created_at')
    search_fields = ('appeal_number', 'lawsuit__case_number', 'lawsuit__subject', 'higher_court', 'submitted_by', 'appeal_reasons', 'appeal_requests')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'appeal_date'
    
    fieldsets = (
        ('معلومات الطعن الأساسية', {
            'fields': ('lawsuit', 'appeal_number', 'appeal_type', 'status', 'higher_court')
        }),
        ('معلومات المقدم', {
            'fields': ('submitted_by', 'submitted_by_user')
        }),
        ('التواريخ', {
            'fields': ('appeal_date', 'hijri_date')
        }),
        ('محتوى الطعن', {
            'fields': ('appeal_reasons', 'appeal_requests')
        }),
        ('معلومات إضافية', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-appeal_date', '-created_at')
    
    def get_submitted_by_display(self, obj):
        """
        Display submitted by in list view
        """
        return obj.get_submitted_by_display()
    get_submitted_by_display.short_description = 'مقدم الطعن'
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('lawsuit', 'submitted_by_user')
