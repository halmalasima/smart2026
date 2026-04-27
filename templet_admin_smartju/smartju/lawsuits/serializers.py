from rest_framework import serializers
from .models import Case, CaseParty, Lawsuit, LegalTemplate, FinancialClaim
from .models_casefile import CaseFileItem
from accounts.serializers import UserSerializer
from courts.serializers import CourtSerializer


class LawsuitMinimalSerializer(serializers.ModelSerializer):
    """
    Lightweight serializer for Lawsuit - used in FK references to avoid 
    heavy nested serialization that causes performance issues
    """
    case_type_display = serializers.CharField(source='get_case_type_display', read_only=True)
    case_status_display = serializers.CharField(source='get_case_status_display', read_only=True)
    
    class Meta:
        model = Lawsuit
        fields = (
            'id', 'case_number', 'subject', 'case_type', 'case_type_display',
            'case_status', 'case_status_display', 'court', 'filing_date',
        )
        read_only_fields = fields


class CasePartySerializer(serializers.ModelSerializer):
    """Serializer for CaseParty (طرف القضية)"""
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    entity_type_display = serializers.CharField(source='get_entity_type_display', read_only=True)
    generated_password = serializers.CharField(read_only=True, required=False)

    class Meta:
        model = CaseParty
        fields = (
            'id', 'case', 'role', 'role_display',
            'entity_type', 'entity_type_display',
            'name', 'phone', 'id_number', 'id_issued_from', 'id_date',
            'address', 'nationality',
            'user_account', 'generated_password',
            'created_at', 'updated_at',
        )
        read_only_fields = ('id', 'user_account', 'created_at', 'updated_at')


class CaseSerializer(serializers.ModelSerializer):
    """Serializer for Case (قضية)"""

    created_by_detail = serializers.SerializerMethodField()
    client_name = serializers.SerializerMethodField()
    court_detail = CourtSerializer(source='court_fk', read_only=True)
    case_status_display = serializers.CharField(source='get_case_status_display', read_only=True)
    case_type_display = serializers.CharField(source='get_case_type_display', read_only=True)
    parties = CasePartySerializer(many=True, read_only=True)

    class Meta:
        model = Case
        fields = (
            'id', 'case_number',
            'filing_date', 'gregorian_date', 'hijri_date', 'case_year_hijri',
            'case_status', 'case_status_display',
            'case_type', 'case_type_display', 'case_subtype',
            'governorate',
            'court_fk', 'court_detail', 'court',
            'subject', 'description',
            'client', 'client_name',
            'created_by', 'created_by_detail',
            'parties',
            'created_at', 'updated_at',
        )
        read_only_fields = ('id', 'created_at', 'updated_at', 'created_by')

    def get_client_name(self, obj):
        if obj.client:
            return f"{obj.client.first_name} {obj.client.last_name}".strip() or obj.client.username
        return None

    def get_created_by_detail(self, obj):
        if obj.created_by:
            return {
                'id': obj.created_by.id,
                'username': obj.created_by.username,
                'first_name': obj.created_by.first_name,
                'last_name': obj.created_by.last_name,
                'role': obj.created_by.profile.role if hasattr(obj.created_by, 'profile') else 'unknown'
            }
        return None



class LegalTemplateSerializer(serializers.ModelSerializer):
    """
    Serializer for LegalTemplate model
    """
    case_type_display = serializers.CharField(source='get_case_type_display', read_only=True)
    
    class Meta:
        model = LegalTemplate
        fields = (
            'id', 'case_type', 'case_type_display', 'section_key', 
            'section_title', 'default_text', 'is_required'
        )
        read_only_fields = ('id',)


class FinancialClaimSerializer(serializers.ModelSerializer):
    """
    Serializer for FinancialClaim model
    """
    currency_display = serializers.CharField(source='get_currency_display', read_only=True)
    
    class Meta:
        model = FinancialClaim
        fields = (
            'id', 'lawsuit', 'amount', 'currency', 'currency_display', 
            'due_date', 'description', 'created_at'
        )
        read_only_fields = ('id', 'created_at')


