import os, sys, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'auth_service.settings')
sys.path.insert(0, '/app')
sys.path.insert(0, '/app/shared')
django.setup()

from django.contrib.auth.models import User
from accounts.serializers import CustomTokenObtainPairSerializer

# Simulate what the view does
data = {'username': '783783351', 'password': 'TestPass123!'}
serializer = CustomTokenObtainPairSerializer(data=data)
try:
    validated = serializer.is_valid(raise_exception=True)
    print(f'SUCCESS: {serializer.validated_data}')
except Exception as e:
    print(f'FAILED: {e}')
    # Try manually
    from accounts.models import UserProfile
    profile = UserProfile.objects.filter(phone_number='783783351').first()
    if profile:
        user = profile.user
        print(f'Manual check: user={user.username}, active={user.is_active}, pwd_ok={user.check_password("TestPass123!")}')
