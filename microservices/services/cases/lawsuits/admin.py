from django.contrib import admin
from .models import Case, CaseParty, Lawsuit, LegalTemplate, FinancialClaim
from .models_casefile import CaseFileItem
from smartjudi_common.admin_utils import UserIsolationAdminMixin


@admin.register(CaseFileItem)
class CaseFileItemAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    list_display = ('title', 'lawsuit', 'item_type', 'created_by_display', 'created_at')
    list_filter = ('item_type', 'created_at')
    search_fields = ('title', 'description', 'lawsuit__case_number')
    raw_id_fields = ('lawsuit',)
    readonly_fields = ('created_at', 'updated_at', 'file_size')
    ordering = ('-created_at',)

    def created_by_display(self, obj):
        return f"User ID: {obj.created_by}"
    created_by_display.short_description = 'أنشأ بواسطة'


@admin.register(LegalTemplate)
class LegalTemplateAdmin(admin.ModelAdmin):
    list_display = ('case_type', 'section_key', 'section_title', 'is_required')
    list_filter = ('case_type', 'is_required')
    search_fields = ('section_title', 'default_text')
    ordering = ('case_type', 'section_key')


@admin.register(FinancialClaim)
class FinancialClaimAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    user_field = 'lawsuit__created_by' # Link to parent lawsuit creator
    list_display = ('lawsuit', 'amount', 'currency', 'due_date')
    list_filter = ('currency', 'due_date')
    search_fields = ('lawsuit__case_number', 'description')
    raw_id_fields = ('lawsuit',)

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser: return qs
        return qs.filter(lawsuit__created_by=request.user.id)


@admin.register(Case)
class CaseAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    list_display = ('case_number', 'subject', 'case_status', 'created_at')
    list_filter = ('case_status', 'case_type', 'governorate')
    search_fields = ('case_number', 'subject')
    readonly_fields = ('created_at', 'updated_at')

@admin.register(Lawsuit)
class LawsuitAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    list_display = ('case_number', 'case_type', 'case_status', 'subject', 'created_at')
    list_filter = ('case_type', 'case_status', 'status', 'created_at')
    search_fields = ('case_number', 'subject', 'court')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'created_at'
    raw_id_fields = ('case', 'parent_lawsuit')
