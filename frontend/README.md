# Cloud Invoice Frontend

A React 18 + Vite frontend for the Cloud Invoice DevOps project. This SPA provides a complete interface for managing invoices, payments, notifications, and analytics.

## Features

- **Authentication**: JWT-based login with token storage
- **Invoice Management**: Create, view, and pay invoices
- **Payment Processing**: Integrated payment flow
- **Notifications**: Real-time notifications with auto-refresh
- **Analytics**: Dashboard with metrics and event tracking
- **Responsive Design**: Clean, minimal CSS styling

## Tech Stack

- **React 18** - Modern React with hooks
- **Vite** - Fast build tool and dev server
- **React Router** - Client-side routing
- **Axios** - HTTP client with interceptors
- **JWT Decode** - Token parsing
- **Day.js** - Date formatting
- **Nginx** - Production static file serving

## Development

### Prerequisites

- Node.js 18+ (recommended: Node 24 LTS)
- npm or yarn
- Backend services running (see root README)

### Local Development

```bash
# Install dependencies
cd frontend
npm install

# Start development server (http://localhost:5173)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Environment Setup

The frontend connects to backend services on these ports:
- Auth Service: `http://localhost:4000`
- Invoice Service: `http://localhost:5050`
- Payment Service: `http://localhost:6000`
- Notification Service: `http://localhost:7001`
- Analytics Service: `http://localhost:7100`

Make sure all backend services have CORS enabled for `http://localhost:3000` (see Backend CORS Setup below).

## Docker Deployment

### Build and Run with Docker

```bash
# Build frontend image
docker build -t cloud-invoice-frontend -f frontend/Dockerfile .

# Run frontend container
docker run -p 3000:80 cloud-invoice-frontend
```

### Run with Docker Compose

```bash
# Run all services including frontend
docker-compose up -d

# Run only frontend (requires backend services)
docker-compose up -d frontend
```

Frontend will be available at `http://localhost:3000`

## Backend CORS Setup

**IMPORTANT**: Before running the frontend, you must enable CORS in all backend services.

### Install CORS in each service:

```bash
# For each service (auth-service, invoice-service, payment-service, notification-service, analytics-service)
cd auth-service
npm install cors

cd ../invoice-service  
npm install cors

cd ../payment-service
npm install cors

cd ../notification-service
npm install cors

cd ../analytics-service
npm install cors
```

### Add CORS to each service's index.js:

Add these lines to the top of each service's `index.js` file, right after the express imports:

```javascript
const cors = require('cors');
app.use(cors({ origin: 'http://localhost:3000', credentials: true }));
```

**Example for auth-service/index.js:**
```javascript
const express = require('express');
const cors = require('cors');

const app = express();

// Enable CORS for frontend
app.use(cors({ origin: 'http://localhost:3000', credentials: true }));

// ... rest of your service code
```

Repeat this for all 5 backend services, then restart them:

```bash
docker-compose restart auth-service invoice-service payment-service notification-service analytics-service
```

## Verification Instructions

### 1. Start Development Server
```bash
cd frontend
npm ci
npm run dev
```
Open `http://localhost:5173` in your browser.

### 2. Docker Container Test
```bash
docker-compose up -d frontend
```
Open `http://localhost:3000` in your browser.

### 3. Full Flow Testing

1. **Login Test**
   - Go to login page
   - Use demo credentials: `demo` / `demo123`
   - Verify token is saved in localStorage
   - Check that navigation shows user as logged in

2. **Invoice Creation**
   - Navigate to Invoices page
   - Click "Create Invoice"
   - Fill form with customer name, due date, and items
   - Submit and verify invoice appears in list
   - Check that invoice exists in backend database

3. **Payment Processing**
   - Click on an invoice to view details
   - Click "Pay" button
   - Verify payment processes successfully
   - Check that invoice status updates to "paid"

4. **Notifications Check**
   - Navigate to Notifications page
   - Verify notifications appear after invoice creation/payment
   - Check auto-refresh works (updates every 10 seconds)

5. **Analytics Dashboard**
   - Navigate to Analytics page
   - Verify metrics reflect recent invoice/payment activity
   - Check that event counts and charts display correctly

## Project Structure

```
frontend/
├── public/              # Static assets
├── src/
│   ├── components/      # Reusable components
│   │   └── NavBar.jsx
│   ├── pages/           # Page components
│   │   ├── Login.jsx
│   │   ├── Invoices.jsx
│   │   ├── InvoiceDetail.jsx
│   │   ├── Notifications.jsx
│   │   └── Analytics.jsx
│   ├── api.js           # Axios configuration & API calls
│   ├── App.jsx          # Main app component with routing
│   ├── main.jsx         # React entry point
│   └── styles.css       # Global styles
├── Dockerfile           # Multi-stage build for production
├── nginx.conf           # Nginx configuration
├── package.json         # Dependencies and scripts
├── vite.config.js       # Vite configuration
└── README.md           # This file
```

## API Integration

The frontend integrates with 5 backend microservices:

- **Auth API**: Login, JWT token management
- **Invoice API**: CRUD operations for invoices
- **Payment API**: Payment processing
- **Notification API**: Event notifications
- **Analytics API**: Metrics and event data

All APIs use JWT authentication via `Authorization: Bearer <token>` header.

## Styling

Uses minimal CSS with:
- CSS Grid and Flexbox for layouts
- CSS custom properties for theming
- Responsive design for mobile/desktop
- Simple component-based styling
- Status badges and color coding

## Error Handling

- Axios interceptors for automatic token injection
- 401 handling with automatic redirect to login
- User-friendly error messages
- Loading states for all async operations
- Form validation and feedback

## Browser Support

- Modern browsers supporting ES2020+
- Chrome 88+, Firefox 85+, Safari 14+
- Mobile browsers (iOS Safari, Chrome Mobile)

## Troubleshooting

### CORS Issues
- Ensure all backend services have CORS enabled
- Check that services are running on expected ports
- Verify CORS origin matches frontend URL

### Authentication Issues
- Check JWT token in browser localStorage
- Verify auth service is responding correctly
- Clear localStorage and re-login if needed

### Build Issues
- Ensure Node.js 18+ is installed
- Clear `node_modules` and reinstall: `rm -rf node_modules && npm install`
- Check for port conflicts on 5173 (dev) or 3000 (prod)