import os, sys, json

os.environ['DJANGO_SETTINGS_MODULE'] = 'legal_service.settings'
sys.path.insert(0, '/app')

import django
django.setup()

from courts.models import Governorate, Court

DATA = json.loads(open('/app/load_courts_data.json', encoding='utf-8').read())

created_gov = 0
created_court = 0
skipped_court = 0

for entry in DATA:
    gov_name = entry['governorate'].strip()
    courts_list = entry.get('courts', [])

    gov, gov_new = Governorate.objects.get_or_create(name=gov_name)
    if gov_new:
        created_gov += 1
        print(f'✅ محافظة جديدة: {gov_name}')
    else:
        print(f'🔄 محافظة موجودة: {gov_name}')

    for court_name in courts_list:
        court_name = court_name.strip()
        if not court_name:
            continue
        court, court_new = Court.objects.get_or_create(
            name=court_name,
            governorate=gov,
            defaults={'is_active': True}
        )
        if court_new:
            created_court += 1
        else:
            skipped_court += 1

print(f'\n📊 النتائج:')
print(f'  المحافظات الجديدة: {created_gov}')
print(f'  المحاكم الجديدة:   {created_court}')
print(f'  المحاكم الموجودة:  {skipped_court}')
print(f'\n✅ تم الانتهاء بنجاح.')
