from rest_framework import serializers
from .models import AuditLog
from lawsuits.serializers import LawsuitSerializer
from accounts.serializers import UserSerializer


class AuditLogSerializer(serializers.ModelSerializer):
    """
    Serializer for AuditLog model (Read-only)
    """
    user = UserSerializer(read_only=True)
    lawsuit = LawsuitSerializer(read_only=True)
    action_type_display = serializers.CharField(source='get_action_type_display', read_only=True)
    
    class Meta:
        model = AuditLog
        fields = (
            'id', 'action_type', 'action_type_display', 'user', 'lawsuit',
            'description', 'metadata', 'ip_address', 'timestamp'
        )
        read_only_fields = fields  # All fields are read-only

