from django.contrib import admin
from .models import Hearing
from smartjudi_common.admin_utils import UserIsolationAdminMixin


@admin.register(Hearing)
class HearingAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    """
    Admin interface for Hearing
    """
    list_display = ('lawsuit_id', 'hearing_date', 'hearing_time', 'hearing_type', 'judge_name', 'created_at')
    list_filter = ('hearing_type', 'hearing_date', 'created_at')
    search_fields = ('lawsuit_case_number', 'notes', 'judge_name')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'hearing_date'
    
    fieldsets = (
        ('معلومات الجلسة', {
            'fields': ('lawsuit_id', 'lawsuit_case_number', 'hearing_date', 'hijri_date', 'hearing_time', 'hearing_type')
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
        Optimize queryset
        """
        qs = super().get_queryset(request)
        return qs.select_related('judge', 'created_by')
