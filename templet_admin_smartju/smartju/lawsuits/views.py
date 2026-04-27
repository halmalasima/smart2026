import logging

from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

logger = logging.getLogger(__name__)
from django_filters.rest_framework import DjangoFilterBackend
from django_filters import rest_framework as django_filters
from django.db.models import Q, Count
from django.utils import timezone
from django.contrib.auth.models import User
from .models import Case, CaseParty, Lawsuit, LegalTemplate, FinancialClaim
from .models_casefile import CaseFileItem
from .serializers import (
    CaseSerializer, CasePartySerializer,
    LawsuitSerializer, LawsuitCreateSerializer, LawsuitUpdateSerializer,
    LegalTemplateSerializer, FinancialClaimSerializer, CaseFileItemSerializer
)
from accounts.permissions import IsJudgeOrLawyerOrAdmin



class LawsuitFilter(django_filters.FilterSet):
    """
    Advanced filter for Lawsuit - فلترة متقدمة للدعاوى
    """
    # Date range filters
    filing_date_from = django_filters.DateFilter(
        field_name='filing_date', lookup_expr='gte',
        label='تاريخ الرفع من'
    )
    filing_date_to = django_filters.DateFilter(
        field_name='filing_date', lookup_expr='lte',
        label='تاريخ الرفع إلى'
    )
    created_from = django_filters.DateFilter(
        field_name='created_at', lookup_expr='gte',
        label='تاريخ الإنشاء من'
    )
    created_to = django_filters.DateFilter(
        field_name='created_at', lookup_expr='lte',
        label='تاريخ الإنشاء إلى'
    )
    
    # Text search in parties (via related models)
    party_name = django_filters.CharFilter(
        method='filter_by_party_name',
        label='اسم طرف التقاضي'
    )
    
    # Archive status
    archive_status = django_filters.ChoiceFilter(
        choices=Lawsuit.ARCHIVE_STATUS_CHOICES,
        label='حالة الأرشفة'
    )
    
    # Exclude soft-deleted by default
    include_deleted = django_filters.BooleanFilter(
        method='filter_include_deleted',
        label='تضمين المحذوفة'
    )
    
    class Meta:
        model = Lawsuit
        fields = [
            'case_type', 'case_status', 'status', 'court', 
            'governorate', 'archive_status', 'court_fk',
        ]
    
    def filter_by_party_name(self, queryset, name, value):
        """Search in plaintiff and defendant names"""
        return queryset.filter(
            Q(plaintiffs__name__icontains=value) |
            Q(defendants__name__icontains=value)
        ).distinct()
    
    def filter_include_deleted(self, queryset, name, value):
        """Include soft-deleted items"""
        if value:
            return queryset
        return queryset.filter(is_deleted=False)


class LegalTemplateViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for LegalTemplate (read-only)
    """
    queryset = LegalTemplate.objects.all()
    serializer_class = LegalTemplateSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['case_type', 'section_key', 'is_required']
    search_fields = ['section_title', 'default_text']
    
    @action(detail=False, methods=['get'])
    def by_case_type(self, request):
        """
        Get all templates for a specific case type
        GET /api/legal-templates/by_case_type/?case_type=دعوى
        """
        case_type = request.query_params.get('case_type')
        if not case_type:
            return Response(
                {'error': 'case_type parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        templates = self.queryset.filter(case_type=case_type)
        serializer = self.get_serializer(templates, many=True)
        
        # Group by section_key for easier access
        grouped = {}
        for template in serializer.data:
            key = template['section_key']
            if key not in grouped:
                grouped[key] = {
                    'section_key': key,
                    'section_title': template['section_title'],
                    'default_text': template['default_text'],
                    'is_required': template['is_required'],
                }
        
        return Response({
            'case_type': case_type,
            'templates': list(grouped.values())
        })


class CaseViewSet(viewsets.ModelViewSet):
    """ViewSet for Case (قضية)"""

    queryset = Case.objects.select_related('court_fk', 'created_by', 'client').prefetch_related('parties').all()
    serializer_class = CaseSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['case_status', 'case_type', 'case_subtype', 'governorate', 'court_fk', 'created_by', 'client']
    search_fields = ['case_number', 'subject', 'description']
    ordering_fields = ['created_at', 'updated_at', 'case_number']
    ordering = ['-created_at']

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class CasePartyViewSet(viewsets.ModelViewSet):
    """ViewSet for CaseParty – أطراف القضية"""

    queryset = CaseParty.objects.select_related('case', 'user_account').all()
    serializer_class = CasePartySerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['case', 'role', 'entity_type']
    search_fields = ['name', 'phone', 'id_number']
    ordering = ['role', 'name']

    def create(self, request, *args, **kwargs):
        import secrets
        import string
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        party = serializer.save()

        generated_password = None

        # Auto-create user account for client (الموكل) if phone is provided
        if party.role == CaseParty.ROLE_CLIENT and party.phone:
            if not party.user_account:
                username = party.phone.strip()
                password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(8))
                user, created = User.objects.get_or_create(
                    username=username,
                    defaults={'first_name': party.name or '', 'is_active': True}
                )
                if created:
                    user.set_password(password)
                    user.save()
                    if hasattr(user, 'profile'):
                        user.profile.role = 'citizen'
                        user.profile.phone_number = username
                        user.profile.supervisor = request.user
                        user.profile.save()
                    generated_password = password
                party.user_account = user
                party.save()

        response_data = self.get_serializer(party).data
        if generated_password:
            response_data['account_created'] = True
            response_data['account_username'] = party.phone.strip()
            # Password is NOT returned in API response for security.
            # It should be sent via SMS or secure channel instead.
            logger.info(f"Auto-created account for party '{party.name}' (username: {party.phone.strip()}). Password must be communicated securely.")
        return Response(response_data, status=status.HTTP_201_CREATED)


class FinancialClaimViewSet(viewsets.ModelViewSet):
    """
    ViewSet for FinancialClaim
    """
    queryset = FinancialClaim.objects.select_related('lawsuit').all()
    serializer_class = FinancialClaimSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['lawsuit', 'currency']
    search_fields = ['description']
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]


class LawsuitViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Lawsuit - with advanced archive features
    """
    queryset = Lawsuit.objects.select_related(
        'created_by', 'court_fk', 'archived_by', 'parent_lawsuit'
    ).prefetch_related('financial_claims').all()
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = LawsuitFilter
    search_fields = [
        'case_number', 'subject', 'court', 'governorate',
        'description', 'facts', 'legal_basis', 'notes',
    ]
    ordering_fields = [
        'created_at', 'filing_date', 'case_number',
        'updated_at', 'archive_date', 'case_status',
    ]
    ordering = ['-created_at']
    
    def get_serializer_class(self):
        if self.action == 'create':
            return LawsuitCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return LawsuitUpdateSerializer
        return LawsuitSerializer
    
    def get_permissions(self):
        if self.action in ['update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)
    
    def perform_update(self, serializer):
        instance = serializer.instance
        user = self.request.user
        if hasattr(user, 'profile'):
            user_role = user.profile.role
            if user_role == 'citizen' and instance.created_by != user:
                from rest_framework.exceptions import PermissionDenied
                raise PermissionDenied("You can only update your own lawsuits")
        serializer.save()
    
    def perform_destroy(self, instance):
        """Soft delete instead of hard delete"""
        user = self.request.user
        if hasattr(user, 'profile'):
            user_role = user.profile.role
            if user_role == 'citizen' and instance.created_by != user:
                from rest_framework.exceptions import PermissionDenied
                raise PermissionDenied("You can only delete your own lawsuits")
        # Soft delete
        instance.is_deleted = True
        instance.deleted_at = timezone.now()
        instance.save(update_fields=['is_deleted', 'deleted_at'])
    
    def get_queryset(self):
        queryset = super().get_queryset()
        # Filter out soft-deleted by default
        if not self.request.query_params.get('include_deleted'):
            queryset = queryset.filter(is_deleted=False)
        
        # Filter out child lawsuits by default (only show parent lawsuits in main list)
        # Child lawsuits should only appear inside their parent lawsuit details
        if not self.request.query_params.get('include_child_lawsuits'):
            queryset = queryset.filter(parent_lawsuit__isnull=True)
        
        # Filter out appeal, challenge, and payment order case types from main archive list
        # These should only appear inside their parent lawsuit details
        if not self.request.query_params.get('include_appeals'):
            queryset = queryset.exclude(case_type__in=['طعن', 'استئناف', 'امر_اداء'])
        
        user = self.request.user
        if user.is_superuser:
            return queryset
            
        if hasattr(user, 'profile'):
            user_role = user.profile.role
            if user_role == 'admin':
                return queryset
            if user_role == 'citizen':
                queryset = queryset.filter(Q(created_by=user) | Q(client=user))
            elif user_role == 'assistant' and user.profile.supervisor:
                supervisor = user.profile.supervisor
                queryset = queryset.filter(Q(created_by=supervisor) | Q(client=supervisor) | Q(created_by=user))
            elif user_role == 'lawyer' or user_role == 'notary':
                queryset = queryset.filter(Q(created_by=user) | Q(client=user))
            else:
                queryset = queryset.filter(created_by=user)
        else:
            # Fallback if no profile: only see what they created
            queryset = queryset.filter(created_by=user)
            
        return queryset
    
    # ========== Archive Actions ==========
    
    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """
        Archive a lawsuit - أرشفة دعوى
        POST /api/lawsuits/{id}/archive/
        """
        lawsuit = self.get_object()
        reason = request.data.get('reason', '')
        
        lawsuit.archive_status = Lawsuit.ARCHIVE_ARCHIVED
        lawsuit.archive_date = timezone.now()
        lawsuit.archive_reason = reason
        lawsuit.archived_by = request.user
        lawsuit.save(update_fields=[
            'archive_status', 'archive_date', 'archive_reason', 'archived_by'
        ])
        
        serializer = self.get_serializer(lawsuit)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def unarchive(self, request, pk=None):
        """
        Restore a lawsuit from archive - استعادة دعوى من الأرشيف
        POST /api/lawsuits/{id}/unarchive/
        """
        lawsuit = self.get_object()
        lawsuit.archive_status = Lawsuit.ARCHIVE_ACTIVE
        lawsuit.archive_date = None
        lawsuit.archive_reason = None
        lawsuit.archived_by = None
        lawsuit.save(update_fields=[
            'archive_status', 'archive_date', 'archive_reason', 'archived_by'
        ])
        
        serializer = self.get_serializer(lawsuit)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def restore(self, request, pk=None):
        """
        Restore a soft-deleted lawsuit - استعادة دعوى محذوفة
        POST /api/lawsuits/{id}/restore/
        """
        try:
            lawsuit = Lawsuit.objects.get(pk=pk, is_deleted=True)
        except Lawsuit.DoesNotExist:
            return Response(
                {'error': 'الدعوى غير موجودة أو غير محذوفة'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        lawsuit.is_deleted = False
        lawsuit.deleted_at = None
        lawsuit.save(update_fields=['is_deleted', 'deleted_at'])
        
        serializer = self.get_serializer(lawsuit)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """
        Get archive statistics - إحصائيات الأرشيف
        GET /api/lawsuits/stats/
        """
        qs = self.get_queryset()
        
        # Count by archive status
        archive_counts = {}
        for choice_value, choice_label in Lawsuit.ARCHIVE_STATUS_CHOICES:
            archive_counts[choice_value] = qs.filter(archive_status=choice_value).count()
        
        # Count by case status
        status_counts = {}
        for choice_value, choice_label in Lawsuit.STATUS_CHOICES:
            status_counts[choice_value] = qs.filter(case_status=choice_value).count()
        
        # Count by case type
        type_counts = {}
        for choice_value, choice_label in Lawsuit.CASE_TYPE_CHOICES:
            count = qs.filter(case_type=choice_value).count()
            if count > 0:
                type_counts[choice_value] = {
                    'count': count,
                    'label': choice_label,
                }
        
        return Response({
            'total': qs.count(),
            'deleted': Lawsuit.objects.filter(is_deleted=True).count() if hasattr(request.user, 'profile') and request.user.profile.role in ['admin', 'judge'] else 0,
            'by_archive_status': archive_counts,
            'by_case_status': status_counts,
            'by_case_type': type_counts,
        })
    
    @action(detail=False, methods=['get'])
    def get_templates(self, request):
        """
        Get legal templates for a case type
        GET /api/lawsuits/get_templates/?case_type=دعوى
        """
        case_type = request.query_params.get('case_type')
        if not case_type:
            return Response(
                {'error': 'case_type parameter is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        templates = LegalTemplate.objects.filter(case_type=case_type)
        serializer = LegalTemplateSerializer(templates, many=True)
        
        grouped = {}
        for template in serializer.data:
            key = template['section_key']
            if key not in grouped:
                grouped[key] = {
                    'section_key': key,
                    'section_title': template['section_title'],
                    'default_text': template['default_text'],
                    'is_required': template['is_required'],
                }
        
        return Response({
            'case_type': case_type,
            'templates': list(grouped.values())
        })

    @action(detail=True, methods=['get'])
    def child_lawsuits(self, request, pk=None):
        """
        Get child lawsuits for a parent lawsuit
        GET /api/lawsuits/{id}/child_lawsuits/
        """
        parent_lawsuit = self.get_object()
        child_lawsuits = Lawsuit.objects.filter(parent_lawsuit=parent_lawsuit, is_deleted=False)
        serializer = self.get_serializer(child_lawsuits, many=True)
        return Response({
            'parent_id': parent_lawsuit.id,
            'parent_case_number': parent_lawsuit.case_number,
            'child_lawsuits': serializer.data,
            'count': child_lawsuits.count()
        })


class CaseFileItemViewSet(viewsets.ModelViewSet):
    """
    ViewSet for CaseFileItem - ملف القضية الموحد
    يربط جميع المستندات والعناصر المتعلقة بالقضية
    """
    serializer_class = CaseFileItemSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['lawsuit', 'item_type', 'related_object_type']
    search_fields = ['title', 'description', 'original_filename']
    ordering_fields = ['created_at', 'sort_order', 'item_type']
    ordering = ['sort_order', '-created_at']
    
    def get_queryset(self):
        user = self.request.user
        qs = CaseFileItem.objects.select_related('lawsuit', 'created_by').all()
        
        if user.is_superuser:
            return qs
        
        if hasattr(user, 'profile'):
            role = user.profile.role
            if role == 'admin':
                return qs
            elif role == 'citizen':
                return qs.filter(Q(lawsuit__created_by=user) | Q(lawsuit__client=user))
            elif role == 'assistant' and user.profile.supervisor:
                sup = user.profile.supervisor
                return qs.filter(
                    Q(lawsuit__created_by=sup) | Q(lawsuit__client=sup) | Q(lawsuit__created_by=user)
                )
            else:
                return qs.filter(Q(lawsuit__created_by=user) | Q(lawsuit__client=user))
        
        return qs.filter(lawsuit__created_by=user)
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    @action(detail=False, methods=['get'])
    def by_lawsuit(self, request):
        """
        احضار كل عناصر ملف القضية مع إحصائيات
        GET /api/case-file-items/by_lawsuit/?lawsuit=123
        """
        lawsuit_id = request.query_params.get('lawsuit')
        if not lawsuit_id:
            return Response({'error': 'lawsuit parameter is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        items = self.get_queryset().filter(lawsuit_id=lawsuit_id)
        serializer = self.get_serializer(items, many=True)
        
        # Stats by type
        type_counts = {}
        for item in items:
            t = item.item_type
            type_counts[t] = type_counts.get(t, 0) + 1
        
        return Response({
            'lawsuit_id': int(lawsuit_id),
            'total_items': items.count(),
            'by_type': type_counts,
            'items': serializer.data,
        })
    
    @action(detail=False, methods=['post'])
    def sync_from_attachments(self, request):
        """
        مزامنة عناصر ملف القضية من المرفقات الموجودة
        POST /api/case-file-items/sync_from_attachments/
        Body: {"lawsuit": 123}
        """
        lawsuit_id = request.data.get('lawsuit')
        if not lawsuit_id:
            return Response({'error': 'lawsuit is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            lawsuit = Lawsuit.objects.get(pk=lawsuit_id)
        except Lawsuit.DoesNotExist:
            return Response({'error': 'الدعوى غير موجودة'}, status=status.HTTP_404_NOT_FOUND)
        
        # Sync from attachments
        from attachments.models import Attachment
        attachments = Attachment.objects.filter(lawsuit=lawsuit)
        created_count = 0
        for att in attachments:
            existing = CaseFileItem.objects.filter(
                lawsuit=lawsuit,
                related_object_id=att.id,
                related_object_type='attachment'
            ).exists()
            if not existing:
                CaseFileItem.objects.create(
                    lawsuit=lawsuit,
                    item_type=self._map_doc_type(att.document_type),
                    title=att.content or att.original_filename or f'مرفق #{att.id}',
                    description=att.evidence_basis or '',
                    original_filename=att.original_filename or '',
                    file_size=att.file_size,
                    related_object_id=att.id,
                    related_object_type='attachment',
                    created_by=request.user,
                )
                created_count += 1
        
        # Sync from appeals
        from appeals.models import Appeal
        appeals = Appeal.objects.filter(lawsuit=lawsuit)
        for appeal in appeals:
            existing = CaseFileItem.objects.filter(
                lawsuit=lawsuit,
                related_object_id=appeal.id,
                related_object_type='appeal'
            ).exists()
            if not existing:
                CaseFileItem.objects.create(
                    lawsuit=lawsuit,
                    item_type='appeal',
                    title=f'طعن - {appeal.appeal_number}',
                    description=appeal.appeal_reasons[:200] if appeal.appeal_reasons else '',
                    related_object_id=appeal.id,
                    related_object_type='appeal',
                    created_by=request.user,
                )
                created_count += 1
        
        # Sync from hearings
        from hearings.models import Hearing
        hearings = Hearing.objects.filter(lawsuit=lawsuit)
        for hearing in hearings:
            existing = CaseFileItem.objects.filter(
                lawsuit=lawsuit,
                related_object_id=hearing.id,
                related_object_type='hearing'
            ).exists()
            if not existing:
                CaseFileItem.objects.create(
                    lawsuit=lawsuit,
                    item_type='hearing_record',
                    title=f'جلسة - {hearing.hearing_date}',
                    description=hearing.notes[:200] if hearing.notes else '',
                    related_object_id=hearing.id,
                    related_object_type='hearing',
                    created_by=request.user,
                )
                created_count += 1
        
        # Sync from payment orders
        from payments.models import PaymentOrder
        payments = PaymentOrder.objects.filter(lawsuit=lawsuit)
        for payment in payments:
            existing = CaseFileItem.objects.filter(
                lawsuit=lawsuit,
                related_object_id=payment.id,
                related_object_type='payment_order'
            ).exists()
            if not existing:
                CaseFileItem.objects.create(
                    lawsuit=lawsuit,
                    item_type='payment_order',
                    title=f'أمر أداء - {payment.order_number or payment.id}',
                    description=payment.description or f'مبلغ: {payment.amount}',
                    related_object_id=payment.id,
                    related_object_type='payment_order',
                    created_by=request.user,
                )
                created_count += 1
        
        # Sync from judgments
        from judgments.models import Judgment
        judgments = Judgment.objects.filter(lawsuit=lawsuit)
        for judgment in judgments:
            existing = CaseFileItem.objects.filter(
                lawsuit=lawsuit,
                related_object_id=judgment.id,
                related_object_type='judgment'
            ).exists()
            if not existing:
                CaseFileItem.objects.create(
                    lawsuit=lawsuit,
                    item_type='judgment',
                    title=f'حكم - {getattr(judgment, "judgment_number", judgment.id)}',
                    description=getattr(judgment, 'judgment_text', '')[:200] if hasattr(judgment, 'judgment_text') else '',
                    related_object_id=judgment.id,
                    related_object_type='judgment',
                    created_by=request.user,
                )
                created_count += 1
        
        return Response({
            'message': f'تمت المزامنة بنجاح - تم إضافة {created_count} عنصر جديد',
            'created_count': created_count,
        })
    
    def _map_doc_type(self, doc_type):
        """Map attachment document_type to CaseFileItem item_type"""
        mapping = {
            'identity': 'document',
            'contract': 'contract',
            'certificate': 'document',
            'evidence': 'evidence',
            'statement': 'document',
            'receipt': 'document',
            'other': 'document',
            'document': 'document',
            'lawsuit': 'lawsuit',
            'appeal': 'appeal',
            'payment_order': 'payment_order',
        }
        return mapping.get(doc_type, 'document')
