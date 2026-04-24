import os, sys
import jwt
import urllib.request, json

# Get fresh token from auth service
data = json.dumps({'username': 'admin', 'password': 'Admin@2026'}).encode()
req = urllib.request.Request(
    'http://gateway:80/api/token/', data=data,
    headers={'Content-Type': 'application/json'}
)
try:
    r = urllib.request.urlopen(req, timeout=5)
    token_data = json.loads(r.read())
    access_token = token_data['access']
    print("Token obtained:", access_token[:50])
except Exception as e:
    print("Token request failed:", e)
    sys.exit(1)

# Try to decode with current JWT_SECRET
JWT_SECRET = os.getenv("JWT_SECRET_KEY", os.getenv("JWT_SECRET", ""))
print("JWT_SECRET (first 40):", JWT_SECRET[:40])

try:
    decoded = jwt.decode(access_token, JWT_SECRET, algorithms=["HS256"])
    print("Decode SUCCESS:", decoded)
except jwt.PyJWTError as e:
    print("Decode FAILED:", e)

# Also try with no verification to see payload
try:
    unverified = jwt.decode(access_token, options={"verify_signature": False}, algorithms=["HS256"])
    print("Unverified payload:", unverified)
except Exception as e:
    print("Unverified decode error:", e)
