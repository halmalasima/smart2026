from rest_framework import serializers
from .models import Lawyer, LawyerFilterOptions


class LawyerSerializer(serializers.ModelSerializer):
    """
    Serializer for Lawyer model
    """
    
    class Meta:
        model = Lawyer
        fields = (
            'id',
            'user',
            'registration_number',
            'name',
            'grade',
            'branch',
            'phone',
            'governorate',
            'directorate',
            'neighborhood',
            'address_details',
            'office_type',
            'notes',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class LawyerFilterOptionsSerializer(serializers.ModelSerializer):
    """Serializer for LawyerFilterOptions model"""
    
    class Meta:
        model = LawyerFilterOptions
        fields = (
            'id',
            'option_type',
            'option_value',
            'display_name',
            'is_active',
            'sort_order',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('id', 'created_at', 'updated_at')
