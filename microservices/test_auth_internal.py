import urllib.request, json
data = json.dumps({'username': 'admin', 'password': 'Admin@2026'}).encode()
req = urllib.request.Request(
    'http://localhost:8000/api/token/', data=data,
    headers={'Content-Type': 'application/json', 'Host': 'auth:8000'}
)
try:
    r = urllib.request.urlopen(req, timeout=5)
    print('OK:', r.status, r.read()[:80])
except urllib.error.HTTPError as e:
    print('HTTPError:', e.code, e.read()[:100])
except Exception as ex:
    print('Error:', ex)
