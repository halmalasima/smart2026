from rest_framework import serializers
from .models import Response
from lawsuits.serializers import LawsuitSerializer
from accounts.serializers import UserSerializer
from smartju.common_fields import LawsuitPrimaryKeyField


class ResponseSerializer(serializers.ModelSerializer):
    """
    Serializer for Response model
    """
    lawsuit = LawsuitSerializer(read_only=True)
    lawsuit_id = LawsuitPrimaryKeyField(
        source='lawsuit', 
        write_only=True,
        required=False,
        allow_null=True
    )
    submitted_by_user = UserSerializer(read_only=True)
    submitted_by_display = serializers.CharField(source='get_submitted_by_display', read_only=True)
    response_type_display = serializers.CharField(source='get_response_type_display', read_only=True)
    
    class Meta:
        model = Response
        fields = (
            'id', 'lawsuit', 'lawsuit_id', 'response_text', 'submitted_by', 
            'submitted_by_user', 'submitted_by_display', 'submission_date', 
            'hijri_date', 'response_type', 'response_type_display', 
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')
