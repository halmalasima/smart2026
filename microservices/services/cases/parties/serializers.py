from rest_framework import serializers
from .models import Plaintiff, Defendant
from lawsuits.serializers import LawsuitSerializer
from lawsuits.models import Lawsuit


class PlaintiffSerializer(serializers.ModelSerializer):
    """
    Serializer for Plaintiff model
    """
    lawsuit_detail = LawsuitSerializer(source='lawsuit', read_only=True)
    lawsuit = serializers.PrimaryKeyRelatedField(
        queryset=Lawsuit.objects.all(), required=False, allow_null=True
    )
    gender_display = serializers.CharField(source='get_gender_display', read_only=True)

    class Meta:
        model = Plaintiff
        fields = (
            'id', 'lawsuit', 'lawsuit_detail', 'name', 'gender', 'gender_display',
            'nationality', 'occupation', 'address', 'phone', 'attorney_name',
            'attorney_phone', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class DefendantSerializer(serializers.ModelSerializer):
    """
    Serializer for Defendant model
    """
    lawsuit_detail = LawsuitSerializer(source='lawsuit', read_only=True)
    lawsuit = serializers.PrimaryKeyRelatedField(
        queryset=Lawsuit.objects.all(), required=False, allow_null=True
    )
    gender_display = serializers.CharField(source='get_gender_display', read_only=True)

    class Meta:
        model = Defendant
        fields = (
            'id', 'lawsuit', 'lawsuit_detail', 'name', 'gender', 'gender_display',
            'nationality', 'occupation', 'address', 'phone', 'attorney_name',
            'attorney_phone', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')
