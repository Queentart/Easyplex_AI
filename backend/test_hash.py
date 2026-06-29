import sys
import os
import asyncio

base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(base_dir)

from app.core.security import get_password_hash, verify_password

def main():
    h = get_password_hash("1234")
    print(f"Hash of 1234: {h}")
    print(f"Verify 1234 with hash: {verify_password('1234', h)}")

if __name__ == "__main__":
    main()
