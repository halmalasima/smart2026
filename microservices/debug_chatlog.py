import os, sys
os.environ['DJANGO_SETTINGS_MODULE'] = 'search_service.settings'
sys.path.insert(0, '/app')
import django
django.setup()

from search_app.models import AIChatLog
try:
    log = AIChatLog(
        user_id=1,
        question='test question',
        answer='test answer',
        model_version='groq'
    )
    log.save()
    print('SUCCESS: created AIChatLog id=', log.id)
except Exception as e:
    import traceback
    print('ERROR:', e)
    traceback.print_exc()
