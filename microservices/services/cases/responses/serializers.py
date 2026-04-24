from rest_framework import serializers
from .models import Response
from lawsuits.serializers import LawsuitSerializer
from lawsuits.models import Lawsuit


class ResponseSerializer(serializers.ModelSerializer):
    """
    Serializer for Response model
    """
    lawsuit_detail = LawsuitSerializer(source='lawsuit', read_only=True)
    lawsuit = serializers.PrimaryKeyRelatedField(
        queryset=Lawsuit.objects.all(), required=False, allow_null=True
    )
    submitted_by_user = serializers.SerializerMethodField()
    submitted_by_display = serializers.CharField(source='get_submitted_by_display', read_only=True)
    response_type_display = serializers.CharField(source='get_response_type_display', read_only=True)
    
    class Meta:
        model = Response
        fields = (
            'id', 'lawsuit', 'lawsuit_detail', 'response_text', 'submitted_by',
            'submitted_by_user', 'submitted_by_display', 'submission_date',
            'hijri_date', 'response_type', 'response_type_display',
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')

    def get_submitted_by_user(self, obj):
        u = getattr(obj, 'submitted_by_user', None)
        if not u:
            return None
        return {'id': u.id, 'username': u.username,
                'full_name': f'{u.first_name} {u.last_name}'.strip()}
