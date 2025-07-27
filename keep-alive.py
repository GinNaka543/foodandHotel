#!/usr/bin/env python3
"""
Keep-alive script for Render.com server
Can be run as a cron job or scheduled task
"""

import requests
import time
from datetime import datetime
import sys
import json

# Configuration
SERVER_BASE_URL = "https://happiness-game.onrender.com"
HEALTH_ENDPOINT = "/api/health"
TIMEOUT = 30  # seconds

# Optional: Add more endpoints to warm up
WARM_UP_ENDPOINTS = [
    "/api/health",
    # "/api/create-payment-intent",  # Uncomment if needed
    # "/api/youtube-download"         # Uncomment if needed
]

def ping_server(endpoint=HEALTH_ENDPOINT):
    """Ping a server endpoint and return the status"""
    url = f"{SERVER_BASE_URL}{endpoint}"
    
    try:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Pinging: {url}")
        
        response = requests.get(url, timeout=TIMEOUT)
        
        if response.status_code == 200:
            print(f"✅ Server is healthy (Status: {response.status_code})")
            
            # Try to parse JSON response
            try:
                data = response.json()
                print(f"   Response: {json.dumps(data, indent=2)}")
            except:
                print(f"   Response: {response.text[:100]}...")
                
            return True
        else:
            print(f"⚠️  Server returned status: {response.status_code}")
            return False
            
    except requests.exceptions.Timeout:
        print(f"❌ Request timed out after {TIMEOUT} seconds")
        return False
        
    except requests.exceptions.ConnectionError:
        print(f"❌ Failed to connect to server")
        return False
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def warm_up_all_endpoints():
    """Warm up multiple endpoints"""
    print(f"\n{'='*50}")
    print(f"Starting server warm-up at {datetime.now()}")
    print(f"{'='*50}\n")
    
    success_count = 0
    
    for endpoint in WARM_UP_ENDPOINTS:
        if ping_server(endpoint):
            success_count += 1
        time.sleep(1)  # Small delay between requests
    
    print(f"\n{'='*50}")
    print(f"Warm-up complete: {success_count}/{len(WARM_UP_ENDPOINTS)} endpoints responded")
    print(f"{'='*50}\n")
    
    return success_count == len(WARM_UP_ENDPOINTS)

def main():
    """Main function"""
    # You can customize this based on your needs
    
    # Option 1: Just ping the health endpoint
    success = ping_server()
    
    # Option 2: Warm up all endpoints (uncomment if needed)
    # success = warm_up_all_endpoints()
    
    # Exit with appropriate code for monitoring tools
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()