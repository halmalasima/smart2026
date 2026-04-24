from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from .models import Response
from .serializers import ResponseSerializer
from permissions import IsJudgeOrLawyerOrAdmin


class ResponseViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Response
    """
    serializer_class = ResponseSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['response_type', 'lawsuit', 'submitted_by_user']
    search_fields = ['response_text', 'submitted_by']
    ordering_fields = ['created_at', 'submission_date']
    ordering = ['-submission_date', '-created_at']

    def get_queryset(self):
        user = self.request.user
        if user.is_superuser:
            return Response.objects.all()

        from django.db.models import Q
        return Response.objects.filter(
            Q(lawsuit__created_by=user.id) |
            Q(lawsuit__client=user.id)
        ).select_related('lawsuit')
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        serializer.save()
