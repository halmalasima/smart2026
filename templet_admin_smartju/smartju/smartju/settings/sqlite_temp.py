"""
Temporary settings to use SQLite for data export
"""
from .base import *  # noqa

# Override database to use SQLite
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',  # noqa
    }
}

