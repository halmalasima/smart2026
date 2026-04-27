from rest_framework import viewsets, filters, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django_filters import rest_framework as django_filters
from django.db.models import Q
from django.utils import timezone
from django.contrib.auth.models import User
from .models import Hearing
from .serializers import HearingSerializer
from rest_framework.permissions import IsAuthenticated as IsJudgeOrLawyerOrAdmin


class HearingFilter(django_filters.FilterSet):
    """
    Advanced filter for Hearing - فلترة متقدمة للجلسات
    """
    # Date range filters
    hearing_date_from = django_filters.DateFilter(
        field_name='hearing_date', lookup_expr='gte',
        label='تاريخ الجلسة من'
    )
    hearing_date_to = django_filters.DateFilter(
        field_name='hearing_date', lookup_expr='lte',
        label='تاريخ الجلسة إلى'
    )
    created_from = django_filters.DateFilter(
        field_name='created_at', lookup_expr='gte',
        label='تاريخ الإنشاء من'
    )
    created_to = django_filters.DateFilter(
        field_name='created_at', lookup_expr='lte',
        label='تاريخ الإنشاء إلى'
    )
    
    # Archive status
    archive_status = django_filters.ChoiceFilter(
        choices=Hearing.ARCHIVE_STATUS_CHOICES,
        label='حالة الأرشفة'
    )
    
    # Exclude soft-deleted by default
    include_deleted = django_filters.BooleanFilter(
        method='filter_include_deleted',
        label='تضمين المحذوفة'
    )
    
    class Meta:
        model = Hearing
        fields = ['hearing_type', 'lawsuit_id', 'case_id', 'judge', 'hearing_date', 'session_type', 'archive_status']
    
    def filter_include_deleted(self, queryset, name, value):
        """Include soft-deleted items"""
        if value:
            return queryset
        return queryset.filter(is_deleted=False)


class HearingViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Hearing - المحامون والقضاة يمكنهم إنشاء الجلسات
    """
    serializer_class = HearingSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = HearingFilter
    search_fields = ['notes', 'judge_name']
    ordering_fields = ['created_at', 'hearing_date', 'archive_date']
    ordering = ['-hearing_date', '-hearing_time']

    def get_queryset(self):
        user = self.request.user
        queryset = Hearing.objects.select_related('judge', 'created_by', 'archived_by')

        # Filter out soft-deleted by default
        if not self.request.query_params.get('include_deleted'):
            queryset = queryset.filter(is_deleted=False)

        from smartjudi_common.user_utils import get_user_role
        if get_user_role(user) == 'admin':
            return queryset

        # Filter to hearings created by or presided over by this user
        return queryset.filter(
            Q(created_by=user.id) | Q(judge=user.id)
        ).distinct()

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy', 'archive', 'unarchive', 'restore']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        uid = self.request.user.id
        username = getattr(self.request.user, 'username', None) or f'user_{uid}'
        user, _ = User.objects.get_or_create(
            id=uid,
            defaults={'username': username},
        )
        serializer.save(created_by=user)
    
    def perform_destroy(self, instance):
        """Soft delete instead of hard delete"""
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=['is_deleted', 'deleted_at'])
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """
        Archive a hearing session - أرشفة جلسة
        POST /api/hearings/{id}/archive/
        Body: {"archive_reason": "reason for archiving"}
        """
        hearing = self.get_object()
        archive_reason = request.data.get('archive_reason', '')
        
        uid = request.user.id
        username = getattr(request.user, 'username', None) or f'user_{uid}'
        archiver, _ = User.objects.get_or_create(
            id=uid, defaults={'username': username},
        )
        hearing.archive_status = Hearing.ARCHIVE_ARCHIVED
        hearing.archive_date = timezone.now()
        hearing.archive_reason = archive_reason
        hearing.archived_by = archiver
        hearing.save(update_fields=[
            'archive_status', 'archive_date', 'archive_reason', 'archived_by'
        ])
        
        serializer = self.get_serializer(hearing)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['post'])
    def unarchive(self, request, pk=None):
        """
        Restore a hearing session from archive - استعادة جلسة من الأرشيف
        POST /api/hearings/{id}/unarchive/
        """
        hearing = self.get_object()
        hearing.archive_status = Hearing.ARCHIVE_ACTIVE
        hearing.archive_date = None
        hearing.archive_reason = None
        hearing.archived_by = None
        hearing.save(update_fields=[
            'archive_status', 'archive_date', 'archive_reason', 'archived_by'
        ])
        
        serializer = self.get_serializer(hearing)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['post'])
    def restore(self, request, pk=None):
        """
        Restore a soft-deleted hearing session - استعادة جلسة محذوفة
        POST /api/hearings/{id}/restore/
        """
        try:
            hearing = Hearing.objects.get(pk=pk, is_deleted=True)
        except Hearing.DoesNotExist:
            return Response(
                {'error': 'الجلسة غير موجودة أو غير محذوفة'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        hearing.is_deleted = False
        hearing.deleted_at = None
        hearing.save(update_fields=['is_deleted', 'deleted_at'])
        
        serializer = self.get_serializer(hearing)
        return Response(serializer.data)
