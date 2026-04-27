import json
import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'legal_service.settings')
django.setup()

from courts.models import Governorate, Court, CourtType

def seed_courts(json_file_path):
    with open(json_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Get or create a default court type
    ct, _ = CourtType.objects.get_or_create(
        name='ابتدائي', 
        defaults={'judicial_level': 'primary'}
    )
    
    for entry in data:
        gov_name = entry['governorate'].replace('محافظة ', '')
        gov, created = Governorate.objects.get_or_create(name=gov_name)
        if created:
            print(f"Created Governorate: {gov_name}")
        
        for court_name in entry['courts']:
            court, created = Court.objects.get_or_create(
                name=court_name,
                governorate=gov,
                defaults={'court_type': ct}
            )
            if created:
                print(f"  Created Court: {court_name}")

if __name__ == "__main__":
    seed_courts('/tmp/governorates_courts_final.json')
