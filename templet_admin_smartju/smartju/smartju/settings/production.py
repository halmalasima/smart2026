"""
Django settings for smartju project - Production Settings for Render
"""
from .base import *  # noqa
import os
import dj_database_url

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = False

# SECURITY WARNING: enforce real SECRET_KEY in production!
if SECRET_KEY == 'django-insecure-4cyci@v!&=khm4+b)(^n@&k0((=5o5=o^r8w&)#4h=wdl)cjx=':
    from django.core.exceptions import ImproperlyConfigured
    raise ImproperlyConfigured("SECRET_KEY must be set in the environment for production.")


# Update allowed hosts from environment variable
ALLOWED_HOSTS_STR = os.environ.get('ALLOWED_HOSTS', '')
if ALLOWED_HOSTS_STR:
    ALLOWED_HOSTS = [host.strip() for host in ALLOWED_HOSTS_STR.split(',') if host.strip()]
else:
    # Only allow Render domains by default — never use '*' in production
    ALLOWED_HOSTS = ['smartjudi-nls1.onrender.com', '.onrender.com', 'localhost', '127.0.0.1']

# Database - use Render's DATABASE_URL
DATABASES = {
    'default': dj_database_url.config(
        default=os.environ.get('DATABASE_URL'),
        conn_max_age=600,
        conn_health_checks=True,
    )
}

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'  # noqa
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Security settings
# Disable SSL redirect for health checks (Render handles SSL)
SECURE_SSL_REDIRECT = False  # Render handles SSL termination
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'

# CORS settings for production
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS_ENV = os.environ.get('CORS_ALLOWED_ORIGINS', '')
if CORS_ALLOWED_ORIGINS_ENV:
    CORS_ALLOWED_ORIGINS = [origin.strip() for origin in CORS_ALLOWED_ORIGINS_ENV.split(',') if origin.strip()]
else:
    CORS_ALLOWED_ORIGINS = []

# Always allow Render subdomains via regex
CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^https://.*\.onrender\.com$",
]

# Allow credentials for authenticated requests
CORS_ALLOW_CREDENTIALS = True
