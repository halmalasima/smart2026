"""
URL configuration for smartju project.
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse
from django.views.generic import RedirectView
from django.views.decorators.http import require_http_methods
from rest_framework.routers import DefaultRouter

from notifications.views import (
    notifications_detail,
    notifications_list,
    notifications_mark_all_read,
)
from rest_framework_simplejwt.views import (
    TokenRefreshView,
)
from accounts.views import CustomTokenObtainPairView
from drf_yasg.views import get_schema_view
from drf_yasg import openapi

# Import ViewSets
from accounts.views import UserProfileViewSet
from lawsuits.views import CaseViewSet, CasePartyViewSet, LawsuitViewSet, LegalTemplateViewSet, FinancialClaimViewSet, CaseFileItemViewSet
from parties.views import PlaintiffViewSet, DefendantViewSet
from attachments.views import AttachmentViewSet
from responses.views import ResponseViewSet
from appeals.views import AppealViewSet
from hearings.views import HearingViewSet
from judgments.views import JudgmentViewSet
from audit.views import AuditLogViewSet
from courts.views import (
    GovernorateViewSet, DistrictViewSet, CourtTypeViewSet,
    CourtSpecializationViewSet, CourtViewSet
)
from payments.views import PaymentOrderViewSet
from laws.views import (
    LegalCategoryViewSet, LawViewSet, LawChapterViewSet,
    LawSectionViewSet, LawArticleViewSet, CaseLegalReferenceViewSet,
    LegalArticleFlatViewSet, LegalProcedureViewSet, LawLibraryViewSet
)
from logs.views import UserSessionViewSet, SearchLogViewSet, AIChatLogViewSet, AIConversationViewSet
from lawyers.views import LawyerViewSet, LawyerFilterOptionsViewSet
from lawsuits.views_ocr import ExtractTextView

# Create router
router = DefaultRouter()
router.register(r'profiles', UserProfileViewSet, basename='profile')
router.register(r'cases', CaseViewSet, basename='case')
router.register(r'case-parties', CasePartyViewSet, basename='case-party')
router.register(r'lawsuits', LawsuitViewSet, basename='lawsuit')
router.register(r'legal-templates', LegalTemplateViewSet, basename='legal-template')
router.register(r'financial-claims', FinancialClaimViewSet, basename='financial-claim')
router.register(r'case-file-items', CaseFileItemViewSet, basename='case-file-item')
router.register(r'plaintiffs', PlaintiffViewSet, basename='plaintiff')
router.register(r'defendants', DefendantViewSet, basename='defendant')
router.register(r'attachments', AttachmentViewSet, basename='attachment')
router.register(r'responses', ResponseViewSet, basename='response')
router.register(r'appeals', AppealViewSet, basename='appeal')
router.register(r'hearings', HearingViewSet, basename='hearing')
router.register(r'judgments', JudgmentViewSet, basename='judgment')
router.register(r'lawyers', LawyerViewSet, basename='lawyer')
router.register(r'lawyer-filter-options', LawyerFilterOptionsViewSet, basename='lawyer-filter-option')
router.register(r'audit-logs', AuditLogViewSet, basename='audit-log')
# Courts
router.register(r'governorates', GovernorateViewSet, basename='governorate')
router.register(r'districts', DistrictViewSet, basename='district')
router.register(r'court-types', CourtTypeViewSet, basename='court-type')
router.register(r'court-specializations', CourtSpecializationViewSet, basename='court-specialization')
router.register(r'courts', CourtViewSet, basename='court')
# Payments
router.register(r'payment-orders', PaymentOrderViewSet, basename='payment-order')
# Laws
router.register(r'legal-categories', LegalCategoryViewSet, basename='legal-category')
router.register(r'laws', LawViewSet, basename='law')
router.register(r'law-chapters', LawChapterViewSet, basename='law-chapter')
router.register(r'law-sections', LawSectionViewSet, basename='law-section')
router.register(r'law-articles', LawArticleViewSet, basename='law-article')
router.register(r'case-legal-references', CaseLegalReferenceViewSet, basename='case-legal-reference')
# Legal Library - Full-Text Search
router.register(r'legal-library', LegalArticleFlatViewSet, basename='legal-library')
router.register(r'legal-procedures', LegalProcedureViewSet, basename='legal-procedure')
router.register(r'law-library-books', LawLibraryViewSet, basename='law-library-books')
# Logs
router.register(r'user-sessions', UserSessionViewSet, basename='user-session')
router.register(r'search-logs', SearchLogViewSet, basename='search-log')
router.register(r'ai-chat-logs', AIChatLogViewSet, basename='ai-chat-log')
router.register(r'ai-conversations', AIConversationViewSet, basename='ai-conversation')

# Swagger schema view
schema_view = get_schema_view(
    openapi.Info(
        title="SmartJudi API",
        default_version='v1',
        description="""
        منصة قضائية - REST API
        
        هذه API توفر واجهة برمجية شاملة لإدارة النظام القضائي.
        
        ## التوثيق الكامل:
        
        ### المصادقة (Authentication):
        - استخدام JWT Token للمصادقة
        - الحصول على Token من `/api/token/`
        - استخدام Refresh Token من `/api/token/refresh/`
        
        ### الأدوار (Roles):
        - **judge**: قاضي - يمكنه إنشاء وتعديل الجلسات والأحكام
        - **lawyer**: محامي - يمكنه إنشاء وتعديل الدعاوى والأطراف
        - **notary**: كاتب عدل
        - **citizen**: مواطن - يمكنه فقط رؤية دعاويه
        - **admin**: مدير - صلاحيات كاملة
        
        ### Endpoints المتاحة:
        - `/api/profiles/` - ملفات المستخدمين
        - `/api/lawsuits/` - الدعاوى
        - `/api/plaintiffs/` - المدعون
        - `/api/defendants/` - المدعى عليهم
        - `/api/attachments/` - المرفقات
        - `/api/responses/` - الردود والمذكرات
        - `/api/appeals/` - الطعون
        - `/api/hearings/` - الجلسات
        - `/api/judgments/` - الأحكام
        - `/api/audit-logs/` - سجل الإجراءات (قراءة فقط)
        
        ### Pagination:
        جميع endpoints تدعم Pagination بحجم صفحة 20 عنصر.
        
        ### Filtering:
        جميع endpoints تدعم Filtering و Search و Ordering.
        """,
        terms_of_service="https://www.google.com/policies/terms/",
        contact=openapi.Contact(
            name="SmartJudi Support",
            email="contact@smartjudi.local"
        ),
        license=openapi.License(name="Proprietary License"),
    ),
    public=True,
    permission_classes=[],  # Allow access to schema without authentication
)

# Health check view (for Render) - Ultra simple, no dependencies
@require_http_methods(["GET", "HEAD"])
def health_check(request):
    """Health check endpoint for Render - must be fast and simple"""
    return JsonResponse({'status': 'ok'}, status=200)

# Home page view - also serves as root health check
@require_http_methods(["GET", "HEAD"])
def home_view(request):
    """Home page that provides API information"""
    return JsonResponse({
        'message': 'مرحباً بك في منصة SmartJudi القضائية',
        'welcome': 'Welcome to SmartJudi Judicial Platform',
        'version': '1.0.0',
        'endpoints': {
            'api_documentation': '/swagger/',
            'api_documentation_redoc': '/redoc/',
            'api_base': '/api/',
            'admin_panel': '/admin/',
            'authentication': {
                'obtain_token': '/api/token/',
                'refresh_token': '/api/token/refresh/',
            },
            'resources': {
                'profiles': '/api/profiles/',
                'lawsuits': '/api/lawsuits/',
                'plaintiffs': '/api/plaintiffs/',
                'defendants': '/api/defendants/',
                'attachments': '/api/attachments/',
                'responses': '/api/responses/',
                'appeals': '/api/appeals/',
                'hearings': '/api/hearings/',
                'judgments': '/api/judgments/',
                'audit_logs': '/api/audit-logs/',
                'governorates': '/api/governorates/',
                'districts': '/api/districts/',
                'court_types': '/api/court-types/',
                'court_specializations': '/api/court-specializations/',
                'courts': '/api/courts/',
                'payment_orders': '/api/payment-orders/',
                'legal_categories': '/api/legal-categories/',
                'laws': '/api/laws/',
                'law_chapters': '/api/law-chapters/',
                'law_sections': '/api/law-sections/',
                'law_articles': '/api/law-articles/',
                'case_legal_references': '/api/case-legal-references/',
                'legal_library': '/api/legal-library/',
                'legal_library_sources': '/api/legal-library/sources/',
                'legal_library_search': '/api/legal-library/search/',
                'user_sessions': '/api/user-sessions/',
                'search_logs': '/api/search-logs/',
                'ai_chat_logs': '/api/ai-chat-logs/',
                'ai_chat': '/api/ai/chat/',
                'ai_documents_add': '/api/ai/documents/add/',
                'ai_documents_delete': '/api/ai/documents/delete/',
            }
        },
        'documentation': 'Visit /swagger/ for interactive API documentation',
    }, json_dumps_params={'ensure_ascii': False, 'indent': 2})


from dashboard.views import intro_page, custom_login, custom_register

from django.urls import re_path
from django.views.static import serve
import os
import mimetypes
from django.conf import settings

# ─── Role-Based Service API Views ───
from rest_framework.decorators import api_view as drf_api_view, permission_classes as drf_permission_classes
from rest_framework.permissions import IsAuthenticated as DRFIsAuthenticated, AllowAny as DRFAllowAny
from rest_framework.response import Response as DRFResponse

@drf_api_view(['GET'])
@drf_permission_classes([DRFIsAuthenticated])
def _get_my_services(request):
    """
    Returns the services available to the current user's role.
    GET /api/services/my-services/
    """
    from control_panel.models import RoleServicePermission, ServiceDefinition
    try:
        from dashboard.subscription_utils import get_active_subscription
    except Exception:
        get_active_subscription = None
    try:
        role = request.user.profile.role
    except Exception:
        role = 'citizen'

    permissions = RoleServicePermission.objects.filter(
        role=role, is_enabled=True, service__is_active=True
    ).select_related('service').order_by('service__sort_order')

    sub = None
    if get_active_subscription is not None:
        try:
            sub = get_active_subscription(request.user)
        except Exception:
            sub = None

    services = []
    for perm in permissions:
        svc = perm.service
        if svc.is_premium and not sub:
            continue
        services.append({
            'key': svc.key,
            'name_ar': svc.name_ar,
            'name_en': svc.name_en,
            'icon': svc.icon,
            'category': svc.category,
            'is_premium': svc.is_premium,
            'max_daily_uses': perm.max_daily_uses,
            'max_monthly_uses': perm.max_monthly_uses,
        })

    return DRFResponse({
        'role': role,
        'services': services,
        'total': len(services),
    })


@drf_api_view(['POST'])
@drf_permission_classes([DRFIsAuthenticated])
def _log_service_usage(request):
    """
    Logs a service usage event.
    POST /api/services/log-usage/
    Body: { "service_key": "chat", "duration_seconds": 120 }
    """
    from control_panel.models import RoleServicePermission, ServiceDefinition, ServiceUsageLog
    from django.utils import timezone
    from datetime import date
    try:
        from dashboard.subscription_utils import get_active_subscription
    except Exception:
        get_active_subscription = None
    service_key = request.data.get('service_key', '').strip()
    duration = request.data.get('duration_seconds', 0)

    if not service_key:
        return DRFResponse({'error': 'service_key is required'}, status=400)

    service = ServiceDefinition.objects.filter(key=service_key).first()
    if not service:
        return DRFResponse({'error': 'Service not found'}, status=404)

    try:
        role = request.user.profile.role
    except Exception:
        role = 'citizen'

    perm = RoleServicePermission.objects.filter(role=role, service=service).first()
    if not perm or not perm.is_enabled:
        return DRFResponse({'error': 'Service not allowed for this role'}, status=403)

    sub = None
    if get_active_subscription is not None:
        try:
            sub = get_active_subscription(request.user)
        except Exception:
            sub = None

    if service.is_premium and not sub:
        return DRFResponse({'error': 'Subscription required'}, status=403)

    today = timezone.localdate()
    month_start = date(today.year, today.month, 1)

    if perm.max_daily_uses and perm.max_daily_uses > 0:
        used_today = ServiceUsageLog.objects.filter(
            user=request.user,
            service=service,
            accessed_at__date=today,
        ).count()
        if used_today >= perm.max_daily_uses:
            return DRFResponse({'error': 'Daily limit exceeded'}, status=429)

    if perm.max_monthly_uses and perm.max_monthly_uses > 0:
        used_month = ServiceUsageLog.objects.filter(
            user=request.user,
            service=service,
            accessed_at__date__gte=month_start,
        ).count()
        if used_month >= perm.max_monthly_uses:
            return DRFResponse({'error': 'Monthly limit exceeded'}, status=429)

    # Detect device type
    ua = request.META.get('HTTP_USER_AGENT', '').lower()
    device_type = 'Desktop'
    if 'mobi' in ua or 'android' in ua or 'iphone' in ua:
        device_type = 'Mobile'
    elif 'dart' in ua:
        device_type = 'App'

    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    ip = x_forwarded_for.split(',')[0].strip() if x_forwarded_for else request.META.get('REMOTE_ADDR')

    ServiceUsageLog.objects.create(
        user=request.user,
        service=service,
        ip_address=ip,
        device_type=device_type,
        duration_seconds=duration or 0,
    )

    return DRFResponse({'status': 'logged'})


# Fix MIME type for Windows
mimetypes.add_type("application/javascript", ".js", True)
mimetypes.add_type("application/wasm", ".wasm", True)

FLUTTER_WEB_DIR = os.path.join(settings.BASE_DIR.parent, 'build', 'web')

def serve_flutter_app(request, path):
    if path != "" and os.path.exists(os.path.join(FLUTTER_WEB_DIR, path)):
        return serve(request, path, document_root=FLUTTER_WEB_DIR)
    else:
        return serve(request, 'index.html', document_root=FLUTTER_WEB_DIR)

urlpatterns = [
    # Health check endpoint (for Discovery and Render)
    path('health/', health_check, name='health'),
    path('health', health_check),  # alias without slash
    
    # Explicit AI health check to bypass any routing issues
    path('api/ai/health/', health_check),
    path('api/ai/health', health_check),
    
    # Microservice Health Check Catch-all (for Gateway/Control Panel Monitor)
    re_path(r'^api/[a-z_]+/health/?$', health_check),
    path('portal/', health_check), # Health check for portal service
    
    # Root endpoint - Marketing/intro landing page
    path('', intro_page, name='landing'),
    path('login/', RedirectView.as_view(url='/app/', permanent=False), name='custom-login'),
    path('register/', RedirectView.as_view(url='/app/', permanent=False), name='custom-register'),
    # Serve Flutter Web App
    re_path(r'^app/(?P<path>.*)$', serve_flutter_app, name='flutter_app'),
    
    # Auto-fix browser caching redirects to accounts/login
    path('accounts/login/', RedirectView.as_view(url='/login/', permanent=False)),
    
    # Custom Web Dashboard (legacy — redirects to /cp/)
    path('dashboard/', RedirectView.as_view(url='/cp/', permanent=True)),
    
    # ─── Modern Control Panel (Tabler) ───
    path('cp/', include('control_panel.urls', namespace='control_panel')),

    # Admin
    path('admin/', admin.site.urls),

    
    # API Routes
    path('api/', include(router.urls)),
    
    # OCR API (Handles both with and without trailing slash to avoid 301 redirects)
    re_path(r'^api/ocr/extract-text/?$', ExtractTextView.as_view(), name='ocr-extract-text'),

    # إشعارات التطبيق (Flutter يتوقع JSON وليس صفحة 404 HTML)
    path('api/notifications/mark-all-read/', notifications_mark_all_read),
    path('api/notifications/<str:pk>/', notifications_detail),
    path('api/notifications/', notifications_list),
    
    # JWT Authentication
    path('api/token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # User Registration
    path('api/register/', include('accounts.urls')),
    
    # AI Assistant (المساعد الذكي)
    path('api/ai/', include('ai_assistant.urls')),
    path('api/messaging/', include('messaging.urls')),
    
    # Role-Based Service Management (SaaS Pro)
    path('api/services/my-services/', _get_my_services, name='my_services'),
    path('api/services/log-usage/', _log_service_usage, name='log_service_usage'),
    
    # Swagger/OpenAPI Documentation (unified — /redoc/ redirects here)
    path('swagger/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('redoc/', RedirectView.as_view(url='/swagger/', permanent=True)),
    path('swagger.json', schema_view.without_ui(cache_timeout=0), name='schema-json'),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
