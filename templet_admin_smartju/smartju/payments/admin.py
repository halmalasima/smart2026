from django.contrib import admin
from .models import PaymentOrder


@admin.register(PaymentOrder)
class PaymentOrderAdmin(admin.ModelAdmin):
    list_display = ('order_number', 'lawsuit', 'amount', 'paid_amount', 'status', 'order_date')
    list_filter = ('status', 'order_date')
    search_fields = ('order_number', 'lawsuit__case_number')
    ordering = ('-order_date',)
    readonly_fields = ('created_at', 'updated_at')

