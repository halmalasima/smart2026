from rest_framework import serializers
from .models import Attachment
from lawsuits.serializers import LawsuitMinimalSerializer
from smartju.common_fields import LawsuitPrimaryKeyField


class AttachmentSerializer(serializers.ModelSerializer):
    """
    Serializer for Attachment model
    Uses LawsuitMinimalSerializer for read to avoid heavy nested payloads
    """
    lawsuit = LawsuitMinimalSerializer(read_only=True)
    lawsuit_id = LawsuitPrimaryKeyField(
        source='lawsuit', 
        write_only=True,
        required=True,
    )
    document_type_display = serializers.CharField(source='get_document_type_display', read_only=True)
    file_url = serializers.SerializerMethodField()
    file_size_display = serializers.CharField(source='get_file_size_display', read_only=True)
    
    class Meta:
        model = Attachment
        fields = (
            'id', 'lawsuit', 'lawsuit_id', 'document_type', 'document_type_display',
            'gregorian_date', 'hijri_date', 'page_count', 'content', 'evidence_basis',
            'file', 'file_url', 'original_filename', 'file_size', 'file_size_display',
            'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')
        extra_kwargs = {
            'hijri_date': {'required': False, 'allow_blank': True},
            'gregorian_date': {'required': False},
            'content': {'required': False, 'allow_blank': True},
            'evidence_basis': {'required': False, 'allow_blank': True},
            'file': {'required': False, 'allow_null': True},
            'page_count': {'required': False},
        }
    
    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None
