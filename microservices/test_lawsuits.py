import requests

base = 'http://127.0.0.1:8000'

# Get token
token_resp = requests.post(f'{base}/api/token/', json={'username': 'admin', 'password': 'Admin@2026'}, timeout=10)
print(f'Token status: {token_resp.status_code}')
token = token_resp.json()['access']

# Get lawsuits
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
lawsuits_resp = requests.get(f'{base}/api/lawsuits/', headers=headers, timeout=15)
print(f'Lawsuits status: {lawsuits_resp.status_code}')
with open('lawsuits_error.html', 'w', encoding='utf-8') as f:
    f.write(lawsuits_resp.text)
print('Saved response to lawsuits_error.html')
if lawsuits_resp.status_code != 200:
    print(f'Response: {lawsuits_resp.text[:1000]}')
