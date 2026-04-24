from django.urls import path
from .views import (
    register_user, create_sub_account,
    verify_email, resend_otp,
    request_password_reset, verify_reset_otp, reset_password,
)

urlpatterns = [
    path('', register_user, name='register'),
    path('create-sub-account/', create_sub_account, name='create_sub_account'),
    path('verify-email/', verify_email, name='verify_email'),
    path('resend-otp/', resend_otp, name='resend_otp'),
    path('password-reset/', request_password_reset, name='request_password_reset'),
    path('password-reset/verify/', verify_reset_otp, name='verify_reset_otp'),
    path('password-reset/confirm/', reset_password, name='reset_password'),
]

