from django.contrib import admin
from .models import Governorate, District, CourtType, CourtSpecialization, Court


@admin.register(Governorate)
class GovernorateAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at')
    search_fields = ('name',)
    ordering = ('name',)


@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ('name', 'governorate', 'created_at')
    list_filter = ('governorate',)
    search_fields = ('name', 'governorate__name')
    ordering = ('governorate', 'name')


@admin.register(CourtType)
class CourtTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'judicial_level', 'created_at')
    list_filter = ('judicial_level',)
    search_fields = ('name',)
    ordering = ('judicial_level', 'name')


@admin.register(CourtSpecialization)
class CourtSpecializationAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at')
    search_fields = ('name',)
    ordering = ('name',)


@admin.register(Court)
class CourtAdmin(admin.ModelAdmin):
    list_display = ('name', 'court_type', 'governorate', 'district', 'is_active', 'created_at')
    list_filter = ('court_type', 'governorate', 'is_active', 'specializations')
    search_fields = ('name', 'address')
    filter_horizontal = ('specializations',)
    ordering = ('governorate', 'name')

