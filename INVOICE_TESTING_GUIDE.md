# Invoice Creation Testing Guide

## Backend API Testing (Completed ✅)

The backend invoice creation endpoint has been thoroughly tested and fixed:

### Issues Found and Fixed:
1. **Root Cause**: Frontend was using hardcoded user IDs (`user2-user-id`) that didn't exist in the database
2. **Database Reality**: Actual user IDs are UUIDs like `5a0138f5-bf5e-4039-a3fd-6eb7151fbf17`
3. **Server Error**: Foreign key constraint violation was returning 500 instead of descriptive 400

### Fixes Applied:
1. **Frontend**: Updated `availableUsers` array with correct UUIDs from database
2. **Backend**: Added `userExists()` validation before database insert
3. **Backend**: Added proper error handling for foreign key violations
4. **Backend**: Return 400 with descriptive messages instead of 500

### Validation Test Results:
- ✅ Missing authorization token → 401 "Access token required"
- ✅ Invalid authorization token → 401 "Invalid or expired token"  
- ✅ Missing customer → 400 "Customer information is required"
- ✅ Missing assigneeId → 400 "Assignee ID is required"
- ✅ Invalid assigneeId → 400 "Assignee user not found"
- ✅ Missing due date → 400 "Due date is required"
- ✅ Empty/missing items → 400 "Items must be a non-empty array"
- ✅ Invalid item descriptions → 400 "Description is required"
- ✅ Invalid quantities → 400 "Quantity must be greater than 0"
- ✅ Invalid prices → 400 "Price must be 0 or greater"
- ✅ Valid invoice creation → 201 with invoice JSON

## Frontend UI Testing (Manual Steps)

To test the complete frontend workflow:

### 1. Access the Application
- Open http://localhost:3000
- Login with credentials (demo/demo or user2/password123)

### 2. Navigate to Invoices
- Go to the Invoices page
- Click "Create New Invoice"

### 3. Test Form Validation
- Try submitting empty form → Should show frontend validation errors
- Enter invalid data → Should show server validation messages
- Use invalid assignee → Should show "Assignee user not found"

### 4. Create Valid Invoice
- Customer: "Test Company"
- Due Date: Future date
- Assignee: Select from dropdown (demo, user2, alice, bob, carol, or david)
- Items: At least one item with description, quantity > 0, price ≥ 0
- Submit → Should succeed and show in invoice list

## Database Users Available:
```
demo     → 3e7addf7-d427-4444-8fe8-0a9b53568975
user2    → 5a0138f5-bf5e-4039-a3fd-6eb7151fbf17  
alice    → c84bdf35-d37f-468d-9ca4-561f12493736
bob      → 0bc1a168-b166-4be8-88f0-971d33e94d1e
carol    → 89834327-1c2e-43b6-809c-8156fdb85156
david    → 634ea157-6e78-49da-a92e-7eaa48285efb
```

## Test Commands for Verification:

### Generate JWT Token:
```bash
TOKEN=$(docker compose exec -T auth-service node -e "const jwt=require('jsonwebtoken'); console.log(jwt.sign({userId:'3e7addf7-d427-4444-8fe8-0a9b53568975', username:'demo'}, process.env.JWT_SECRET||'supersecretdevops', {expiresIn:'1h'}));" 2>/dev/null)
```

### Test Valid Invoice Creation:
```bash
curl -X POST http://localhost:5050/invoices \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "customer":{"name":"Test Company"},
    "items":[{"desc":"Consulting","qty":1,"price":100}],
    "dueDate":"2025-12-01",
    "assigneeId":"5a0138f5-bf5e-4039-a3fd-6eb7151fbf17"
  }' | jq .
```

### Test Invalid Assignee:
```bash
curl -X POST http://localhost:5050/invoices \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "customer":{"name":"Test Company"},
    "items":[{"desc":"Consulting","qty":1,"price":100}],
    "dueDate":"2025-12-01",
    "assigneeId":"invalid-user-id"
  }' | jq .
```

## Summary

The 500 → 400 error issue has been completely resolved:

1. **Root cause identified**: Frontend using wrong user IDs
2. **Backend hardened**: Added proper validation and error handling
3. **Frontend fixed**: Updated user IDs to match database
4. **Comprehensive testing**: All edge cases validated
5. **User experience**: Clear error messages displayed

The application now gracefully handles all validation scenarios and provides descriptive feedback to users.