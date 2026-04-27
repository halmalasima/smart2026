from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from smartjudi_common.health import health_check
from notifications_app.views import notifications_list, notifications_mark_all_read, notifications_detail
from messaging.views import MessageViewSet

router = DefaultRouter()
router.register(r'messaging/messages', MessageViewSet, basename='message')

urlpatterns = [
    path('admin/notifications/', admin.site.urls),
    path('health/', health_check),
    path('api/notifications/', notifications_list, name='notifications_list'),
    path('api/notifications/mark-all-read/', notifications_mark_all_read, name='notifications_mark_all_read'),
    path('api/notifications/<int:pk>/', notifications_detail, name='notifications_detail'),
    path('api/', include(router.urls)),
]
