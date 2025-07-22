#!/bin/bash

echo "Starting Happiness Game Admin..."

# サーバーを起動
echo "Starting server on port 5002..."
cd server
npm start &
SERVER_PID=$!

# 少し待つ
sleep 3

# クライアントを起動
echo "Starting client on port 3000..."
cd ../client
npm start &
CLIENT_PID=$!

echo "Server PID: $SERVER_PID"
echo "Client PID: $CLIENT_PID"
echo "Press Ctrl+C to stop both processes"

# 両方のプロセスを待つ
wait $SERVER_PID $CLIENT_PID