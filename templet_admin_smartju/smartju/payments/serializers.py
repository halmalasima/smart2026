from rest_framework import serializers
from .models import PaymentOrder
from lawsuits.serializers import LawsuitSerializer
from lawsuits.models import Lawsuit
from smartju.common_fields import LawsuitPrimaryKeyField


class PaymentOrderSerializer(serializers.ModelSerializer):
    lawsuit_detail = LawsuitSerializer(source='lawsuit', read_only=True)
    lawsuit = serializers.PrimaryKeyRelatedField(
        queryset=Lawsuit.objects.all(),
        required=True
    )
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    remaining_amount = serializers.DecimalField(max_digits=18, decimal_places=2, read_only=True)
    
    class Meta:
        model = PaymentOrder
        fields = (
            'id', 'lawsuit', 'lawsuit_detail', 'lawsuit_id',
            'amount', 'paid_amount', 'remaining_amount',
            'order_date', 'order_number', 'description',
            'status', 'status_display', 'payment_date',
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at', 'remaining_amount')

