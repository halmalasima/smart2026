from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q
from .models import Attachment
from .serializers import AttachmentSerializer
from smartjudi_common.user_utils import get_user_role


class AttachmentViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Attachment - أي مستخدم مسجّل يستطيع رفع مرفقات
    """
    serializer_class = AttachmentSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['document_type', 'lawsuit_id']
    search_fields = ['original_filename', 'content', 'evidence_basis']
    ordering_fields = ['created_at', 'gregorian_date']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        qs = Attachment.objects.all()
        if get_user_role(user) in ('admin',):
            return qs
        lawsuit_id = self.request.query_params.get('lawsuit_id')
        if lawsuit_id:
            return qs.filter(lawsuit_id=lawsuit_id)
        # Detail routes (retrieve/update/delete) don't include lawsuit_id query param.
        # Allow lookup by pk so PATCH/DELETE on an existing attachment works.
        pk = self.kwargs.get('pk')
        if pk is not None:
            return qs.filter(pk=pk)
        # No filter provided: return nothing to prevent exposing all attachments
        return qs.none()

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
