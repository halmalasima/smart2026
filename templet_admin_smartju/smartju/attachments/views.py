from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q
from .models import Attachment
from .serializers import AttachmentSerializer


class AttachmentViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Attachment - أي مستخدم مسجّل يستطيع رفع مرفقات
    """
    serializer_class = AttachmentSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['document_type', 'lawsuit']
    search_fields = ['original_filename', 'content', 'evidence_basis']
    ordering_fields = ['created_at', 'gregorian_date']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        qs = Attachment.objects.select_related('lawsuit').all()
        if user.is_superuser:
            return qs
        if hasattr(user, 'profile') and user.profile.role == 'admin':
            return qs
        return qs.filter(
            Q(lawsuit__created_by=user) |
            Q(lawsuit__client=user)
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
