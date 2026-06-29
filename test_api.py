import urllib.request
import json
import sys

data = json.dumps({'mode': 'instructor', 'message': '[test] Test message', 'student_name': 'Test Student'}).encode()
req = urllib.request.Request('http://localhost:8000/api/v1/student/support/message', data=data, headers={'Content-Type': 'application/json'})

try:
    urllib.request.urlopen(req)
except urllib.error.HTTPError as e:
    print(e.read().decode())
    sys.exit(1)
