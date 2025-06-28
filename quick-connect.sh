#!/bin/bash

# Quick MoonTun Connect (Syntax Fixed)
sudo ./moontun.sh &
sleep 2
echo "3" | sudo tee /proc/${!}/fd/0 2>/dev/null || echo "3"
wait

echo "✅ Connection attempt completed!"

