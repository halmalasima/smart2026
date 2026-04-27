from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Message

class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.get_full_name', read_only=True)
    recipient_name = serializers.CharField(source='recipient.get_full_name', read_only=True)
    
    class Meta:
        model = Message
        fields = (
            'id', 'sender', 'sender_name', 'recipient', 'recipient_name', 
            'lawsuit', 'content', 'attachment', 'is_read', 'created_at'
        )
        read_only_fields = ('id', 'created_at', 'sender', 'sender_name', 'recipient_name')

    def create(self, validated_data):
        # Allow views to set the sender
        return super().create(validated_data)
