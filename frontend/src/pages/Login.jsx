import React, { useState } from 'react'
import { useNavigate, Link, useLocation } from 'react-router-dom'
import { api, setAuthToken } from '../api'

const Login = () => {
  const [credentials, setCredentials] = useState({ username: '', password: '' })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const navigate = useNavigate()
  const location = useLocation()

  const from = location.state?.from?.pathname || '/invoices'

  const handleChange = (e) => {
    setCredentials({
      ...credentials,
      [e.target.name]: e.target.value
    })
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      const response = await api.login(credentials)
      const { token } = response.data
      
      if (token) {
        setAuthToken(token)
        navigate(from, { replace: true })
      } else {
        setError('Login failed: No token received')
      }
    } catch (err) {
      console.error('Login error:', err)
      setError(
        err.response?.data?.message || 
        err.response?.data?.error || 
        'Login failed. Please check your credentials.'
      )
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-container">
      <div className="auth-card">
        <h1>Welcome Back</h1>
        <p className="auth-subtitle">Sign in to your Cloud Invoice account</p>
        
        {error && (
          <div className="error-message">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="form-group">
            <label htmlFor="username">Username</label>
            <input
              type="text"
              id="username"
              name="username"
              value={credentials.username}
              onChange={handleChange}
              required
              placeholder="Enter your username"
              autoComplete="username"
              disabled={loading}
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              type="password"
              id="password"
              name="password"
              value={credentials.password}
              onChange={handleChange}
              required
              placeholder="Enter your password"
              autoComplete="current-password"
              disabled={loading}
            />
          </div>

          <button 
            type="submit" 
            className="auth-button"
            disabled={loading}
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <div className="auth-links">
          <p>
            Don't have an account? <Link to="/register">Create one here</Link>
          </p>
        </div>

        <div className="demo-credentials">
          <small>
            <strong>Demo Users:</strong><br />
            Username: <code>demo</code> / Password: <code>demo123</code><br />
            Username: <code>user2</code> / Password: <code>user2123</code>
            <br /><small>(Use seeding script to create these users)</small>
          </small>
        </div>
      </div>
    </div>
  )
}

export default Login