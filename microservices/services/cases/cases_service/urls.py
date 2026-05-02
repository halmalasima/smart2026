"""URL configuration for cases-service."""
from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from smartjudi_common.health import health_check

from lawsuits.views import (
    LawsuitViewSet, CaseViewSet, CasePartyViewSet, LegalTemplateViewSet,
    FinancialClaimViewSet, CaseFileItemViewSet,
)
from parties.views import PlaintiffViewSet, DefendantViewSet
from responses.views import ResponseViewSet
from appeals.views import AppealViewSet
from judgments.views import JudgmentViewSet
from payments.views import PaymentOrderViewSet
from audit.views import AuditLogViewSet

router = DefaultRouter()
router.register(r'lawsuits', LawsuitViewSet, basename='lawsuit')
router.register(r'cases', CaseViewSet, basename='case')
router.register(r'case-parties', CasePartyViewSet, basename='case-party')
router.register(r'legal-templates', LegalTemplateViewSet, basename='legal-template')
router.register(r'financial-claims', FinancialClaimViewSet, basename='financial-claim')
router.register(r'case-file-items', CaseFileItemViewSet, basename='case-file-item')
router.register(r'plaintiffs', PlaintiffViewSet, basename='plaintiff')
router.register(r'defendants', DefendantViewSet, basename='defendant')
router.register(r'responses', ResponseViewSet, basename='response')
router.register(r'appeals', AppealViewSet, basename='appeal')
router.register(r'judgments', JudgmentViewSet, basename='judgment')
router.register(r'payment-orders', PaymentOrderViewSet, basename='payment-order')
router.register(r'audit-logs', AuditLogViewSet, basename='audit-log')

from lawsuits.views_ocr import ExtractTextView

urlpatterns = [
    path('admin/cases/', admin.site.urls),
    # Legacy API (Backward Compatibility)
    path('api/', include(router.urls)),
    # Versioned API (v1)
    path('api/v1/', include(router.urls)),
    # OCR API
    path('api/ocr/extract-text/', ExtractTextView.as_view(), name='ocr-extract-text'),
    path('api/v1/ocr/extract-text/', ExtractTextView.as_view(), name='ocr-extract-text-v1'),
    path('health/', health_check, name='health_check'),
]
