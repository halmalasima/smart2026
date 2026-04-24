from rest_framework import viewsets, filters
from rest_framework.pagination import PageNumberPagination
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q, Count
from .models import Lawyer, LawyerFilterOptions
from .serializers import LawyerSerializer, LawyerFilterOptionsSerializer


class LawyerPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class LawyerViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Lawyer model with search and filtering
    """
    queryset = Lawyer.objects.all()
    serializer_class = LawyerSerializer
    pagination_class = LawyerPagination
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['branch', 'grade']
    search_fields = ['name', 'registration_number', 'governorate', 'neighborhood', 'branch']
    ordering_fields = ['name', 'registration_number', 'created_at']
    ordering = ['registration_number']

    from rest_framework.decorators import action

    @action(detail=False, methods=['get'])
    def branches(self, request):
        """Get list of distinct branches"""
        branches = Lawyer.objects.values_list('branch', flat=True).distinct().exclude(branch__isnull=True).exclude(branch='')
        return Response({'branches': list(branches)})

    @action(detail=False, methods=['get'])
    def grades(self, request):
        """Get list of distinct grades"""
        grades = Lawyer.objects.values_list('grade', flat=True).distinct().exclude(grade__isnull=True).exclude(grade='')
        return Response({'grades': list(grades)})

    @action(detail=False, methods=['get'])
    def my_stats(self, request):
        """
        Get statistics for the current lawyer user.
        Fetches lawsuit stats from cases-service via internal API.
        """
        import os
        import httpx

        cases_url = os.environ.get('CASES_SERVICE_URL', 'http://cases:8000')
        token = request.META.get('HTTP_AUTHORIZATION', '')
        try:
            with httpx.Client(timeout=5.0) as client:
                resp = client.get(
                    f'{cases_url}/api/lawsuits/my_stats/',
                    headers={'Authorization': token},
                )
            if resp.status_code == 200:
                return Response(resp.json())
            return Response({'error': 'cases-service unavailable'}, status=resp.status_code)
        except Exception as exc:
            return Response({'error': str(exc)}, status=503)


class LawyerFilterOptionsViewSet(viewsets.ModelViewSet):
    """
    ViewSet for LawyerFilterOptions model - manages filter options (branches and grades)
    """
    queryset = LawyerFilterOptions.objects.filter(is_active=True)
    serializer_class = LawyerFilterOptionsSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['option_type', 'is_active']
    ordering_fields = ['option_type', 'sort_order', 'display_name']
    ordering = ['option_type', 'sort_order', 'display_name']

    @action(detail=False, methods=['get'])
    def branches(self, request):
        """Get list of active branches"""
        branches = LawyerFilterOptions.objects.filter(
            option_type='branch',
            is_active=True
        ).order_by('sort_order', 'display_name')
        serializer = self.get_serializer(branches, many=True)
        return Response({
            'branches': [item['display_name'] for item in serializer.data]
        })

    @action(detail=False, methods=['get'])
    def grades(self, request):
        """Get list of active grades"""
        grades = LawyerFilterOptions.objects.filter(
            option_type='grade',
            is_active=True
        ).order_by('sort_order', 'display_name')
        serializer = self.get_serializer(grades, many=True)
        return Response({
            'grades': [item['display_name'] for item in serializer.data]
        })
