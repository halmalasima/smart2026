"""
Django settings for smartju project - Base/Development Settings
"""

from pathlib import Path
from datetime import timedelta
import os
import sys

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent.parent

SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-4cyci@v!&=khm4+b)(^n@&k0((=5o5=o^r8w&)#4h=wdl)cjx=')


def _read_key_env_or_file(env_name: str, file_env_name: str) -> str:
    value = os.environ.get(env_name, '')
    if value:
        return value

    file_path = os.environ.get(file_env_name, '')
    if not file_path:
        return ''

    p = Path(file_path)
    if not p.is_absolute():
        p = BASE_DIR / p

    try:
        return p.read_text(encoding='utf-8')
    except FileNotFoundError:
        return ''
DEBUG = True
ALLOWED_HOSTS = ['127.0.0.1', 'localhost', '192.168.43.198', '192.168.0.157', '10.0.2.2', '*']

# Application definition
INSTALLED_APPS = [
    'jazzmin',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'drf_yasg',
    'django_filters',
    'accounts',
    'courts',
    'lawsuits',
    'parties',
    'attachments',
    'responses',
    'appeals',
    'hearings',
    'judgments',
    'payments',
    'laws',
    'logs',
    'audit',
    'ai_assistant',
    'dashboard',
    'messaging',
    'lawyers',
    'notifications',
    'control_panel',
]

# ─── Control Panel Settings ───
CP_BRAND = 'SmartJudi Console'
CP_VERSION = '2.0.0'
CP_GATEWAY_URL = 'http://localhost:8000'

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

X_FRAME_OPTIONS = 'SAMEORIGIN'


ROOT_URLCONF = 'smartju.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'control_panel.context_processors.cp_globals',
            ],
        },
    },
]

WSGI_APPLICATION = 'smartju.wsgi.application'

# Database — local development without cloud hosting
# Default: SQLite file next to manage.py (no PostgreSQL required).
# Optional PostgreSQL: set DATABASE_URL, or USE_LOCAL_POSTGRES=1 with DB_* env vars.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    },
    'auth_db': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smartjudi_auth',
        'USER': 'smartjudi',
        'PASSWORD': 'smartjudi_secret',
        'HOST': 'localhost',
        'PORT': '5439',
    },
    'cases_db': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smartjudi_cases',
        'USER': 'smartjudi',
        'PASSWORD': 'smartjudi_secret',
        'HOST': 'localhost',
        'PORT': '5433',
    },
    'hearings_db': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smartjudi_hearings',
        'USER': 'smartjudi',
        'PASSWORD': 'smartjudi_secret',
        'HOST': 'localhost',
        'PORT': '5434',
    },
    'legal_db': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smartjudi_legal',
        'USER': 'smartjudi',
        'PASSWORD': 'smartjudi_secret',
        'HOST': 'localhost',
        'PORT': '5435',
    },
    'documents_db': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smartjudi_documents',
        'USER': 'smartjudi',
        'PASSWORD': 'smartjudi_secret',
        'HOST': 'localhost',
        'PORT': '5436',
    },
    'notifications_db': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smartjudi_notifications',
        'USER': 'smartjudi',
        'PASSWORD': 'smartjudi_secret',
        'HOST': 'localhost',
        'PORT': '5437',
    },
    'search_db': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'smartjudi_search',
        'USER': 'smartjudi',
        'PASSWORD': 'smartjudi_secret',
        'HOST': 'localhost',
        'PORT': '5438',
    },
}

DATABASE_ROUTERS = ['smartju.router.MicroserviceRouter']

# Internationalization
LANGUAGE_CODE = 'ar'
TIME_ZONE = 'Asia/Aden'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [
    BASE_DIR / 'static',
]
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': ('rest_framework_simplejwt.authentication.JWTAuthentication',),
    'DEFAULT_PERMISSION_CLASSES': ['rest_framework.permissions.IsAuthenticated',],
    'DEFAULT_RENDERER_CLASSES': (
        'rest_framework.renderers.JSONRenderer',
    ),
    'DEFAULT_PAGINATION_CLASS': 'smartju.pagination.StandardResultsSetPagination',
    'PAGE_SIZE': 20,
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=2),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'ALGORITHM': 'RS256' if (
        _read_key_env_or_file('JWT_PRIVATE_KEY', 'JWT_PRIVATE_KEY_FILE')
        and _read_key_env_or_file('JWT_PUBLIC_KEY', 'JWT_PUBLIC_KEY_FILE')
    ) else 'HS256',
    'SIGNING_KEY': _read_key_env_or_file('JWT_PRIVATE_KEY', 'JWT_PRIVATE_KEY_FILE') or SECRET_KEY,
    'VERIFYING_KEY': _read_key_env_or_file('JWT_PUBLIC_KEY', 'JWT_PUBLIC_KEY_FILE') or '',
    'AUTH_HEADER_TYPES': ('Bearer',),
}

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOW_CREDENTIALS = True

LOGIN_URL = '/login/'
LOGIN_REDIRECT_URL = '/app/'


# --- JAZZMIN ADMIN PANEL SETTINGS ---
JAZZMIN_SETTINGS = {
    "site_title": "SmartJudi Admin",
    "site_header": "SmartJudi",
    "site_brand": "SmartJudi 2025",
    "site_logo": None,
    "welcome_sign": "مرحباً بك في لوحة تحكم SmartJudi",
    "copyright": "SmartJudi",
    "user_avatar": None,
    "topmenu_links": [
        {"name": "Home",  "url": "admin:index", "permissions": ["auth.view_user"]},
        {"model": "auth.User"},
    ],
    "show_sidebar": True,
    "navigation_expanded": True,
    "hide_apps": [],
    "hide_models": [],
    "icons": {
        "auth": "fas fa-users-cog",
        "auth.user": "fas fa-user",
        "auth.Group": "fas fa-users",
        "accounts.user": "fas fa-user-tie",
        "lawsuits.lawsuit": "fas fa-gavel",
        "courts.court": "fas fa-building",
        "parties.party": "fas fa-handshake",
        "attachments.attachment": "fas fa-paperclip",
        "hearings.hearing": "fas fa-calendar-alt",
        "judgments.judgment": "fas fa-balance-scale",
        "logs.log": "fas fa-history",
    },
    "default_icon_parents": "fas fa-chevron-circle-right",
    "default_icon_children": "fas fa-circle",
    "related_modal_active": False,
    "custom_css": None,
    "custom_js": None,
    "show_ui_builder": False,
}

JAZZMIN_UI_TWEAKS = {
    "navbar_small_text": False,
    "footer_small_text": False,
    "body_small_text": False,
    "brand_small_text": False,
    "brand_colour": "navbar-success",
    "accent": "accent-success",
    "navbar": "navbar-dark",
    "no_navbar_border": False,
    "navbar_fixed": True,
    "layout_boxed": False,
    "footer_fixed": False,
    "sidebar_fixed": True,
    "sidebar": "sidebar-dark-success",
    "sidebar_nav_small_text": False,
    "sidebar_disable_expand": False,
    "sidebar_nav_child_indent": True,
    "sidebar_nav_compact_style": False,
    "sidebar_nav_legacy_style": False,
    "sidebar_nav_flat_style": False,
    "theme": "pulse",
    "dark_mode_theme": "darkly",
    "button_classes": {
        "primary": "btn-outline-primary",
        "secondary": "btn-outline-secondary",
        "info": "btn-outline-info",
        "warning": "btn-warning",
        "danger": "btn-danger",
        "success": "btn-success"
    }
}
