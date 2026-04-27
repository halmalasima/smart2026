from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import PaymentOrder
from .serializers import PaymentOrderSerializer


class PaymentOrderViewSet(viewsets.ModelViewSet):
    serializer_class = PaymentOrderSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['lawsuit', 'status', 'order_date']
    search_fields = ['order_number', 'description']
    ordering_fields = ['order_date', 'amount', 'created_at']
    ordering = ['-order_date']

    def get_queryset(self):
        user = self.request.user
        if user.is_superuser:
            return PaymentOrder.objects.all()

        from django.db.models import Q
        return PaymentOrder.objects.filter(
            Q(lawsuit__created_by=user) | 
            Q(lawsuit__client=user) |
            Q(lawsuit__created_by__profile__supervisor=user)
        ).select_related('lawsuit')

