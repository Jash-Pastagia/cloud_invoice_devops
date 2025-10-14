#!/bin/bash

# Quick test script to verify React error #31 fixes
# Run this from the frontend/ directory

echo "🧪 Testing React Error #31 Fixes"
echo "================================"

# Check if server is running
echo "1. Checking if development server is running..."
if curl -s http://localhost:5173 > /dev/null; then
    echo "✅ Frontend server is running at http://localhost:5173"
else
    echo "❌ Frontend server is not running. Please run: npm run dev"
    exit 1
fi

echo ""
echo "2. Checking file imports and exports..."

# Check if critical files exist
files=(
    "src/pages/Invoices.jsx"
    "src/pages/InvoiceDetail.jsx"
    "src/utils/renderUtils.js"
    "src/components/ErrorBoundary.jsx"
    ".copilot_debug_instructions.md"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

echo ""
echo "3. Checking for common error patterns..."

# Check for potential React error #31 patterns
echo "Checking for direct object rendering in JSX..."
if grep -n "{.*customer}" src/pages/*.jsx | grep -v "safeRenderCustomer\|customer?.name\|customer.name"; then
    echo "⚠️  Found potential object rendering issues (check above)"
else
    echo "✅ No direct object rendering found"
fi

echo ""
echo "Checking jwt-decode import..."
if grep -n "import jwtDecode from 'jwt-decode'" src/api.js; then
    echo "❌ Found old jwt-decode import style"
else
    echo "✅ jwt-decode import is correct"
fi

echo ""
echo "Checking dayjs plugin imports..."
if grep -l "fromNow\|relativeTime" src/pages/*.jsx | xargs grep -L "dayjs/plugin/relativeTime"; then
    echo "⚠️  Found files using fromNow() without importing relativeTime plugin"
else
    echo "✅ dayjs relativeTime plugin properly imported"
fi

echo ""
echo "4. Manual testing steps:"
echo "   • Open http://localhost:5173 in browser"
echo "   • Open DevTools Console"
echo "   • Login with demo/demo123 or user2/user2123"
echo "   • Navigate to Invoices page"
echo "   • Check for React errors in console"
echo "   • Verify customer names display correctly (not [object Object])"

echo ""
echo "📋 Debug Instructions: See .copilot_debug_instructions.md for full testing guide"
echo "🎯 Expected Result: No React error #31, Invoices page loads successfully"