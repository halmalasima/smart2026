"""URL configuration for legal-service."""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from smartjudi_common.health import health_check

from courts.views import (
    GovernorateViewSet, DistrictViewSet,
    CourtTypeViewSet, CourtSpecializationViewSet, CourtViewSet,
)
from laws.views import (
    LegalCategoryViewSet, LawViewSet, LawChapterViewSet, LawSectionViewSet,
    LawArticleViewSet, CaseLegalReferenceViewSet, LegalArticleFlatViewSet,
    LegalProcedureViewSet,
)
from lawyers.views import LawyerViewSet, LawyerFilterOptionsViewSet

router = DefaultRouter()

# Courts
router.register(r'governorates', GovernorateViewSet)
router.register(r'districts', DistrictViewSet)
router.register(r'court-types', CourtTypeViewSet)
router.register(r'court-specializations', CourtSpecializationViewSet)
router.register(r'courts', CourtViewSet)

# Laws
router.register(r'legal-categories', LegalCategoryViewSet)
router.register(r'laws', LawViewSet)
router.register(r'law-chapters', LawChapterViewSet)
router.register(r'law-sections', LawSectionViewSet)
router.register(r'law-articles', LawArticleViewSet)
router.register(r'case-legal-references', CaseLegalReferenceViewSet)
router.register(r'legal-library', LegalArticleFlatViewSet, basename='legal-library')
router.register(r'legal-procedures', LegalProcedureViewSet)

# Lawyers
router.register(r'lawyers', LawyerViewSet)
router.register(r'lawyer-filter-options', LawyerFilterOptionsViewSet, basename='lawyer-filter-options')

urlpatterns = [
    path('health/', health_check),
    path('api/', include(router.urls)),
]
