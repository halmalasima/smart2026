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
    TokenObtainPairView,
    TokenRefreshView,
)
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
    LegalArticleFlatViewSet, LegalProcedureViewSet
)
from logs.views import UserSessionViewSet, SearchLogViewSet, AIChatLogViewSet
from lawyers.views import LawyerViewSet, LawyerFilterOptionsViewSet

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
# Logs
router.register(r'user-sessions', UserSessionViewSet, basename='user-session')
router.register(r'search-logs', SearchLogViewSet, basename='search-log')
router.register(r'ai-chat-logs', AIChatLogViewSet, basename='ai-chat-log')

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
    # Health check endpoints (for Discovery and Render)
    path('health', health_check, name='health_no_slash'),
    path('health/', health_check, name='health_slash'),
    path('api/health/', health_check, name='api_health'),
    
    # Root endpoint - Now points to the full website landing page
    path('', intro_page, name='landing'),
    path('login/', custom_login, name='custom-login'),
    path('register/', custom_register, name='custom-register'),
    # Serve Flutter Web App
    re_path(r'^app/(?P<path>.*)$', serve_flutter_app, name='flutter_app'),
    
    # Auto-fix browser caching redirects to accounts/login
    path('accounts/login/', RedirectView.as_view(url='/login/', permanent=False)),
    
    # Custom Web Dashboard
    path('dashboard/', include('dashboard.urls')),
    
    # ─── Modern Control Panel (Tabler) ───
    path('cp/', include('control_panel.urls', namespace='control_panel')),

    # Admin
    path('admin/', admin.site.urls),

    
    # API Routes
    path('api/', include(router.urls)),

    # إشعارات التطبيق (Flutter يتوقع JSON وليس صفحة 404 HTML)
    path('api/notifications/mark-all-read/', notifications_mark_all_read),
    path('api/notifications/<str:pk>/', notifications_detail),
    path('api/notifications/', notifications_list),
    
    # JWT Authentication
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # User Registration
    path('api/register/', include('accounts.urls')),
    
    # AI Assistant (المساعد الذكي)
    path('api/ai/', include('ai_assistant.urls')),
    path('api/messaging/', include('messaging.urls')),
    
    # Swagger/OpenAPI Documentation
    path('swagger/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    path('swagger.json', schema_view.without_ui(cache_timeout=0), name='schema-json'),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
