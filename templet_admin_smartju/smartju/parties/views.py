from rest_framework import viewsets, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q
from .models import Plaintiff, Defendant
from .serializers import PlaintiffSerializer, DefendantSerializer
from accounts.permissions import IsJudgeOrLawyerOrAdmin


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
        if user.is_superuser:
            return qs
        if hasattr(user, 'profile') and user.profile.role == 'admin':
            return qs
        return qs.filter(
            Q(lawsuit__created_by=user) |
            Q(lawsuit__client=user)
        )
    
    def get_permissions(self):
        # Allow all authenticated users to create parties for their own lawsuits
        # Only restrict update/delete to judges, lawyers, and admins
        if self.action in ['update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        # Verify user owns the lawsuit or is judge/lawyer/admin
        lawsuit = serializer.validated_data.get('lawsuit')
        if lawsuit:
            user = self.request.user
            if hasattr(user, 'profile'):
                user_role = user.profile.role
                # Citizens can only add parties to their own lawsuits
                if user_role == 'citizen' and lawsuit.created_by != user:
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
        if user.is_superuser:
            return qs
        if hasattr(user, 'profile') and user.profile.role == 'admin':
            return qs
        return qs.filter(
            Q(lawsuit__created_by=user) |
            Q(lawsuit__client=user)
        )
    
    def get_permissions(self):
        # Allow all authenticated users to create parties for their own lawsuits
        # Only restrict update/delete to judges, lawyers, and admins
        if self.action in ['update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        # Verify user owns the lawsuit or is judge/lawyer/admin
        lawsuit = serializer.validated_data.get('lawsuit')
        if lawsuit:
            user = self.request.user
            if hasattr(user, 'profile'):
                user_role = user.profile.role
                # Citizens can only add parties to their own lawsuits
                if user_role == 'citizen' and lawsuit.created_by != user:
                    from rest_framework.exceptions import PermissionDenied
                    raise PermissionDenied("You can only add parties to your own lawsuits")
        serializer.save()
