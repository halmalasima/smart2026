from django.contrib import admin
from .models import Lawyer, LawyerFilterOptions


@admin.register(Lawyer)
class LawyerAdmin(admin.ModelAdmin):
    list_display = ['registration_number', 'name', 'grade', 'branch', 'phone', 'governorate']
    list_filter = ['grade', 'branch', 'governorate']
    search_fields = ['name', 'registration_number', 'phone']
    ordering = ['registration_number']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(LawyerFilterOptions)
class LawyerFilterOptionsAdmin(admin.ModelAdmin):
    list_display = ['option_type', 'display_name', 'option_value', 'is_active', 'sort_order']
    list_filter = ['option_type', 'is_active']
    search_fields = ['display_name', 'option_value']
    ordering = ['option_type', 'sort_order', 'display_name']
    readonly_fields = ['created_at', 'updated_at']
