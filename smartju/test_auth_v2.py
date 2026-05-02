import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings.base')
django.setup()

from django.contrib.auth.models import User
from django.contrib.auth import authenticate

def setup_test_user():
    username = 'ai_test_user'
    password = 'ai_password_123'
    
    # Use auth_db
    db = 'auth_db'
    
    print(f"Creating/resetting user {username} in {db}...")
    User.objects.using(db).filter(username=username).delete()
    user = User.objects.db_manager(db).create_user(username=username, password=password)
    print(f"User created. Password hash: {user.password}")
    
    # Try to authenticate
    print(f"Testing authentication for {username}...")
    auth_user = authenticate(username=username, password=password)
    if auth_user:
        print(f"[OK] Authentication successful for {auth_user.username}")
    else:
        print("[FAIL] Authentication failed for newly created user!")
        # Check why
        u = User.objects.using(db).get(username=username)
        print(f"User check_password results: {u.check_password(password)}")

if __name__ == "__main__":
    setup_test_user()
