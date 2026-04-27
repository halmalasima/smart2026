"""
Django settings package for smartju project.

This package contains different settings configurations:
- base.py: Base settings (shared across all environments)
- staging.py: Staging environment settings
- production.py: Production environment settings (to be created)
"""

# Default to base settings
from .base import *  # noqa: F403, F401

