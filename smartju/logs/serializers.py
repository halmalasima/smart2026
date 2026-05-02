from rest_framework import serializers
from .models import UserSession, SearchLog, AIChatLog, AIConversation
from accounts.serializers import UserSerializer


class UserSessionSerializer(serializers.ModelSerializer):
    user_detail = UserSerializer(source='user', read_only=True)
    
    class Meta:
        model = UserSession
        fields = (
            'id', 'user', 'user_detail',
            'device_type', 'browser', 'ip_address',
            'country', 'governorate', 'city',
            'login_time', 'logout_time', 'is_active'
        )
        read_only_fields = ('id', 'login_time')


class SearchLogSerializer(serializers.ModelSerializer):
    user_detail = UserSerializer(source='user', read_only=True)
    
    class Meta:
        model = SearchLog
        fields = (
            'id', 'user', 'user_detail',
            'search_query', 'search_date', 'results_count'
        )
        read_only_fields = ('id', 'search_date')


class AIConversationSerializer(serializers.ModelSerializer):
    messages_count = serializers.SerializerMethodField()
    
    class Meta:
        model = AIConversation
        fields = (
            'id', 'title', 'is_archived', 'is_favorite',
            'created_at', 'updated_at', 'messages_count'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')
    
    def get_messages_count(self, obj):
        return obj.messages.count()


class AIChatLogSerializer(serializers.ModelSerializer):
    user_detail = UserSerializer(source='user', read_only=True)
    
    class Meta:
        model = AIChatLog
        fields = (
            'id', 'user', 'user_detail', 'conversation',
            'question', 'answer', 'model_version', 'created_at'
        )
        read_only_fields = ('id', 'created_at')


