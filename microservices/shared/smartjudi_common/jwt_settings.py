"""
Shared JWT configuration for all SmartJudi microservices.

Usage in each service's settings.py:
    from smartjudi_common.jwt_settings import get_simple_jwt_config
    SIMPLE_JWT = get_simple_jwt_config(SECRET_KEY)
"""
from datetime import timedelta


def get_simple_jwt_config(signing_key: str, verifying_key: str = '', algorithm: str = 'HS256') -> dict:
    """Return SIMPLE_JWT settings dict using the shared signing key."""
    cfg = {
        'ACCESS_TOKEN_LIFETIME': timedelta(hours=2),
        'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
        'ROTATE_REFRESH_TOKENS': True,
        'BLACKLIST_AFTER_ROTATION': True,
        'ALGORITHM': algorithm,
        'SIGNING_KEY': signing_key,
        'AUTH_HEADER_TYPES': ('Bearer',),
        'TOKEN_OBTAIN_SERIALIZER': 'rest_framework_simplejwt.serializers.TokenObtainPairSerializer',
    }

    if verifying_key:
        cfg['VERIFYING_KEY'] = verifying_key

    return cfg


def get_rest_framework_config() -> dict:
    """Return shared DRF settings for all services."""
    return {
        'DEFAULT_AUTHENTICATION_CLASSES': (
            'rest_framework_simplejwt.authentication.JWTStatelessUserAuthentication',
        ),
        'DEFAULT_PERMISSION_CLASSES': [
            'rest_framework.permissions.IsAuthenticated',
        ],
        'DEFAULT_RENDERER_CLASSES': (
            'rest_framework.renderers.JSONRenderer',
        ),
        'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
        'PAGE_SIZE': 20,
        'DEFAULT_FILTER_BACKENDS': (
            'django_filters.rest_framework.DjangoFilterBackend',
            'rest_framework.filters.SearchFilter',
            'rest_framework.filters.OrderingFilter',
        ),
    }
