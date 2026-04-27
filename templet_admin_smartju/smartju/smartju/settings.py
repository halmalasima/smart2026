"""
Django settings for smartju project.

This file is a compatibility layer that imports from settings package.
For staging, use: DJANGO_SETTINGS_MODULE=smartju.settings.staging
"""

import os

# Determine which settings to use based on environment
environment = os.environ.get('DJANGO_ENV', 'development')

if environment == 'staging':
    from .settings.staging import *  # noqa: F403, F401
else:
    # Default to base settings (development)
    from .settings.base import *  # noqa: F403, F401
