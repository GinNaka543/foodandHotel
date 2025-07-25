#!/bin/bash
# Keep-alive script for Render.com server
# This script can be used with cron jobs or external services

# Server URL
SERVER_URL="https://happiness-game.onrender.com/api/health"

# Function to ping the server
ping_server() {
    echo "Pinging server at $(date)"
    
    # Make the request with a 30-second timeout
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$SERVER_URL")
    
    if [ "$response" = "200" ]; then
        echo "✅ Server is healthy (Status: $response)"
    else
        echo "❌ Server returned status: $response"
    fi
}

# Main execution
ping_server

# Optionally, you can add multiple endpoints to warm up
warm_up_endpoints() {
    endpoints=(
        "/api/health"
        "/api/create-payment-intent"
        "/api/youtube-download"
    )
    
    for endpoint in "${endpoints[@]}"; do
        url="https://happiness-game.onrender.com$endpoint"
        echo "Warming up: $endpoint"
        curl -s -o /dev/null --max-time 10 "$url" || true
    done
}

# Uncomment to warm up multiple endpoints
# warm_up_endpoints