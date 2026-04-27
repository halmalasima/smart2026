import urllib.request, json
try:
 req = urllib.request.Request('http://127.0.0.1:8000/api/token/', data=json.dumps({'username': '783783351', 'password': 'password123'}).encode('utf-8'), headers={'Content-Type': 'application/json'})
 resp = urllib.request.urlopen(req)
 data = json.loads(resp.read().decode())
 token = data['access']
 print('Got token!')
except Exception as e:
 print('Login Error:', e); exit(1)

try:
 req2 = urllib.request.Request('http://127.0.0.1:8000/api/cases/', headers={'Authorization': 'Bearer ' + token})
 print('Cases response:', urllib.request.urlopen(req2).status)
except Exception as e:
 print('Cases Error:', e, e.read().decode('utf-8') if hasattr(e, 'read') else '')
