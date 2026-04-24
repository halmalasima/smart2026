from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q
from .models import Plaintiff, Defendant
from .serializers import PlaintiffSerializer, DefendantSerializer
from permissions import IsJudgeOrLawyerOrAdmin
from smartjudi_common.user_utils import get_user_role


class PlaintiffViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Plaintiff
    """
    serializer_class = PlaintiffSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['gender', 'nationality', 'lawsuit']
    search_fields = ['name', 'phone', 'attorney_name']
    ordering_fields = ['created_at', 'name']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        qs = Plaintiff.objects.select_related('lawsuit').all()
        if get_user_role(user) in ('admin',):
            return qs
        return qs.filter(
            Q(lawsuit__created_by=user.id) |
            Q(lawsuit__client=user.id)
        )
    
    def get_permissions(self):
        if self.action in ['update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        lawsuit = serializer.validated_data.get('lawsuit')
        if lawsuit:
            user = self.request.user
            if get_user_role(user) == 'citizen' and lawsuit.created_by != user.id:
                from rest_framework.exceptions import PermissionDenied
                raise PermissionDenied("You can only add parties to your own lawsuits")
        serializer.save()


class DefendantViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Defendant
    """
    serializer_class = DefendantSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['gender', 'nationality', 'lawsuit']
    search_fields = ['name', 'phone', 'attorney_name']
    ordering_fields = ['created_at', 'name']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        qs = Defendant.objects.select_related('lawsuit').all()
        if get_user_role(user) in ('admin',):
            return qs
        return qs.filter(
            Q(lawsuit__created_by=user.id) |
            Q(lawsuit__client=user.id)
        )
    
    def get_permissions(self):
        if self.action in ['update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        lawsuit = serializer.validated_data.get('lawsuit')
        if lawsuit:
            user = self.request.user
            if get_user_role(user) == 'citizen' and lawsuit.created_by != user.id:
                from rest_framework.exceptions import PermissionDenied
                raise PermissionDenied("You can only add parties to your own lawsuits")
        serializer.save()
