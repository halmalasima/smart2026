import os
import django
from django.conf import settings
import dj_database_url
import time

# Configure settings manually to avoid importing production.py issues
if not settings.configured:
    settings.configure(
        DATABASES={
            'default': dj_database_url.config(
                default=os.environ.get('DATABASE_URL'),
                conn_max_age=600,
                conn_health_checks=True,
            )
        },
        INSTALLED_APPS=[
            'django.contrib.auth',
            'django.contrib.contenttypes',
        ],
    )
    django.setup()

from django.db import connection

print("Testing connection to Render database...")
start = time.time()
try:
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        print(f"✓ Connection successful! (Time: {time.time() - start:.2f}s)")
        
        cursor.execute("SELECT count(*) FROM auth_user")
        count = cursor.fetchone()[0]
        print(f"✓ Current Users count: {count}")
        
except Exception as e:
    print(f"❌ Connection failed: {e}")
