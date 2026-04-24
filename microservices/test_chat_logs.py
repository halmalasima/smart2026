import requests, json

r = requests.post('http://127.0.0.1:8000/api/token/', json={'username':'admin','password':'Admin@2026'}, timeout=10)
token = r.json().get('access','')
headers = {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}

# Try POST to ai-chat-logs
data = {'user_id': 1, 'query': 'test', 'response': 'test response'}
r2 = requests.post('http://127.0.0.1:8000/api/ai-chat-logs/', json=data, headers=headers, timeout=10)
print('POST ai-chat-logs:', r2.status_code)
print(r2.text[:300])
