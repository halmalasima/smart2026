from rest_framework import serializers
from .models import Judgment
from lawsuits.serializers import LawsuitSerializer
from lawsuits.models import Lawsuit


class JudgmentSerializer(serializers.ModelSerializer):
    """
    Serializer for Judgment model
    """
    lawsuit_detail = LawsuitSerializer(source='lawsuit', read_only=True)
    lawsuit = serializers.PrimaryKeyRelatedField(
        queryset=Lawsuit.objects.all(), required=False, allow_null=True
    )
    judge_info = serializers.SerializerMethodField()
    judgment_type_display = serializers.CharField(source='get_judgment_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Judgment
        fields = (
            'id', 'lawsuit', 'lawsuit_detail', 'judgment_type', 'judgment_type_display',
            'judgment_number', 'judgment_date', 'hijri_date', 'judgment_text', 'summary',
            'judge_name', 'judge_info', 'court_name', 'status', 'status_display',
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')

    def get_judge_info(self, obj):
        u = getattr(obj, 'judge', None)
        if not u:
            return None
        return {'id': u.id, 'username': u.username,
                'full_name': f'{u.first_name} {u.last_name}'.strip()}
