from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import UserSession, SearchLog, AIChatLog, AIConversation
from .serializers import (
    UserSessionSerializer, SearchLogSerializer, 
    AIChatLogSerializer, AIConversationSerializer
)


class UserSessionViewSet(viewsets.ModelViewSet):
    queryset = UserSession.objects.all()
    serializer_class = UserSessionSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['is_active', 'device_type', 'governorate']
    search_fields = ['ip_address', 'country', 'city']
    ordering_fields = ['login_time', 'created_at']
    ordering = ['-login_time']

    def get_queryset(self):
        return self.queryset.filter(user_id=self.request.user.id)


class SearchLogViewSet(viewsets.ModelViewSet):
    queryset = SearchLog.objects.all()
    serializer_class = SearchLogSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = []
    search_fields = ['search_query']
    ordering_fields = ['search_date']
    ordering = ['-search_date']

    def get_queryset(self):
        return self.queryset.filter(user_id=self.request.user.id)


class AIConversationViewSet(viewsets.ModelViewSet):
    queryset = AIConversation.objects.all()
    serializer_class = AIConversationSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['is_archived', 'is_favorite']
    search_fields = ['title']
    ordering_fields = ['updated_at', 'created_at']
    ordering = ['-updated_at']

    def get_queryset(self):
        return self.queryset.filter(user_id=self.request.user.id)

    def perform_create(self, serializer):
        serializer.save(user_id=self.request.user.id)

    @action(detail=True, methods=['get'])
    def messages(self, request, pk=None):
        conversation = self.get_object()
        messages = conversation.messages.all()
        serializer = AIChatLogSerializer(messages, many=True)
        return Response(serializer.data)


class AIChatLogViewSet(viewsets.ModelViewSet):
    queryset = AIChatLog.objects.all()
    serializer_class = AIChatLogSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['model_version', 'conversation']
    search_fields = ['question', 'answer']
    ordering_fields = ['created_at']
    ordering = ['created_at']

    def get_queryset(self):
        return self.queryset.filter(user_id=self.request.user.id)

    def perform_create(self, serializer):
        # Update conversation's updated_at timestamp when a new message is added
        log = serializer.save(user_id=self.request.user.id)
        if log.conversation:
            log.conversation.save() # Triggers auto_now update

