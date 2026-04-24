import requests
import json

base = 'http://127.0.0.1:8000'

# Get token
token_resp = requests.post(f'{base}/api/token/', json={'username': 'admin', 'password': 'Admin@2026'}, timeout=10)
print(f'Token status: {token_resp.status_code}')
token = token_resp.json()['access']

# Create case
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
payload = {
    'case_number': '777777',
    'subject': 'Test case from API',
    'filing_date': '2026-04-22',
    'gregorian_date': '2026-04-22',
    'case_year_hijri': 1447,
    'case_status': 'جديد',
    'case_type': 'مدنية',
    'case_subtype': 'مدنية',
    'governorate': 'امانة العاصمة',
    'court_id': 1
}

create_resp = requests.post(f'{base}/api/cases/', headers=headers, json=payload, timeout=15)
print(f'Create status: {create_resp.status_code}')
print(f'Response: {create_resp.text}')
