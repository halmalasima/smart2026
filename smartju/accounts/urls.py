from django.urls import path
from .views import (
    register_user, create_sub_account, check_phone, quick_register,
    verify_otp_login, send_otp, set_password, reset_password_otp
)

urlpatterns = [
    path('', register_user, name='register'),
    path('create-sub-account/', create_sub_account, name='create_sub_account'),
    path('check-phone/', check_phone, name='check_phone'),
    path('quick-register/', quick_register, name='quick_register'),
    path('verify-otp/', verify_otp_login, name='verify_otp_login'),
    path('send-otp/', send_otp, name='send_otp'),
    path('set-password/', set_password, name='set_password'),
    path('reset-password/', reset_password_otp, name='reset_password_otp'),
]
