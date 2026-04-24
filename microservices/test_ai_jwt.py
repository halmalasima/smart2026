import requests, json

# Get token
r = requests.post('http://127.0.0.1:8000/api/token/', json={'username':'admin','password':'Admin@2026'}, timeout=10)
print('Token status:', r.status_code)
token = r.json().get('access','')
print('Token (first 50):', token[:50])

# Test AI
headers = {'Authorization': 'Bearer ' + token}
payload = {'query': 'ما هو قانون العمل اليمني؟', 'conversation_history': []}
r2 = requests.post('http://127.0.0.1:8000/api/ai/chat/', json=payload, headers=headers, timeout=30)
print('AI status:', r2.status_code)
print('AI response:', r2.text[:200])

# Test ai-chat-logs
r3 = requests.get('http://127.0.0.1:8000/api/ai-chat-logs/', headers=headers, timeout=10)
print('ai-chat-logs status:', r3.status_code)
print('ai-chat-logs response:', r3.text[:200])
