from rest_framework import serializers
from .models import UserSession, SearchLog, AIChatLog
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


class AIChatLogSerializer(serializers.ModelSerializer):
    user_detail = UserSerializer(source='user', read_only=True)
    
    class Meta:
        model = AIChatLog
        fields = (
            'id', 'user', 'user_detail',
            'question', 'answer', 'model_version', 'created_at'
        )
        read_only_fields = ('id', 'created_at')

