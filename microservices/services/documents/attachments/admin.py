from django.contrib import admin
from .models import Attachment


@admin.register(Attachment)
class AttachmentAdmin(admin.ModelAdmin):
    """
    Admin interface for Attachment
    """
    list_display = ('document_type', 'lawsuit', 'gregorian_date', 'page_count', 'get_file_size_display', 'created_at')
    list_filter = ('document_type', 'created_at', 'gregorian_date')
    search_fields = ('lawsuit__case_number', 'lawsuit__subject', 'content', 'evidence_basis', 'original_filename')
    readonly_fields = ('created_at', 'updated_at', 'file_size', 'original_filename')
    date_hierarchy = 'created_at'
    
    fieldsets = (
        ('معلومات المرفق', {
            'fields': ('lawsuit', 'document_type', 'file')
        }),
        ('التواريخ', {
            'fields': ('gregorian_date', 'hijri_date')
        }),
        ('معلومات المستند', {
            'fields': ('page_count', 'content', 'evidence_basis')
        }),
        ('معلومات الملف', {
            'fields': ('original_filename', 'file_size'),
            'classes': ('collapse',)
        }),
        ('معلومات إضافية', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-created_at',)
    
    def get_file_size_display(self, obj):
        """
        Display human-readable file size in list view
        """
        return obj.get_file_size_display()
    get_file_size_display.short_description = 'حجم الملف'
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('lawsuit')
