from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from .models import PaymentOrder
from .serializers import PaymentOrderSerializer


class PaymentOrderViewSet(viewsets.ModelViewSet):
    serializer_class = PaymentOrderSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
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
            Q(lawsuit__created_by=user.id) |
            Q(lawsuit__client=user.id)
        ).select_related('lawsuit')

