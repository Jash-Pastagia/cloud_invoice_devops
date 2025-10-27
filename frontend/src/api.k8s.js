import axios from 'axios'
import jwtDecode from 'jwt-decode'

// API Base URLs for Kubernetes Ingress
const API_URLS = {
  auth: '/api/auth',
  invoice: '/api/invoice',
  payment: '/api/payment',
  notification: '/api/notification',
  analytics: '/api/analytics'
}

// Create axios instances for each service
const createApiInstance = (baseURL) => {
  const instance = axios.create({
    baseURL,
    timeout: 10000,
    headers: {
      'Content-Type': 'application/json'
    }
  })

  // Request interceptor to add JWT token
  instance.interceptors.request.use(
    (config) => {
      const token = localStorage.getItem('jwt')
      if (token) {
        config.headers.Authorization = `Bearer ${token}`
      }
      return config
    },
    (error) => Promise.reject(error)
  )

  // Response interceptor to handle 401 errors
  instance.interceptors.response.use(
    (response) => response,
    (error) => {
      if (error.response?.status === 401) {
        localStorage.removeItem('jwt')
        window.location.href = '/login'
      }
      return Promise.reject(error)
    }
  )

  return instance
}

// API instances
export const authApi = createApiInstance(API_URLS.auth)
export const invoiceApi = createApiInstance(API_URLS.invoice)
export const paymentApi = createApiInstance(API_URLS.payment)
export const notificationApi = createApiInstance(API_URLS.notification)
export const analyticsApi = createApiInstance(API_URLS.analytics)

// Auth utilities
export const setAuthToken = (token) => {
  localStorage.setItem('jwt', token)
}

export const removeAuthToken = () => {
  localStorage.removeItem('jwt')
}

export const getAuthToken = () => {
  return localStorage.getItem('jwt')
}

export const decodeToken = () => {
  const token = getAuthToken()
  if (!token) return null
  
  try {
    return jwtDecode(token)
  } catch (error) {
    console.error('Invalid token:', error)
    removeAuthToken()
    return null
  }
}

export const getCurrentUser = () => {
  const decoded = decodeToken()
  return decoded ? { 
    id: decoded.userId,
    username: decoded.username || decoded.user || 'User' 
  } : null
}

// Check if user is authenticated
export const isAuthenticated = () => {
  const token = getAuthToken()
  if (!token) return false
  
  try {
    const decoded = jwtDecode(token)
    return decoded.exp * 1000 > Date.now()
  } catch {
    return false
  }
}

// API functions
export const api = {
  // Auth
  login: (credentials) => authApi.post('/login', credentials),
  register: (userDetails) => authApi.post('/register', userDetails),
  getCurrentUserProfile: () => authApi.get('/me'),
  
  // Invoices
  getInvoices: (filter = 'created') => invoiceApi.get(`/invoices?filter=${filter}`),
  createInvoice: (invoice) => invoiceApi.post('/invoices', invoice),
  getInvoice: (id) => invoiceApi.get(`/invoices/${id}`),
  
  // Payments
  createPayment: (payment) => paymentApi.post('/payments', payment),
  
  // Notifications
  getNotifications: () => notificationApi.get('/notifications'),
  
  // Analytics
  getMetrics: () => analyticsApi.get('/metrics')
}

export default api
