from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from smartjudi_common.health import health_check
from hearings.views import HearingViewSet

router = DefaultRouter()
router.register(r'hearings', HearingViewSet, basename='hearing')

urlpatterns = [
    path('admin/hearings/', admin.site.urls),
    path('health/', health_check),
    path('api/', include(router.urls)),
]
