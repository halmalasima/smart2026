import requests, json

users = [('admin','Admin@2026'), ('lawyer1','Test@1234'), ('citizen1','Test@1234')]
for username, password in users:
    r = requests.post('http://localhost:8000/api/token/', json={'username': username, 'password': password}, timeout=10)
    token = r.json().get('access', '')
    headers = {'Authorization': 'Bearer ' + token}
    resp = requests.get('http://localhost:8000/api/profiles/me/', headers=headers, timeout=10)
    d = resp.json()
    print(username + ': role=' + str(d.get('role')) + ', name=' + str(d.get('username')))
