"""
Settings for auth-service.
Serves: JWT tokens, registration, profiles, sub-accounts, user sessions.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'change-me-in-production')
DEBUG = os.environ.get('DEBUG', '0') == '1'
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'corsheaders',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'django_filters',
    # Service apps
    'accounts',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
]

ROOT_URLCONF = 'auth_service.urls'
WSGI_APPLICATION = 'auth_service.wsgi.application'

import dj_database_url
DATABASES = {
    'default': dj_database_url.config(
        default=os.environ.get('DATABASE_URL', 'sqlite:///db.sqlite3'),
        conn_max_age=600,
        conn_health_checks=True,
    )
}

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

from smartjudi_common.jwt_settings import get_rest_framework_config, get_simple_jwt_config
REST_FRAMEWORK = get_rest_framework_config()
SIMPLE_JWT = get_simple_jwt_config(SECRET_KEY)
SIMPLE_JWT['TOKEN_OBTAIN_SERIALIZER'] = 'accounts.serializers.CustomTokenObtainPairSerializer'

CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOW_CREDENTIALS = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

LANGUAGE_CODE = 'ar'
TIME_ZONE = 'Asia/Aden'
USE_TZ = True

# ─── Email Configuration ────────────────────────────────────────
# Production: set EMAIL_HOST, EMAIL_PORT, EMAIL_HOST_USER, EMAIL_HOST_PASSWORD in .env
# Development: uses console backend (prints emails to terminal)
EMAIL_BACKEND = os.environ.get(
    'EMAIL_BACKEND',
    'django.core.mail.backends.smtp.EmailBackend' if not DEBUG else 'django.core.mail.backends.console.EmailBackend'
)
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True') == 'True'
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'noreply@smartjudi.com')

# ─── SMS Configuration (sms.arsi.fun) ─────────────────────────────────
SMS_API_URL = os.environ.get('SMS_API_URL', 'https://sms.arsi.fun/api')
SMS_API_KEY = os.environ.get('SMS_API_KEY', '609aef4d393812a330427ed473bc14b0')
SMS_DEVICE_ID = int(os.environ.get('SMS_DEVICE_ID', '5'))
SMS_SIM = int(os.environ.get('SMS_SIM', '6'))

