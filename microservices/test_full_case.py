import requests

base = 'http://127.0.0.1:8000'

# Get token
token_resp = requests.post(f'{base}/api/token/', json={'username': 'admin', 'password': 'Admin@2026'}, timeout=10)
print(f'Token status: {token_resp.status_code}')
token = token_resp.json()['access']

# Create case
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
payload = {
    'case_number': '999999',
    'subject': 'Test full case flow',
    'filing_date': '2026-04-22',
    'gregorian_date': '2026-04-22',
    'case_year_hijri': 1447,
    'case_status': 'جديد',
    'case_type': 'مدنية',
    'case_subtype': 'مدنية',
    'governorate': 'امانة العاصمة',
    'court_id': 1
}
case_resp = requests.post(f'{base}/api/cases/', headers=headers, json=payload, timeout=15)
print(f'Create case status: {case_resp.status_code}')
if case_resp.status_code == 201:
    case_id = case_resp.json()['id']
    print(f'Created case ID: {case_id}')
    
    # Get lawsuits for this case
    lawsuits_resp = requests.get(f'{base}/api/lawsuits/?case={case_id}', headers=headers, timeout=15)
    print(f'Get lawsuits status: {lawsuits_resp.status_code}')
    print(f'Lawsuits response: {lawsuits_resp.text[:200]}')
else:
    print(f'Error: {case_resp.text}')
