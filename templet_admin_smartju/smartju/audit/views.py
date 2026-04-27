from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from .models import AuditLog
from .serializers import AuditLogSerializer
from accounts.permissions import IsJudgeOrAdmin


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for AuditLog (Read-only)
    """
    queryset = AuditLog.objects.select_related('user', 'lawsuit').all()
    serializer_class = AuditLogSerializer
    permission_classes = [IsJudgeOrAdmin]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['action_type', 'user', 'lawsuit']
    search_fields = ['description']
    ordering_fields = ['timestamp']
    ordering = ['-timestamp']
