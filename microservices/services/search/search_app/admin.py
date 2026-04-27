from django.contrib import admin
from .models import UserSession, SearchLog, AIChatLog
from smartjudi_common.admin_utils import UserIsolationAdminMixin


@admin.register(UserSession)
class UserSessionAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    user_field = 'user_id'
    list_display = ('user_id', 'device_type', 'ip_address', 'governorate', 'login_time', 'is_active')
    list_filter = ('is_active', 'device_type', 'governorate', 'login_time')
    search_fields = ('user_id', 'ip_address')
    ordering = ('-login_time',)
    readonly_fields = ('login_time',)


@admin.register(SearchLog)
class SearchLogAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    user_field = 'user_id'
    list_display = ('user_id', 'search_query', 'results_count', 'search_date')
    list_filter = ('search_date',)
    search_fields = ('search_query', 'user_id')
    ordering = ('-search_date',)
    readonly_fields = ('search_date',)


@admin.register(AIChatLog)
class AIChatLogAdmin(UserIsolationAdminMixin, admin.ModelAdmin):
    user_field = 'user_id'
    list_display = ('user_id', 'question', 'created_at', 'model_version')
    list_filter = ('created_at', 'model_version')
    search_fields = ('question', 'answer', 'user_id')
    ordering = ('-created_at',)
    readonly_fields = ('created_at',)

