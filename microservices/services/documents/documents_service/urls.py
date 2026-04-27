from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.views.static import serve as static_serve
from rest_framework.routers import DefaultRouter
from smartjudi_common.health import health_check
from attachments.views import AttachmentViewSet

router = DefaultRouter()
router.register(r'attachments', AttachmentViewSet, basename='attachment')

urlpatterns = [
    path('admin/documents/', admin.site.urls),
    path('health/', health_check),
    path('api/', include(router.urls)),
    # Serve uploaded media files (works with DEBUG=False too).
    re_path(
        r'^media/(?P<path>.*)$',
        static_serve,
        {'document_root': settings.MEDIA_ROOT},
    ),
]
