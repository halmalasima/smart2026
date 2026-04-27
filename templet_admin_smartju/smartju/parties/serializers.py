from rest_framework import serializers
from .models import Plaintiff, Defendant
from lawsuits.serializers import LawsuitSerializer
from smartju.common_fields import LawsuitPrimaryKeyField


class PlaintiffSerializer(serializers.ModelSerializer):
    """
    Serializer for Plaintiff model
    """
    lawsuit = LawsuitSerializer(read_only=True)
    lawsuit_id = LawsuitPrimaryKeyField(
        source='lawsuit', 
        write_only=True,
        required=False,
        allow_null=True
    )
    gender_display = serializers.CharField(source='get_gender_display', read_only=True)
    
    class Meta:
        model = Plaintiff
        fields = (
            'id', 'lawsuit', 'lawsuit_id', 'name', 'gender', 'gender_display', 
            'nationality', 'occupation', 'address', 'phone', 'attorney_name', 
            'attorney_phone', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class DefendantSerializer(serializers.ModelSerializer):
    """
    Serializer for Defendant model
    """
    lawsuit = LawsuitSerializer(read_only=True)
    lawsuit_id = LawsuitPrimaryKeyField(
        source='lawsuit', 
        write_only=True,
        required=False,
        allow_null=True
    )
    gender_display = serializers.CharField(source='get_gender_display', read_only=True)
    
    class Meta:
        model = Defendant
        fields = (
            'id', 'lawsuit', 'lawsuit_id', 'name', 'gender', 'gender_display', 
            'nationality', 'occupation', 'address', 'phone', 'attorney_name', 
            'attorney_phone', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')
