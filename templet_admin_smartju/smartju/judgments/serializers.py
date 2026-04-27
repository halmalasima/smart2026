from rest_framework import serializers
from .models import Judgment
from lawsuits.serializers import LawsuitSerializer
from accounts.serializers import UserSerializer
from smartju.common_fields import LawsuitPrimaryKeyField


class JudgmentSerializer(serializers.ModelSerializer):
    """
    Serializer for Judgment model
    """
    lawsuit = LawsuitSerializer(read_only=True)
    lawsuit_id = LawsuitPrimaryKeyField(
        source='lawsuit', 
        write_only=True,
        required=False,
        allow_null=True
    )
    judge = UserSerializer(read_only=True)
    judgment_type_display = serializers.CharField(source='get_judgment_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Judgment
        fields = (
            'id', 'lawsuit', 'lawsuit_id', 'judgment_type', 'judgment_type_display',
            'judgment_number', 'judgment_date', 'hijri_date', 'judgment_text', 'summary',
            'judge_name', 'judge', 'court_name', 'status', 'status_display',
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')
