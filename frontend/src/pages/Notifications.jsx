import React, { useState, useEffect, useRef } from 'react'
import { api } from '../api'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'

// Extend dayjs with relativeTime plugin
dayjs.extend(relativeTime)

const Notifications = () => {
  const [notifications, setNotifications] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const intervalRef = useRef(null)

  useEffect(() => {
    fetchNotifications()
    
    // Set up auto-refresh every 10 seconds
    intervalRef.current = setInterval(() => {
      fetchNotifications(false) // Don't show loading on auto-refresh
    }, 10000)

    // Cleanup interval on unmount
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
      }
    }
  }, [])

  const fetchNotifications = async (showLoading = true) => {
    try {
      if (showLoading) setLoading(true)
      
      const response = await api.getNotifications()
      setNotifications(response.data || [])
      setError('')
    } catch (err) {
      console.error('Error fetching notifications:', err)
      setError('Failed to load notifications')
    } finally {
      if (showLoading) setLoading(false)
    }
  }

  const getEventTypeColor = (eventType) => {
    switch (eventType?.toLowerCase()) {
      case 'invoice.created': return '#007bff'
      case 'invoice.paid': return '#28a745'
      case 'payment.processed': return '#17a2b8'
      case 'payment.initiated': return '#ffc107'
      default: return '#6c757d'
    }
  }

  const getEventTypeIcon = (eventType) => {
    switch (eventType?.toLowerCase()) {
      case 'invoice.created': return '📄'
      case 'invoice.paid': return '✅'
      case 'payment.processed': return '💳'
      case 'payment.initiated': return '⏳'
      default: return '📢'
    }
  }

  const formatEventType = (eventType) => {
    return eventType?.replace(/\./g, ' ').replace(/\b\w/g, l => l.toUpperCase()) || 'Unknown Event'
  }

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        Loading notifications...
      </div>
    )
  }

  return (
    <div>
      <div className="flex-between mb-3">
        <h1>Notifications</h1>
        <div style={{ fontSize: '0.9rem', color: '#666' }}>
          Auto-refreshes every 10 seconds
        </div>
      </div>

      {error && (
        <div className="message error">
          {error}
        </div>
      )}

      {notifications.length === 0 ? (
        <div className="card">
          <div className="card-body text-center">
            <h3>No Notifications</h3>
            <p>No notifications found. Create an invoice or process a payment to see notifications here.</p>
            <button 
              onClick={() => fetchNotifications(true)} 
              className="btn btn-primary"
            >
              Refresh
            </button>
          </div>
        </div>
      ) : (
        <>
          <div className="flex-between mb-2">
            <span style={{ color: '#666' }}>
              {notifications.length} notification{notifications.length !== 1 ? 's' : ''}
            </span>
            <button 
              onClick={() => fetchNotifications(true)} 
              className="btn btn-secondary"
              style={{ fontSize: '0.875rem', padding: '0.5rem 1rem' }}
            >
              Refresh
            </button>
          </div>

          <div className="notifications-list">
            {notifications.map((notification) => (
              <div 
                key={notification.id} 
                className="card mb-2"
                style={{ 
                  borderLeft: `4px solid ${getEventTypeColor(notification.eventType)}`,
                  transition: 'all 0.2s ease'
                }}
              >
                <div className="card-body" style={{ padding: '1rem' }}>
                  <div className="flex-between">
                    <div className="flex" style={{ alignItems: 'center', gap: '1rem' }}>
                      <span style={{ fontSize: '1.5rem' }}>
                        {getEventTypeIcon(notification.eventType)}
                      </span>
                      <div>
                        <h4 style={{ margin: 0, color: getEventTypeColor(notification.eventType) }}>
                          {formatEventType(notification.eventType)}
                        </h4>
                        {notification.invoiceId && (
                          <p style={{ margin: '0.25rem 0', color: '#666', fontSize: '0.9rem' }}>
                            Invoice: {notification.invoiceId.substring(0, 8)}...
                          </p>
                        )}
                        {notification.message && (
                          <p style={{ margin: '0.25rem 0', fontSize: '0.95rem' }}>
                            {notification.message}
                          </p>
                        )}
                      </div>
                    </div>
                    
                    <div style={{ textAlign: 'right', color: '#666', fontSize: '0.875rem' }}>
                      <div>
                        {notification.receivedAt ? 
                          dayjs(notification.receivedAt).format('MMM D, h:mm A') : 
                          'Unknown time'
                        }
                      </div>
                      <div style={{ fontSize: '0.75rem', marginTop: '0.25rem' }}>
                        {notification.receivedAt ? 
                          dayjs(notification.receivedAt).fromNow() : 
                          ''
                        }
                      </div>
                    </div>
                  </div>

                  {/* Additional details */}
                  {(notification.payload || notification.meta) && (
                    <details style={{ marginTop: '1rem' }}>
                      <summary style={{ cursor: 'pointer', color: '#666', fontSize: '0.875rem' }}>
                        Show details
                      </summary>
                      <pre style={{ 
                        background: '#f8f9fa', 
                        padding: '0.5rem', 
                        borderRadius: '4px', 
                        fontSize: '0.75rem',
                        overflow: 'auto',
                        marginTop: '0.5rem',
                        maxHeight: '200px'
                      }}>
                        {JSON.stringify({
                          id: notification.id,
                          eventType: notification.eventType,
                          invoiceId: notification.invoiceId,
                          payload: notification.payload,
                          meta: notification.meta,
                          receivedAt: notification.receivedAt
                        }, null, 2)}
                      </pre>
                    </details>
                  )}
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  )
}

export default Notifications