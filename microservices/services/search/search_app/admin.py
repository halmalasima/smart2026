from django.contrib import admin
from .models import UserSession, SearchLog, AIChatLog


@admin.register(UserSession)
class UserSessionAdmin(admin.ModelAdmin):
    list_display = ('user', 'device_type', 'ip_address', 'governorate', 'login_time', 'is_active')
    list_filter = ('is_active', 'device_type', 'governorate', 'login_time')
    search_fields = ('user__username', 'ip_address')
    ordering = ('-login_time',)
    readonly_fields = ('login_time',)


@admin.register(SearchLog)
class SearchLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'search_query', 'results_count', 'search_date')
    list_filter = ('search_date',)
    search_fields = ('search_query', 'user__username')
    ordering = ('-search_date',)
    readonly_fields = ('search_date',)


@admin.register(AIChatLog)
class AIChatLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'question', 'created_at', 'model_version')
    list_filter = ('created_at', 'model_version')
    search_fields = ('question', 'answer', 'user__username')
    ordering = ('-created_at',)
    readonly_fields = ('created_at',)

