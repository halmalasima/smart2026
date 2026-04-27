from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from .models import Judgment
from .serializers import JudgmentSerializer
from accounts.permissions import IsJudgeOrAdmin


class JudgmentViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Judgment
    """
    serializer_class = JudgmentSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['judgment_type', 'status', 'lawsuit', 'judge']
    search_fields = ['judgment_number', 'judgment_text', 'summary', 'judge_name', 'court_name']
    ordering_fields = ['created_at', 'judgment_date']
    ordering = ['-judgment_date', '-created_at']

    def get_queryset(self):
        user = self.request.user
        if user.is_superuser:
            return Judgment.objects.all()

        from django.db.models import Q
        return Judgment.objects.filter(
            Q(lawsuit__created_by=user) | 
            Q(lawsuit__client=user) |
            Q(lawsuit__created_by__profile__supervisor=user)
        ).select_related('lawsuit', 'judge', 'created_by')
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsJudgeOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)