class LawsuitSerializer(serializers.ModelSerializer):
    """
    Serializer for Lawsuit model - with archive fields
    """
    created_by = UserSerializer(read_only=True)
    archived_by = UserSerializer(read_only=True)
    case_type_display = serializers.CharField(source='get_case_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    case_status_display = serializers.CharField(source='get_case_status_display', read_only=True)
    archive_status_display = serializers.CharField(source='get_archive_status_display', read_only=True)
    court_detail = CourtSerializer(source='court_fk', read_only=True)
    case_detail = CaseSerializer(source='case', read_only=True)
    financial_claims = FinancialClaimSerializer(many=True, read_only=True)
    child_lawsuits_count = serializers.SerializerMethodField()
    plaintiffs_count = serializers.SerializerMethodField()
    defendants_count = serializers.SerializerMethodField()
    attachments_count = serializers.SerializerMethodField()
    hearings_count = serializers.SerializerMethodField()
    client_name = serializers.SerializerMethodField()
    created_by_detail = serializers.SerializerMethodField()
    
    class Meta:
        model = Lawsuit
        fields = (
            'case', 'case_detail',
            'id', 'case_number', 'filing_date', 'gregorian_date', 'hijri_date', 
            'case_year_hijri',
            'case_type', 'case_type_display', 
            'case_subtype',
            'case_status', 'case_status_display',
            'governorate',
            'court_fk', 'court_detail', 'court', 
            'subject', 'description', 'facts', 'legal_basis', 'legal_reasons', 'reasons', 
            'requests', 'status', 'status_display', 'notes',
            # Archive fields
            'archive_status', 'archive_status_display',
            'archive_date', 'archive_reason', 'archived_by',
            'is_deleted', 'deleted_at',
            'parent_lawsuit',
            # Counts
            'child_lawsuits_count', 'plaintiffs_count', 'defendants_count',
            'attachments_count', 'hearings_count',
            # Timestamps
            'created_by', 'created_at', 'updated_at',
            'financial_claims', 'client', 'client_name', 'created_by_detail'
        )
        read_only_fields = ('id', 'created_at', 'updated_at', 'archive_date', 'archived_by', 'is_deleted', 'deleted_at')
    
    def get_client_name(self, obj):
        if obj.client:
            return f"{obj.client.first_name} {obj.client.last_name}".strip() or obj.client.username
        return None

    def get_created_by_detail(self, obj):
        if obj.created_by:
            return {
                'id': obj.created_by.id,
                'username': obj.created_by.username,
                'first_name': obj.created_by.first_name,
                'last_name': obj.created_by.last_name,
                'role': obj.created_by.profile.role if hasattr(obj.created_by, 'profile') else 'unknown'
            }
        return None
    
    def get_child_lawsuits_count(self, obj):
        return obj.child_lawsuits.count() if hasattr(obj, 'child_lawsuits') else 0
    
    def get_plaintiffs_count(self, obj):
        return obj.plaintiffs.count() if hasattr(obj, 'plaintiffs') else 0
    
    def get_defendants_count(self, obj):
        return obj.defendants.count() if hasattr(obj, 'defendants') else 0
    
    def get_attachments_count(self, obj):
        return obj.attachments.count() if hasattr(obj, 'attachments') else 0
    
    def get_hearings_count(self, obj):
        return obj.hearings.count() if hasattr(obj, 'hearings') else 0


class LawsuitCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating Lawsuit
    """
    class Meta:
        model = Lawsuit
        fields = (
            'id', 'case_number', 'filing_date', 'gregorian_date', 'hijri_date', 
            'case_year_hijri',
            'case', 'case_type', 'case_subtype', 'case_status', 'governorate',
            'court_fk', 'court', 'subject', 'description', 
            'facts', 'legal_basis', 'legal_reasons', 'reasons', 'requests', 
            'status', 'notes', 'parent_lawsuit'
        )


class LawsuitUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating Lawsuit
    """
    class Meta:
        model = Lawsuit
        fields = (
            'case_number', 'filing_date', 'gregorian_date', 'hijri_date', 
            'case_year_hijri',
            'case', 'case_type', 'case_subtype', 'case_status', 'governorate',
            'court_fk', 'court', 'subject', 'description', 
            'facts', 'legal_basis', 'legal_reasons', 'reasons', 'requests', 
            'status', 'notes', 'archive_status', 'parent_lawsuit'
        )


class CaseFileItemSerializer(serializers.ModelSerializer):
    """
    Serializer for CaseFileItem - عناصر ملف القضية
    """
    item_type_display = serializers.CharField(source='get_item_type_display', read_only=True)
    file_size_display = serializers.CharField(source='get_file_size_display', read_only=True)
    file_url = serializers.SerializerMethodField()
    created_by_name = serializers.SerializerMethodField()
    
    class Meta:
        model = CaseFileItem
        fields = (
            'id', 'lawsuit', 'item_type', 'item_type_display',
            'title', 'description', 'file', 'file_url',
            'original_filename', 'file_size', 'file_size_display',
            'related_object_id', 'related_object_type',
            'sort_order', 'created_by', 'created_by_name',
            'created_at', 'updated_at',
        )
        read_only_fields = ('id', 'created_at', 'updated_at', 'file_size')
        extra_kwargs = {
            'file': {'required': False, 'allow_null': True},
            'description': {'required': False, 'allow_blank': True},
            'original_filename': {'required': False, 'allow_blank': True},
            'related_object_id': {'required': False},
            'related_object_type': {'required': False, 'allow_blank': True},
            'sort_order': {'required': False},
        }
    
    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None
    
    def get_created_by_name(self, obj):
        if obj.created_by:
            name = f"{obj.created_by.first_name} {obj.created_by.last_name}".strip()
            return name or obj.created_by.username
        return None
