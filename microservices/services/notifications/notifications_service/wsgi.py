import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'notifications_service.settings')
application = get_wsgi_application()

# Start Redis event listeners (lawsuit + hearing events → Notification)
try:
    from notifications_service.event_handlers import start_event_listener
    start_event_listener()
except Exception:
    pass
