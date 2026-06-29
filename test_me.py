import urllib.request
import urllib.parse
import json

url = 'http://localhost:8000/api/v1/auth/login'
data = urllib.parse.urlencode({'username': '24-001', 'password': '1234'}).encode()
req = urllib.request.Request(url, data=data)
try:
    with urllib.request.urlopen(req) as response:
        res = response.read()
        res_json = json.loads(res.decode())
        token = res_json.get("access_token")
        print(f"Login Success, got token.")
        
        # Now test /auth/me
        me_url = 'http://localhost:8000/api/v1/auth/me'
        me_req = urllib.request.Request(me_url, headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(me_req) as me_response:
            me_res = me_response.read()
            print(f"Me Success: {me_res.decode()}")
            
except urllib.error.HTTPError as e:
    print(f"Error {e.code}: {e.read().decode()}")
except Exception as e:
    print(f"Exception: {e}")
