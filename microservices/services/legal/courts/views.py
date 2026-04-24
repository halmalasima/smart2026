from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import Governorate, District, CourtType, CourtSpecialization, Court
from .serializers import (
    GovernorateSerializer, DistrictSerializer, CourtTypeSerializer,
    CourtSpecializationSerializer, CourtSerializer
)


class GovernorateViewSet(viewsets.ModelViewSet):
    queryset = Governorate.objects.prefetch_related('courts').all()
    serializer_class = GovernorateSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['name']
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']


class DistrictViewSet(viewsets.ModelViewSet):
    queryset = District.objects.select_related('governorate').all()
    serializer_class = DistrictSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['governorate', 'name']
    search_fields = ['name', 'governorate__name']
    ordering_fields = ['governorate', 'name', 'created_at']
    ordering = ['governorate', 'name']


class CourtTypeViewSet(viewsets.ModelViewSet):
    queryset = CourtType.objects.all()
    serializer_class = CourtTypeSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['judicial_level']
    search_fields = ['name']
    ordering_fields = ['judicial_level', 'name', 'created_at']
    ordering = ['judicial_level', 'name']


class CourtSpecializationViewSet(viewsets.ModelViewSet):
    queryset = CourtSpecialization.objects.all()
    serializer_class = CourtSpecializationSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = []
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']


class CourtViewSet(viewsets.ModelViewSet):
    queryset = Court.objects.select_related(
        'court_type', 'governorate', 'district'
    ).prefetch_related('specializations').all()
    serializer_class = CourtSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['court_type', 'governorate', 'district', 'is_active']
    search_fields = ['name', 'address']
    ordering_fields = ['name', 'governorate', 'created_at']
    ordering = ['governorate', 'name']

