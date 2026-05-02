import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings.base')
django.setup()

from django.contrib.auth.models import User
from accounts.models import UserProfile

# 1. List all users
print("=== All Users ===")
for u in User.objects.all():
    print(f"  id={u.id}, username={u.username}, is_active={u.is_active}, is_staff={u.is_staff}")

# 2. Check if user 777123456 exists and password works
try:
    u = User.objects.get(username='777123456')
    print(f"\nUser 777123456: active={u.is_active}, check_pw={u.check_password('Admin@2026')}")
except User.DoesNotExist:
    print("\nUser 777123456 does NOT exist!")

# 3. Check all UserProfiles
print("\n=== All UserProfiles ===")
for p in UserProfile.objects.all():
    print(f"  user={p.user.username}, phone={p.phone_number}, role={p.role}")

# 4. Check AUTHENTICATION_BACKENDS
from django.conf import settings
backends = getattr(settings, 'AUTHENTICATION_BACKENDS', ['default Django backend'])
print(f"\n=== AUTHENTICATION_BACKENDS ===\n  {backends}")

# 5. Test actual Django authenticate()
from django.contrib.auth import authenticate
result = authenticate(username='777123456', password='Admin@2026')
print(f"\nauthenticate(username=777123456, password=Admin@2026) = {result}")

result2 = authenticate(username='admin', password='Admin@2026')
print(f"authenticate(username=admin, password=Admin@2026) = {result2}")

# 6. Check SimpleJWT settings
jwt_settings = getattr(settings, 'SIMPLE_JWT', {})
print(f"\n=== SimpleJWT Algorithm ===\n  {jwt_settings.get('ALGORITHM', 'not set')}")
