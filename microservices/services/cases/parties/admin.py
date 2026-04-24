from django.contrib import admin
from .models import Plaintiff, Defendant


class PlaintiffInline(admin.TabularInline):
    """
    Inline admin for Plaintiff in Lawsuit admin
    """
    model = Plaintiff
    extra = 1
    fields = ('name', 'gender', 'nationality', 'occupation', 'phone', 'attorney_name')
    verbose_name = 'مدعي'
    verbose_name_plural = 'مدعون'


class DefendantInline(admin.TabularInline):
    """
    Inline admin for Defendant in Lawsuit admin
    """
    model = Defendant
    extra = 1
    fields = ('name', 'gender', 'nationality', 'occupation', 'phone', 'attorney_name')
    verbose_name = 'مدعى عليه'
    verbose_name_plural = 'مدعى عليهم'


@admin.register(Plaintiff)
class PlaintiffAdmin(admin.ModelAdmin):
    """
    Admin interface for Plaintiff
    """
    list_display = ('name', 'gender', 'nationality', 'occupation', 'phone', 'lawsuit', 'created_at')
    list_filter = ('gender', 'nationality', 'created_at')
    search_fields = ('name', 'phone', 'attorney_name', 'lawsuit__case_number', 'lawsuit__subject')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('معلومات المدعي', {
            'fields': ('lawsuit', 'name', 'gender', 'nationality', 'occupation')
        }),
        ('معلومات الاتصال', {
            'fields': ('address', 'phone')
        }),
        ('معلومات الوكيل', {
            'fields': ('attorney_name', 'attorney_phone'),
            'classes': ('collapse',)
        }),
        ('معلومات إضافية', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-created_at',)
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('lawsuit')


@admin.register(Defendant)
class DefendantAdmin(admin.ModelAdmin):
    """
    Admin interface for Defendant
    """
    list_display = ('name', 'gender', 'nationality', 'occupation', 'phone', 'lawsuit', 'created_at')
    list_filter = ('gender', 'nationality', 'created_at')
    search_fields = ('name', 'phone', 'attorney_name', 'lawsuit__case_number', 'lawsuit__subject')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('معلومات المدعى عليه', {
            'fields': ('lawsuit', 'name', 'gender', 'nationality', 'occupation')
        }),
        ('معلومات الاتصال', {
            'fields': ('address', 'phone')
        }),
        ('معلومات الوكيل', {
            'fields': ('attorney_name', 'attorney_phone'),
            'classes': ('collapse',)
        }),
        ('معلومات إضافية', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    ordering = ('-created_at',)
    
    def get_queryset(self, request):
        """
        Optimize queryset by selecting related objects
        """
        qs = super().get_queryset(request)
        return qs.select_related('lawsuit')
