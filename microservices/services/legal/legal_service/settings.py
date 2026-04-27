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
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
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

# ─── Jazzmin Configuration ──────────────────────────────────────────
JAZZMIN_SETTINGS = {
    "site_title": "SmartJudi Admin Hub",
    "site_header": "SmartJudi",
    "site_brand": "المكتبة القانونية - SmartJudi",
    "site_logo": None,
    "welcome_sign": "إدارة المكتبة القانونية والقوانين",
    "copyright": "SmartJudi 2026",
    "search_model": ["laws.Law", "laws.LawArticle"],
    "topmenu_links": [
        {"name": "الرئيسية", "url": "admin:index", "permissions": ["auth.view_user"]},
        {"name": "المستخدمين", "url": "/admin/auth/", "new_window": False},
        {"name": "القضايا", "url": "/admin/cases/", "new_window": False},
        {"name": "الجلسات", "url": "/admin/hearings/", "new_window": False},
        {"name": "المستندات", "url": "/admin/documents/", "new_window": False},
        {"name": "القوانين", "url": "/admin/legal/", "new_window": False},
        {"name": "الإشعارات", "url": "/admin/notifications/", "new_window": False},
        {"name": "البحث & AI", "url": "/admin/search/", "new_window": False},
        {"name": "الميراث", "url": "/admin/inheritance/", "new_window": False},
    ],
    "show_sidebar": True,
    "navigation_expanded": True,
    "icons": {
        "laws.Law": "fas fa-book",
        "laws.LawArticle": "fas fa-paragraph",
        "laws.LegalCategory": "fas fa-tags",
        "courts.Court": "fas fa-university",
    },
    "default_icon_parents": "fas fa-chevron-circle-right",
    "default_icon_children": "fas fa-circle",
    "changeform_format": "horizontal_tabs",
}

JAZZMIN_UI_TWEAKS = {
    "navbar_small_text": False,
    "footer_small_text": False,
    "body_small_text": False,
    "brand_small_text": False,
    "brand_colour": "navbar-primary",
    "accent": "accent-primary",
    "navbar": "navbar-dark navbar-primary",
    "no_navbar_border": False,
    "navbar_fixed": True,
    "layout_boxed": False,
    "footer_fixed": False,
    "sidebar_fixed": True,
    "sidebar": "sidebar-dark-primary",
    "sidebar_nav_small_text": False,
    "sidebar_disable_expand": False,
    "sidebar_nav_child_indent": False,
    "sidebar_nav_compact_style": False,
    "sidebar_nav_legacy_style": False,
    "sidebar_nav_flat_style": False,
    "theme": "flatly",
    "dark_mode_theme": None,
}

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]
