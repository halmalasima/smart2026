import urllib.request, json
data = json.dumps({'username': 'admin', 'password': 'Admin@2026'}).encode()
req = urllib.request.Request(
    'http://localhost:80/api/token/', data=data,
    headers={'Content-Type': 'application/json'}
)
try:
    r = urllib.request.urlopen(req, timeout=5)
    print('OK:', r.status, r.read()[:80])
except urllib.error.HTTPError as e:
    print('HTTPError:', e.code, e.read()[:200])
except Exception as ex:
    print('Error:', ex)
