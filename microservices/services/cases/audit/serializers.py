from rest_framework import serializers
from .models import AuditLog
from lawsuits.serializers import LawsuitSerializer


class AuditLogSerializer(serializers.ModelSerializer):
    """
    Serializer for AuditLog model (Read-only)
    """
    user_info = serializers.SerializerMethodField()
    lawsuit = LawsuitSerializer(read_only=True)
    action_type_display = serializers.CharField(source='get_action_type_display', read_only=True)
    
    class Meta:
        model = AuditLog
        fields = (
            'id', 'action_type', 'action_type_display', 'user', 'user_info', 'lawsuit',
            'description', 'metadata', 'ip_address', 'timestamp'
        )
        read_only_fields = fields

    def get_user_info(self, obj):
        u = getattr(obj, 'user', None)
        if not u:
            return None
        return {'id': u.id, 'username': u.username,
                'full_name': f'{u.first_name} {u.last_name}'.strip()}

