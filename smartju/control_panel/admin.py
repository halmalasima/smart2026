from django.contrib import admin

from .models import ActivityLog


@admin.register(ActivityLog)
class ActivityLogAdmin(admin.ModelAdmin):
    list_display = ("created_at", "user", "action", "target", "ip_address")
    list_filter = ("action", "created_at")
    search_fields = ("user__username", "target", "description", "ip_address")
    date_hierarchy = "created_at"
    readonly_fields = tuple(f.name for f in ActivityLog._meta.fields)
