import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'cases_service.settings')
application = get_wsgi_application()

# Start Redis event listeners (hearings + documents events → CaseFileItem)
try:
    from cases_service.event_handlers import start_event_listeners
    start_event_listeners()
except Exception:
    pass
