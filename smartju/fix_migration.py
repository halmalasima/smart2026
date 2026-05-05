import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings.base')
import django
django.setup()
from django.contrib.auth.models import User

# Check if 781900834 exists  
u = User.objects.filter(username='781900834').first()
if u:
    print(f'Found by username: {u.username}, phone={u.profile.phone_number}')
else:
    u2 = User.objects.filter(profile__phone_number='781900834').first()
    if u2:
        print(f'Found by phone: username={u2.username}, phone={u2.profile.phone_number}')
    else:
        print('No user with 781900834')
        
# Also check superuser
for hu in User.objects.filter(is_superuser=True):
    try:
        phone = hu.profile.phone_number
    except:
        phone = 'N/A'
    print(f'Superuser: {hu.username}, phone={phone}')
