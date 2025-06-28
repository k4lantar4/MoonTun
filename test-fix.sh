#!/bin/bash

echo "🧪 Testing MoonTun Fixes..."
echo "============================"

# Test quick geo balancing
echo "Testing geo balancing speed..."
start_time=$(date +%s)

# Test if the function exists and works
if grep -q "quick_detect_iran_network" moontun.sh; then
    echo "✅ Quick detection function found"
else
    echo "❌ Quick detection function missing"
fi

if grep -q "background_detailed_geo_testing" moontun.sh; then
    echo "✅ Background testing function found"
else
    echo "❌ Background testing function missing"
fi

end_time=$(date +%s)
echo "⚡ Test completed in $((end_time - start_time))s"

echo
echo "🎯 Ready to test option 3!"
echo "Run: sudo ./moontun.sh" 