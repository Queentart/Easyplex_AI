import urllib.request
import urllib.parse
import json

url = 'http://localhost:8000/api/v1/auth/login'
data = urllib.parse.urlencode({'username': '24-001', 'password': '1234'}).encode()
req = urllib.request.Request(url, data=data)
try:
    with urllib.request.urlopen(req) as response:
        res = response.read()
        print(f"Success: {res.decode()}")
except urllib.error.HTTPError as e:
    print(f"Error {e.code}: {e.read().decode()}")
except Exception as e:
    print(f"Exception: {e}")
