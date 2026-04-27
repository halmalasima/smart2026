from django.contrib import admin
from .models import Hearing


@admin.register(Hearing)
class HearingAdmin(admin.ModelAdmin):
    """
    Admin interface for Hearing
    """
    list_display = ('lawsuit', 'hearing_date', 'hearing_time', 'hearing_type', 'judge_name', 'created_at')
    list_filter = ('hearing_type', 'hearing_date', 'created_at')
    search_fields = ('lawsuit__case_number', 'lawsuit__subject', 'notes', 'judge_name')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'hearing_date'
    
    fieldsets = (
        ('معلومات الجلسة', {
            'fields': ('lawsuit', 'hearing_date', 'hijri_date', 'hearing_time', 'hearing_type')
        }),
        ('معلومات القاضي', {
            'fields': ('judge_name', 'judge')
        }),
        ('ملاحظات الجلسة', {
            'fields': ('notes',)
        }),
        ('معلومات إضافية', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-hearing_date', '-hearing_time')
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('lawsuit', 'judge', 'created_by')
