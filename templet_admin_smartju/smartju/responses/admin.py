from django.contrib import admin
from .models import Response


@admin.register(Response)
class ResponseAdmin(admin.ModelAdmin):
    """
    Admin interface for Response
    """
    list_display = ('response_type', 'lawsuit', 'get_submitted_by_display', 'submission_date', 'created_at')
    list_filter = ('response_type', 'submission_date', 'created_at')
    search_fields = ('response_text', 'submitted_by', 'lawsuit__case_number', 'lawsuit__subject')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'submission_date'
    
    fieldsets = (
        ('معلومات الرد', {
            'fields': ('lawsuit', 'response_type', 'submitted_by', 'submitted_by_user')
        }),
        ('التواريخ', {
            'fields': ('submission_date', 'hijri_date')
        }),
        ('محتوى الرد', {
            'fields': ('response_text',)
        }),
        ('معلومات إضافية', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-submission_date', '-created_at')
    
    def get_submitted_by_display(self, obj):
        """
        Display submitted by in list view
        """
        return obj.get_submitted_by_display()
    get_submitted_by_display.short_description = 'مقدم الرد'
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('lawsuit', 'submitted_by_user')
