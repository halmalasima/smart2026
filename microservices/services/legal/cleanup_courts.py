import os
import sys
import django
from django.db import transaction
from django.db.models import Count, Q

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'legal_service.settings')
django.setup()

from courts.models import Governorate, District, Court

def standardize_gov_name(name):
    std = name.replace('محافظة ', '').strip()
    if std in ['أمانة العاصمة', 'أمانة العاصمة صنعاء']:
        return 'أمانة العاصمة'
    return std

def clean_governorates():
    print("Starting Governorates cleanup...")
    
    # 1. Group by standardized name
    groups = {}
    for gov in Governorate.objects.all():
        std = standardize_gov_name(gov.name)
        if std not in groups:
            groups[std] = []
        groups[std].append(gov)
    
    for std_name, govs in groups.items():
        # Sort by court count descending to pick the best master
        govs_with_info = []
        for g in govs:
            govs_with_info.append({
                'obj': g,
                'court_count': g.courts.count(),
                'dist_count': g.districts.count(),
            })
        govs_with_info.sort(key=lambda x: (x['court_count'], x['dist_count']), reverse=True)
        
        master = govs_with_info[0]['obj']
        slaves = [g['obj'] for g in govs_with_info[1:]]
        
        if slaves:
            print(f"Merging {len(slaves)} slaves into master: {master.name} (will be {std_name})")
            with transaction.atomic():
                for slave in slaves:
                    # Move related records
                    District.objects.filter(governorate=slave).update(governorate=master)
                    Court.objects.filter(governorate=slave).update(governorate=master)
                    # Delete slave
                    slave.delete()
        
        # Finally, ensure master has the correct name
        if master.name != std_name:
            print(f"Renaming master: {master.name} -> {std_name}")
            # Check if std_name exists elsewhere (shouldn't if we grouped correctly)
            try:
                master.name = std_name
                master.save()
            except Exception as e:
                print(f"  Error renaming {master.name} to {std_name}: {e}")
                # If it exists, we might need to merge again, but for now just skip
                pass

def import_missing_courts():
    import json
    print("Importing missing courts from JSON...")
    # Look for the file in several potential locations
    json_locations = [
        '/tmp/governorates_courts_final.json',
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), 'governorates_courts_final.json'),
        'governorates_courts_final.json'
    ]
    
    data = None
    for loc in json_locations:
        if os.path.exists(loc):
            with open(loc, 'r', encoding='utf-8') as f:
                data = json.load(f)
                break
    
    if data is None:
        print("JSON file not found.")
        return

    for entry in data:
        gov_name = standardize_gov_name(entry['governorate'])
        gov, _ = Governorate.objects.get_or_create(name=gov_name)
        
        for court_name in entry['courts']:
            court_name = court_name.strip()
            # Case insensitive check
            exists = Court.objects.filter(governorate=gov, name__iexact=court_name).exists()
            if not exists:
                print(f"  Adding missing court: {court_name} in {gov_name}")
                Court.objects.create(
                    name=court_name,
                    governorate=gov,
                    is_active=True
                )

if __name__ == "__main__":
    clean_governorates()
    import_missing_courts()
    print("Cleanup and import finished.")
