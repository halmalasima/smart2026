from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import UserSession, SearchLog, AIChatLog, AIConversation
from .serializers import (
    UserSessionSerializer, SearchLogSerializer,
    AIChatLogSerializer, AIConversationSerializer
)


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
    filterset_fields = []
    search_fields = ['search_query']
    ordering_fields = ['search_date']
    ordering = ['-search_date']

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)


class AIConversationViewSet(viewsets.ModelViewSet):
    """ViewSet لإدارة محادثات المساعد الذكي"""
    serializer_class = AIConversationSerializer
    permission_classes = [IsAuthenticated]
    ordering = ['-updated_at']

    def get_queryset(self):
        qs = AIConversation.objects.filter(user=self.request.user)
        is_archived = self.request.query_params.get('is_archived')
        if is_archived is not None:
            qs = qs.filter(is_archived=is_archived.lower() == 'true')
        return qs.order_by('-updated_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['get'], url_path='messages')
    def messages(self, request, pk=None):
        """جلب جميع رسائل محادثة معينة"""
        conversation = self.get_object()
        logs = conversation.messages.all().order_by('created_at')
        serializer = AIChatLogSerializer(logs, many=True)
        return Response(serializer.data)


class AIChatLogViewSet(viewsets.ModelViewSet):
    queryset = AIChatLog.objects.select_related('user', 'conversation').all()
    serializer_class = AIChatLogSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['model_version', 'conversation']
    search_fields = ['question', 'answer']
    ordering_fields = ['created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


