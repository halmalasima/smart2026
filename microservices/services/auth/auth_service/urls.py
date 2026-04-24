"""URL configuration for auth-service."""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from smartjudi_common.health import health_check

from accounts.views import (
    UserProfileViewSet, register_user, create_sub_account,
    verify_email, resend_otp,
    request_password_reset, verify_reset_otp, reset_password,
)
from .internal_views import InternalUserDetailView, InternalUserBulkView, InternalUserValidateView

router = DefaultRouter()
router.register(r'profiles', UserProfileViewSet)

urlpatterns = [
    path('health/', health_check),

    # Public API
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/register/', register_user, name='register'),
    path('api/verify-email/', verify_email, name='verify_email'),
    path('api/resend-otp/', resend_otp, name='resend_otp'),
    path('api/password-reset/', request_password_reset, name='request_password_reset'),
    path('api/password-reset/verify/', verify_reset_otp, name='verify_reset_otp'),
    path('api/password-reset/confirm/', reset_password, name='reset_password'),
    path('api/create-sub-account/', create_sub_account, name='create_sub_account'),
    path('api/', include(router.urls)),

    # Internal API (service-to-service only)
    path('internal/users/<int:user_id>/', InternalUserDetailView.as_view(), name='internal_user_detail'),
    path('internal/users/bulk/', InternalUserBulkView.as_view(), name='internal_user_bulk'),
    path('internal/users/<int:user_id>/validate/', InternalUserValidateView.as_view(), name='internal_user_validate'),
]
