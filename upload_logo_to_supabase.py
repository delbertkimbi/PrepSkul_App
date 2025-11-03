#!/usr/bin/env python3
"""
Upload PrepSkul logo to Supabase Storage
Run this script to upload logo-white.png to Supabase
"""

import requests
import os
from pathlib import Path

# Configuration
SUPABASE_URL = os.getenv('SUPABASE_URL')  # Your Supabase URL
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY')  # Your anon key or service role key
LOGO_PATH = '../PrepSkul_Web/public/logo-white.png'
BUCKET_NAME = 'public'
FILE_NAME = 'logo-white.png'

def upload_to_supabase():
    print("🚀 Uploading PrepSkul logo to Supabase Storage...")
    print(f"📁 Logo: {LOGO_PATH}")
    print(f"📦 Bucket: {BUCKET_NAME}")
    print(f"📄 File: {FILE_NAME}")
    print()
    
    # Check if file exists
    if not os.path.exists(LOGO_PATH):
        print(f"❌ Error: Logo not found at {LOGO_PATH}")
        return
    
    # Read logo file
    with open(LOGO_PATH, 'rb') as f:
        logo_data = f.read()
    
    # Upload to Supabase Storage
    upload_url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{FILE_NAME}"
    
    headers = {
        'Authorization': f'Bearer {SUPABASE_KEY}',
        'Content-Type': 'image/png',
    }
    
    try:
        response = requests.post(upload_url, headers=headers, data=logo_data)
        
        if response.status_code in [200, 201]:
            print("✅ Logo uploaded successfully!")
            public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{FILE_NAME}"
            print(f"📎 Public URL: {public_url}")
            print()
            print("📝 Copy this URL and use it in your Supabase email template!")
        else:
            print(f"❌ Error: {response.status_code}")
            print(response.text)
            
    except Exception as e:
        print(f"❌ Error: {e}")
        print()
        print("💡 Make sure you have:")
        print("  1. SUPABASE_URL environment variable set")
        print("  2. SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY set")

if __name__ == '__main__':
    upload_to_supabase()

