from django.contrib import admin
from .models import Judgment


@admin.register(Judgment)
class JudgmentAdmin(admin.ModelAdmin):
    """
    Admin interface for Judgment
    """
    list_display = ('judgment_number', 'lawsuit', 'judgment_type', 'judgment_date', 'judge_name', 'court_name', 'status', 'created_at')
    list_filter = ('judgment_type', 'status', 'judgment_date', 'created_at')
    search_fields = ('judgment_number', 'lawsuit__case_number', 'lawsuit__subject', 'judge_name', 'court_name', 'judgment_text', 'summary')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'judgment_date'
    
    fieldsets = (
        ('معلومات الحكم الأساسية', {
            'fields': ('lawsuit', 'judgment_number', 'judgment_type', 'status')
        }),
        ('التواريخ', {
            'fields': ('judgment_date', 'hijri_date')
        }),
        ('معلومات القاضي والمحكمة', {
            'fields': ('judge_name', 'judge', 'court_name')
        }),
        ('محتوى الحكم', {
            'fields': ('judgment_text', 'summary')
        }),
        ('معلومات إضافية', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-judgment_date', '-created_at')
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('lawsuit', 'judge', 'created_by')
