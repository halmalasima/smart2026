from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import UserSession, SearchLog, AIChatLog
from .serializers import UserSessionSerializer, SearchLogSerializer, AIChatLogSerializer


class UserSessionViewSet(viewsets.ModelViewSet):
    queryset = UserSession.objects.select_related('user').all()
    serializer_class = UserSessionSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['is_active', 'device_type', 'governorate']
    search_fields = ['ip_address', 'country', 'city']
    ordering_fields = ['login_time', 'created_at']
    ordering = ['-login_time']

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)


class SearchLogViewSet(viewsets.ModelViewSet):
    queryset = SearchLog.objects.select_related('user').all()
    serializer_class = SearchLogSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = []  # No need for user filter if it's already filtered
    search_fields = ['search_query']
    ordering_fields = ['search_date']
    ordering = ['-search_date']

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)


class AIChatLogViewSet(viewsets.ModelViewSet):
    queryset = AIChatLog.objects.select_related('user').all()
    serializer_class = AIChatLogSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['model_version']
    search_fields = ['question', 'answer']
    ordering_fields = ['created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

