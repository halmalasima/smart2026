import os, sys
os.environ['DJANGO_SETTINGS_MODULE'] = 'auth_service.settings'
sys.path.insert(0, '/app')

try:
    import django
    django.setup()
    print("Django setup OK")
except Exception as e:
    print("Django setup FAILED:", e)
    sys.exit(1)

try:
    from django.test import RequestFactory
    from django.core.handlers.wsgi import WSGIHandler

    factory = RequestFactory()
    body = '{"username":"admin","password":"Admin@2026"}'
    request = factory.post('/api/token/', data=body,
        content_type='application/json', HTTP_HOST='localhost:8000')

    handler = WSGIHandler()
    resp_holder = {}
    def start_response(status, headers):
        resp_holder['status'] = status
        resp_holder['headers'] = headers

    body_iter = handler(request.environ, start_response)
    body_bytes = b''.join(body_iter)
    print("HTTP Status:", resp_holder.get('status'))
    print("Response:", body_bytes[:200])
except Exception as e:
    import traceback
    print("Error:", e)
    traceback.print_exc()
