from rest_framework import serializers
from .models import Hearing


class HearingSerializer(serializers.ModelSerializer):
    """
    Serializer for Hearing model.
    lawsuit_id is a plain integer cross-service reference (no nested object).
    """
    hearing_type_display = serializers.CharField(source='get_hearing_type_display', read_only=True)
    session_type_display = serializers.CharField(source='get_session_type_display', read_only=True)
    time_of_day_display = serializers.CharField(source='get_time_of_day_display', read_only=True)
    archive_status_display = serializers.CharField(source='get_archive_status_display', read_only=True)
    judge_username = serializers.SerializerMethodField()
    archived_by_username = serializers.SerializerMethodField()

    class Meta:
        model = Hearing
        fields = (
            'id', 'lawsuit_id', 'lawsuit_case_number', 'case_id',
            'hearing_date', 'hijri_date', 'hearing_time',
            'notes', 'judge_name', 'judge', 'judge_username',
            'hearing_type', 'hearing_type_display',
            'session_type', 'session_type_display',
            'time_of_day', 'time_of_day_display',
            'requirements', 'court_decision', 'next_session_date',
            'archive_status', 'archive_status_display',
            'archive_date', 'archive_reason', 'archived_by', 'archived_by_username',
            'is_deleted', 'deleted_at',
            'created_at', 'updated_at',
        )
        read_only_fields = (
            'id', 'created_at', 'updated_at',
            'archive_date', 'archived_by', 'is_deleted', 'deleted_at',
        )

    def get_judge_username(self, obj):
        return obj.judge.get_full_name() or obj.judge.username if obj.judge else None

    def get_archived_by_username(self, obj):
        return obj.archived_by.get_full_name() or obj.archived_by.username if obj.archived_by else None
