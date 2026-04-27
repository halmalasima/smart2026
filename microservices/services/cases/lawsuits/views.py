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
from permissions import IsJudgeOrLawyerOrAdmin
from smartjudi_common.user_utils import get_user_role
from .services import CasePartyService, LawsuitService
from .repositories import LawsuitRepository
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page



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
            'governorate', 'archive_status', 'court_id', 'case',
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

    queryset = Case.objects.prefetch_related('parties').all()
    serializer_class = CaseSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['case_status', 'case_type', 'case_subtype', 'governorate', 'court_id', 'created_by', 'client']
    search_fields = ['case_number', 'subject', 'description']
    ordering_fields = ['created_at', 'updated_at', 'case_number']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        user_role = get_user_role(user)
        uid = user.id
        qs = Case.objects.prefetch_related('parties').all()
        if user_role == 'admin':
            return qs
        return qs.filter(Q(created_by=uid) | Q(client=uid))

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user.id)


class CasePartyViewSet(viewsets.ModelViewSet):
    """ViewSet for CaseParty – أطراف القضية"""

    queryset = CaseParty.objects.select_related('case', 'user_account').all()
    serializer_class = CasePartySerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['case', 'role', 'entity_type']
    search_fields = ['name', 'phone', 'id_number']
    ordering = ['role', 'name']

    def get_queryset(self):
        user = self.request.user
        user_role = get_user_role(user)
        uid = user.id
        qs = CaseParty.objects.select_related('case', 'user_account')
        if user_role == 'admin':
            return qs
        return qs.filter(Q(case__created_by=uid) | Q(case__client=uid))

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        # Move business logic to Service Layer
        party, generated_password, account_created = CasePartyService.create_party(
            serializer.validated_data, 
            request.user
        )

        response_data = self.get_serializer(party).data
        if account_created:
            response_data['account_created'] = True
            response_data['account_username'] = party.phone.strip()
            logger.info(f"Auto-created account for party '{party.name}' via service.")
            
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

    def get_queryset(self):
        user = self.request.user
        user_role = get_user_role(user)
        uid = user.id
        qs = FinancialClaim.objects.select_related('lawsuit')
        if user_role == 'admin':
            return qs
        return qs.filter(Q(lawsuit__created_by=uid) | Q(lawsuit__client=uid))

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]


class LawsuitViewSet(viewsets.ModelViewSet):
    """
    ViewSet for Lawsuit - with advanced archive features
    """
    queryset = Lawsuit.objects.select_related(
        'parent_lawsuit', 'archived_by'
    ).prefetch_related(
        'financial_claims', 'plaintiffs', 'defendants'
    ).all()
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
        serializer.save(created_by=self.request.user.id)
    
    def perform_update(self, serializer):
        instance = serializer.instance
        if not LawsuitService.can_modify(instance, self.request.user):
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("You can only update your own lawsuits")
        
        # Use service for update to handle cache invalidation
        LawsuitService.update_lawsuit(instance, serializer.validated_data)
    
    def perform_destroy(self, instance):
        """Soft delete instead of hard delete via service"""
        if not LawsuitService.can_modify(instance, self.request.user):
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("You can only delete your own lawsuits")
        
        LawsuitService.soft_delete(instance)

    @method_decorator(cache_page(60 * 5))  # Cache for 5 minutes
    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)

    def get_queryset(self):
        """
        Visible lawsuits via Repository
        """
        user = self.request.user
        user_role = get_user_role(user)
        
        # 1. Get lawsuits based on user role
        queryset = LawsuitRepository.get_for_user(user, user_role)
        
        # 2. Apply common filters (active only)
        if not self.request.query_params.get('include_deleted'):
            queryset = LawsuitRepository.filter_active(queryset)
            
        # 3. Apply structural filters (parents only, main archive types)
        if not self.request.query_params.get('include_child_lawsuits'):
            queryset = LawsuitRepository.filter_parents_only(queryset)
            
        if not self.request.query_params.get('include_appeals'):
            queryset = LawsuitRepository.filter_main_archive(queryset)
            
        return queryset
    
    # ========== Archive Actions ==========
    
    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """
        Archive a lawsuit - أرشفة دعوى
        Safe implementation with logging and update_fields for efficiency.
        """
        lawsuit = self.get_object()
        reason = request.data.get('reason', '')
        
        try:
            lawsuit.archive_status = Lawsuit.ARCHIVE_ARCHIVED
            lawsuit.archive_date = timezone.now()
            lawsuit.archive_reason = reason
            lawsuit.archived_by = request.user
            lawsuit.save(update_fields=[
                'archive_status', 'archive_date', 'archive_reason', 'archived_by'
            ])
            logger.info(f"Lawsuit {lawsuit.id} archived by user {request.user.id}")
        except Exception as e:
            logger.error(f"Error archiving lawsuit {lawsuit.id}: {str(e)}")
            return Response({'error': 'حدث خطأ أثناء الأرشفة'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
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
            'deleted': Lawsuit.objects.filter(is_deleted=True).count() if get_user_role(request.user) in ['admin', 'judge'] else 0,
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
        
        from smartjudi_common.user_utils import get_user_role
        role = get_user_role(user)
        uid = user.id
        if role == 'admin':
            return qs
        elif role == 'citizen':
            return qs.filter(Q(lawsuit__created_by=uid) | Q(lawsuit__client=uid))
        elif role == 'assistant':
            sup_id = None
            try:
                sup = user.profile.supervisor
                sup_id = sup.id if sup else None
            except Exception:
                pass
            if sup_id:
                return qs.filter(
                    Q(lawsuit__created_by=sup_id) | Q(lawsuit__client=sup_id) | Q(lawsuit__created_by=uid)
                )
            return qs.filter(lawsuit__created_by=uid)
        else:
            return qs.filter(Q(lawsuit__created_by=uid) | Q(lawsuit__client=uid))
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsJudgeOrLawyerOrAdmin()]
        return [IsAuthenticated()]
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user.id)
    
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
        
        user_id = request.user.id
        
        # NOTE: attachments are in documents-service — synced via Redis events (attachment.created)
        # NOTE: hearings are in hearings-service — synced via Redis events (hearing.scheduled)
        created_count = 0

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
                    created_by=user_id,
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
                    created_by=user_id,
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
                    created_by=user_id,
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
