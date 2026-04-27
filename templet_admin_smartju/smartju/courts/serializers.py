from rest_framework import serializers
from .models import Governorate, District, CourtType, CourtSpecialization, Court


class GovernorateSerializer(serializers.ModelSerializer):
    # إضافة المحاكم التابعة للمحافظة
    courts = serializers.SerializerMethodField()
    courts_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Governorate
        fields = ('id', 'name', 'courts', 'courts_count', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')
    
    def get_courts(self, obj):
        """إرجاع قائمة المحاكم التابعة لهذه المحافظة"""
        courts = obj.courts.filter(is_active=True).order_by('name')
        return [{'id': court.id, 'name': court.name} for court in courts]
    
    def get_courts_count(self, obj):
        """إرجاع عدد المحاكم التابعة لهذه المحافظة"""
        return obj.courts.filter(is_active=True).count()


class DistrictSerializer(serializers.ModelSerializer):
    governorate_name = serializers.CharField(source='governorate.name', read_only=True)
    
    class Meta:
        model = District
        fields = ('id', 'governorate', 'governorate_name', 'name', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class CourtTypeSerializer(serializers.ModelSerializer):
    judicial_level_display = serializers.CharField(source='get_judicial_level_display', read_only=True)
    
    class Meta:
        model = CourtType
        fields = ('id', 'name', 'judicial_level', 'judicial_level_display', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class CourtSpecializationSerializer(serializers.ModelSerializer):
    class Meta:
        model = CourtSpecialization
        fields = ('id', 'name', 'description', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class CourtSerializer(serializers.ModelSerializer):
    court_type_name = serializers.CharField(source='court_type.name', read_only=True)
    governorate_name = serializers.CharField(source='governorate.name', read_only=True)
    district_name = serializers.CharField(source='district.name', read_only=True)
    specializations = CourtSpecializationSerializer(many=True, read_only=True)
    specialization_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=CourtSpecialization.objects.all(),
        source='specializations',
        write_only=True,
        required=False
    )
    
    class Meta:
        model = Court
        fields = (
            'id', 'name', 'court_type', 'court_type_name',
            'governorate', 'governorate_name',
            'district', 'district_name',
            'address', 'location_url', 'latitude', 'longitude',
            'specializations', 'specialization_ids',
            'is_active', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')

