import requests
import time

base = 'http://127.0.0.1:8000'

# Get token
token_resp = requests.post(f'{base}/api/token/', json={'username': 'admin', 'password': 'Admin@2026'}, timeout=10)
print(f'Token status: {token_resp.status_code}')
token = token_resp.json()['access']

# Create a case first
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
case_payload = {
    'case_number': str(int(time.time())),
    'subject': 'Test case for lawsuit',
    'filing_date': '2026-04-22',
    'gregorian_date': '2026-04-22',
    'case_year_hijri': 1447,
    'case_status': 'جديد',
    'case_type': 'مدنية',
    'case_subtype': 'مدنية',
    'governorate': 'امانة العاصمة',
    'court_id': 1
}
case_resp = requests.post(f'{base}/api/cases/', headers=headers, json=case_payload, timeout=15)
print(f'Create case status: {case_resp.status_code}')
if case_resp.status_code != 201:
    print(f'Error creating case: {case_resp.text}')
    exit(1)
case_id = case_resp.json()['id']
print(f'Created case ID: {case_id}')

# Create a lawsuit
lawsuit_payload = {
    'case': case_id,
    'case_number': f'L-{int(time.time())}',
    'case_type': 'دعوى',
    'case_status': 'جديد',
    'subject': 'Test lawsuit',
    'filing_date': '2026-04-22',
    'gregorian_date': '2026-04-22',
    'case_year_hijri': 1447,
    'governorate': 'امانة العاصمة',
    'court_id': 1
}
lawsuit_resp = requests.post(f'{base}/api/lawsuits/', headers=headers, json=lawsuit_payload, timeout=15)
print(f'Create lawsuit status: {lawsuit_resp.status_code}')
with open('lawsuit_error.html', 'w', encoding='utf-8') as f:
    f.write(lawsuit_resp.text)
print('Saved response to lawsuit_error.html')
# Try to extract error
if lawsuit_resp.status_code != 201:
    print(f'Response: {lawsuit_resp.text[:1000]}')
