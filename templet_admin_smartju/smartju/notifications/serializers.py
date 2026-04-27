from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            'id', 'recipient', 'notification_type', 'title', 'body',
            'is_read', 'related_object_id', 'related_object_type',
            'created_at',
        ]
        read_only_fields = ['id', 'recipient', 'created_at']
