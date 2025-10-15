#!/bin/bash

# Invoice Creation Test Suite
# Tests all possible scenarios for POST /invoices endpoint

set -e

BASE_URL="http://localhost:5050"
AUTH_URL="http://localhost:4000"

echo "🧪 Invoice Creation Test Suite"
echo "================================"

# Generate test tokens for different users
echo "📝 Generating test tokens..."
DEMO_TOKEN=$(docker compose exec -T auth-service node -e "const jwt=require('jsonwebtoken'); console.log(jwt.sign({userId:'3e7addf7-d427-4444-8fe8-0a9b53568975', username:'demo'}, process.env.JWT_SECRET||'supersecretdevops', {expiresIn:'1h'}));" 2>/dev/null)
USER2_TOKEN=$(docker compose exec -T auth-service node -e "const jwt=require('jsonwebtoken'); console.log(jwt.sign({userId:'5a0138f5-bf5e-4039-a3fd-6eb7151fbf17', username:'user2'}, process.env.JWT_SECRET||'supersecretdevops', {expiresIn:'1h'}));" 2>/dev/null)

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper function
run_test() {
    local test_name="$1"
    local expected_status="$2"
    local request_data="$3"
    local token="$4"
    local expected_message="$5"
    
    echo -n "$test_name... "
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST "$BASE_URL/invoices" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "$request_data")
    
    http_status=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    response_body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    if [ "$http_status" = "$expected_status" ]; then
        if [ -n "$expected_message" ]; then
            if echo "$response_body" | grep -q "$expected_message"; then
                echo "✅ PASS"
                ((TESTS_PASSED++))
            else
                echo "❌ FAIL (Wrong message: $response_body)"
                ((TESTS_FAILED++))
            fi
        else
            echo "✅ PASS"
            ((TESTS_PASSED++))
        fi
    else
        echo "❌ FAIL (Expected $expected_status, got $http_status: $response_body)"
        ((TESTS_FAILED++))
    fi
}

echo ""

# Test 1: Missing authorization token
run_test "Test 1: Missing authorization token" "401" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":1,"price":10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "" "Access token required"

# Test 2: Invalid authorization token
run_test "Test 2: Invalid authorization token" "401" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":1,"price":10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "invalid-token" "Invalid or expired token"

# Test 3: Missing customer
run_test "Test 3: Missing customer" "400" \
    '{"items":[{"desc":"Item A","qty":1,"price":10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Customer information is required"

# Test 4: Missing assigneeId
run_test "Test 4: Missing assigneeId" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":1,"price":10}],"dueDate":"2025-12-01"}' \
    "$DEMO_TOKEN" "Assignee ID is required"

# Test 5: Invalid assigneeId (user doesn't exist)
run_test "Test 5: Invalid assigneeId" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":1,"price":10}],"dueDate":"2025-12-01","assigneeId":"nonexistent-user-id"}' \
    "$DEMO_TOKEN" "Assignee user not found"

# Test 6: Missing due date
run_test "Test 6: Missing due date" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":1,"price":10}],"assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Due date is required"

# Test 7: Empty items array
run_test "Test 7: Empty items array" "400" \
    '{"customer":{"name":"Test Co"},"items":[],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Items must be a non-empty array"

# Test 8: Missing items
run_test "Test 8: Missing items" "400" \
    '{"customer":{"name":"Test Co"},"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Items must be a non-empty array"

# Test 9: Invalid item - missing description
run_test "Test 9: Invalid item - missing description" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"qty":1,"price":10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Description is required"

# Test 10: Invalid item - empty description
run_test "Test 10: Invalid item - empty description" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"","qty":1,"price":10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Description is required"

# Test 11: Invalid item - zero quantity
run_test "Test 11: Invalid item - zero quantity" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":0,"price":10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Quantity must be greater than 0"

# Test 12: Invalid item - negative quantity
run_test "Test 12: Invalid item - negative quantity" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":-1,"price":10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Quantity must be greater than 0"

# Test 13: Invalid item - negative price
run_test "Test 13: Invalid item - negative price" "400" \
    '{"customer":{"name":"Test Co"},"items":[{"desc":"Item A","qty":1,"price":-10}],"dueDate":"2025-12-01","assigneeId":"3e7addf7-d427-4444-8fe8-0a9b53568975"}' \
    "$DEMO_TOKEN" "Price must be 0 or greater"

# Test 14: Valid invoice creation - basic
run_test "Test 14: Valid invoice creation - basic" "201" \
    '{"customer":{"name":"Test Company"},"items":[{"desc":"Consulting Services","qty":5,"price":100}],"dueDate":"2025-12-01","assigneeId":"5a0138f5-bf5e-4039-a3fd-6eb7151fbf17"}' \
    "$DEMO_TOKEN"

# Test 15: Valid invoice creation - multiple items
run_test "Test 15: Valid invoice creation - multiple items" "201" \
    '{"customer":{"name":"ABC Corp"},"items":[{"desc":"Item 1","qty":2,"price":50},{"desc":"Item 2","qty":1,"price":25}],"dueDate":"2025-12-15","assigneeId":"c84bdf35-d37f-468d-9ca4-561f12493736"}' \
    "$USER2_TOKEN"

# Test 16: Valid invoice creation - zero price item
run_test "Test 16: Valid invoice creation - zero price item" "201" \
    '{"customer":{"name":"Free Service Co"},"items":[{"desc":"Free Consultation","qty":1,"price":0}],"dueDate":"2025-12-31","assigneeId":"0bc1a168-b166-4be8-88f0-971d33e94d1e"}' \
    "$DEMO_TOKEN"

# Test 17: Valid invoice creation - customer as string (backward compatibility)
run_test "Test 17: Valid invoice creation - customer as string" "201" \
    '{"customer":"String Customer Name","items":[{"desc":"Legacy Support","qty":1,"price":150}],"dueDate":"2025-11-01","assigneeId":"89834327-1c2e-43b6-809c-8156fdb85156"}' \
    "$USER2_TOKEN"

echo ""
echo "📊 Test Results:"
echo "=================="
echo "✅ Passed: $TESTS_PASSED"
echo "❌ Failed: $TESTS_FAILED"
echo "Total: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo "🎉 All tests passed! Invoice creation is working correctly."
    exit 0
else
    echo ""
    echo "💥 Some tests failed. Please review the issues above."
    exit 1
fi