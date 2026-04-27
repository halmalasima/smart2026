from rest_framework import serializers
from .models import Hearing
from lawsuits.serializers import LawsuitMinimalSerializer
from accounts.serializers import UserSerializer
from smartju.common_fields import LawsuitPrimaryKeyField


class HearingSerializer(serializers.ModelSerializer):
    """
    Serializer for Hearing model
    Uses LawsuitMinimalSerializer for read responses
    """
    lawsuit = LawsuitMinimalSerializer(read_only=True)
    lawsuit_id = LawsuitPrimaryKeyField(
        source='lawsuit', 
        write_only=True,
        required=False,
        allow_null=True
    )
    judge = UserSerializer(read_only=True)
    archived_by = UserSerializer(read_only=True)
    hearing_type_display = serializers.CharField(source='get_hearing_type_display', read_only=True)
    archive_status_display = serializers.CharField(source='get_archive_status_display', read_only=True)
    
    class Meta:
        model = Hearing
        fields = (
            'id', 'lawsuit', 'lawsuit_id', 'hearing_date', 'hijri_date', 'hearing_time',
            'notes', 'judge_name', 'judge', 'hearing_type', 'hearing_type_display',
            # Archive fields
            'archive_status', 'archive_status_display',
            'archive_date', 'archive_reason', 'archived_by',
            'is_deleted', 'deleted_at',
            # Timestamps
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at', 'archive_date', 'archived_by', 'is_deleted', 'deleted_at')
