import os
import json
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'smartju.settings.base')
django.setup()

from courts.models import Governorate, Court, CourtType

def import_courts(json_file_path):
    print(f"Loading data from {json_file_path}...")
    with open(json_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Ensure a default CourtType exists
    primary_type, _ = CourtType.objects.get_or_create(
        name='محكمة ابتدائية',
        defaults={'judicial_level': 'primary'}
    )

    governorates_created = 0
    courts_created = 0

    for item in data:
        gov_name = item.get('governorate')
        courts_list = item.get('courts', [])

        if not gov_name:
            continue

        # Get or create governorate
        gov, created = Governorate.objects.get_or_create(name=gov_name)
        if created:
            governorates_created += 1
            print(f"Created Governorate: {gov_name}")

        for court_name in courts_list:
            if not court_name:
                continue
                
            # Create court if it doesn't exist in this governorate
            court, c_created = Court.objects.get_or_create(
                name=court_name,
                governorate=gov,
                defaults={'court_type': primary_type}
            )
            if c_created:
                courts_created += 1
                # print(f"  Created Court: {court_name}")

    print("-" * 30)
    print(f"Import Summary:")
    print(f"Governorates created: {governorates_created}")
    print(f"Courts created: {courts_created}")
    print("Done!")

if __name__ == "__main__":
    json_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'governorates_courts_final.json')
    import_courts(json_path)
