from django.contrib import admin
from .models import Lawsuit, LegalTemplate, FinancialClaim
from .models_casefile import CaseFileItem


@admin.register(CaseFileItem)
class CaseFileItemAdmin(admin.ModelAdmin):
    list_display = ('title', 'lawsuit', 'item_type', 'created_by', 'created_at')
    list_filter = ('item_type', 'created_at')
    search_fields = ('title', 'description', 'lawsuit__case_number')
    raw_id_fields = ('lawsuit', 'created_by')
    readonly_fields = ('created_at', 'updated_at', 'file_size')
    ordering = ('-created_at',)


@admin.register(LegalTemplate)
class LegalTemplateAdmin(admin.ModelAdmin):
    list_display = ('case_type', 'section_key', 'section_title', 'is_required')
    list_filter = ('case_type', 'is_required')
    search_fields = ('section_title', 'default_text')
    ordering = ('case_type', 'section_key')


@admin.register(FinancialClaim)
class FinancialClaimAdmin(admin.ModelAdmin):
    list_display = ('lawsuit', 'amount', 'currency', 'due_date')
    list_filter = ('currency', 'due_date')
    search_fields = ('lawsuit__case_number', 'description')
    raw_id_fields = ('lawsuit',)


@admin.register(Lawsuit)
class LawsuitAdmin(admin.ModelAdmin):
    list_display = ('case_number', 'case_type', 'case_status', 'subject', 'created_by', 'created_at')
    list_filter = ('case_type', 'case_status', 'status', 'created_at')
    search_fields = ('case_number', 'subject', 'court')
    raw_id_fields = ('created_by', 'court_fk')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'created_at'
