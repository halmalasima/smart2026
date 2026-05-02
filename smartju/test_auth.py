import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings.base')
django.setup()

from django.contrib.auth import authenticate
from django.contrib.auth.models import User

def test_login(username, password):
    print(f"Testing login for {username}...")
    user = authenticate(username=username, password=password)
    if user:
        print(f"[OK] Success! User found: {user.username}")
    else:
        print("[FAIL] Failed. User not found or password incorrect.")
        
        # Check if user exists in the DB
        try:
            u = User.objects.get(username=username)
            print(f"[INFO] User '{username}' exists in DB '{u._state.db}'. Password mismatch?")
        except User.DoesNotExist:
            print(f"[INFO] User '{username}' does NOT exist in the database.")

if __name__ == "__main__":
    # Test with common users
    test_login('hussein783', 'hussein783') # Assuming password is same as username for test
    test_login('admin', 'admin')
