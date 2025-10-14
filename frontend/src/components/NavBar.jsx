import React from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { getCurrentUser, removeAuthToken } from '../api'

const NavBar = () => {
  const location = useLocation()
  const navigate = useNavigate()
  const currentUser = getCurrentUser()

  const handleLogout = () => {
    removeAuthToken()
    navigate('/login')
  }

  const isActive = (path) => {
    return location.pathname === path || location.pathname.startsWith(path + '/')
  }

  return (
    <nav className="navbar">
      <Link to="/" className="navbar-brand">
        Cloud Invoice
      </Link>

      {currentUser ? (
        <>
          <div className="navbar-nav">
            <Link 
              to="/invoices" 
              className={isActive('/invoices') ? 'active' : ''}
            >
              Invoices
            </Link>
            <Link 
              to="/notifications" 
              className={isActive('/notifications') ? 'active' : ''}
            >
              Notifications
            </Link>
            <Link 
              to="/analytics" 
              className={isActive('/analytics') ? 'active' : ''}
            >
              Analytics
            </Link>
          </div>

          <div className="navbar-user">
            <span>Welcome, {currentUser.username}</span>
            <button onClick={handleLogout} className="logout-btn">
              Logout
            </button>
          </div>
        </>
      ) : (
        <div className="navbar-nav">
          <Link 
            to="/login" 
            className={isActive('/login') ? 'active' : ''}
          >
            Login
          </Link>
        </div>
      )}
    </nav>
  )
}

export default NavBar