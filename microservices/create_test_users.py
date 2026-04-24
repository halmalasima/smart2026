import django, os, sys
sys.path.insert(0, '/app')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auth_service.settings')
django.setup()

from django.contrib.auth.models import User
from accounts.models import UserProfile

users = [
    ('lawyer1',  'Test@1234', 'lawyer1@test.com',  'lawyer',  'محامي',  'اختبار'),
    ('citizen1', 'Test@1234', 'citizen1@test.com', 'citizen', 'مواطن', 'اختبار'),
    ('admin2',   'Test@1234', 'admin2@test.com',   'admin',   'مدير',  'اختبار'),
]

for username, password, email, role, first, last in users:
    user, created = User.objects.get_or_create(username=username)
    user.set_password(password)
    user.email = email
    user.first_name = first
    user.last_name = last
    user.is_active = True
    user.save()
    profile, _ = UserProfile.objects.get_or_create(user=user)
    profile.role = role
    profile.save()
    print(f'{"Created" if created else "Updated"}: {username} / {password} (role={role})')

admin = User.objects.get(username='admin')
admin.set_password('Admin@2026')
admin.save()
print('Reset admin: admin / Admin@2026 (role=admin)')
