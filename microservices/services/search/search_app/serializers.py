from rest_framework import serializers
from .models import UserSession, SearchLog, AIChatLog


class UserSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSession
        fields = (
            'id', 'user_id',
            'device_type', 'browser', 'ip_address',
            'country', 'governorate', 'city',
            'login_time', 'logout_time', 'is_active'
        )
        read_only_fields = ('id', 'login_time')


class SearchLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = SearchLog
        fields = (
            'id', 'user_id',
            'search_query', 'search_date', 'results_count'
        )
        read_only_fields = ('id', 'search_date')


class AIChatLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIChatLog
        fields = (
            'id', 'user_id',
            'question', 'answer', 'model_version', 'created_at'
        )
        read_only_fields = ('id', 'created_at')
