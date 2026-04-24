import django, os, sys
sys.path.insert(0, '/app')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auth_service.settings')
django.setup()

from django.contrib.auth.models import User
from accounts.models import UserProfile

fixes = [
    ('admin',    'admin',   True),
    ('admin2',   'admin',   False),
    ('lawyer1',  'lawyer',  False),
    ('citizen1', 'citizen', False),
]

for username, role, is_superuser in fixes:
    try:
        user = User.objects.get(username=username)
        profile, created = UserProfile.objects.get_or_create(user=user)
        profile.role = role
        profile.is_active = True
        profile.save()
        print(f'Fixed {username}: role={role}, profile_created={created}')
    except User.DoesNotExist:
        print(f'User {username} not found')

print('Done.')
