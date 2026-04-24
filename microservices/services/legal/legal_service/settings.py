"""
Settings for legal-service.
Serves: courts, laws, legal library, lawyers, legal procedures.
"""
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

_shared_path = (BASE_DIR.parent.parent / 'shared')
if _shared_path.exists():
    sys.path.insert(0, str(_shared_path))

_monolith_path = os.environ.get('MONOLITH_PATH')
if _monolith_path:
    sys.path.insert(0, _monolith_path)

SECRET_KEY = os.environ.get(
    'JWT_SECRET_KEY',
    os.environ.get('SECRET_KEY', 'django-insecure-4cyci@v!&=khm4+b)(^n@&k0((=5o5=o^r8w&)#4h=wdl)cjx='),
)
DEBUG = os.environ.get('DEBUG', '0') == '1'
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'corsheaders',
    'rest_framework',
    'rest_framework_simplejwt',
    'django_filters',
    # Service apps
    'courts',
    'laws',
    'lawyers',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
]

ROOT_URLCONF = 'legal_service.urls'
WSGI_APPLICATION = 'legal_service.wsgi.application'

# Database
import dj_database_url

_default_db_url = os.environ.get('DATABASE_URL')
if not _default_db_url and _monolith_path:
    try:
        _candidate = Path(_monolith_path) / 'db.sqlite3'
        if _candidate.exists():
            _default_db_url = f"sqlite:///{_candidate.as_posix()}"
    except Exception:
        pass

DATABASES = {
    'default': dj_database_url.config(
        default=_default_db_url or 'sqlite:///db.sqlite3',
        conn_max_age=600,
        conn_health_checks=True,
    )
}

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# DRF
from smartjudi_common.jwt_settings import get_rest_framework_config, get_simple_jwt_config
REST_FRAMEWORK = get_rest_framework_config()
SIMPLE_JWT = get_simple_jwt_config(SECRET_KEY)

# CORS
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOW_CREDENTIALS = True

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Auth user model — legal-service needs auth_user table to validate JWT
# but does NOT manage user creation; auth-service owns that.
AUTH_USER_MODEL = 'auth.User'

LANGUAGE_CODE = 'ar'
TIME_ZONE = 'Asia/Aden'
USE_TZ = True
