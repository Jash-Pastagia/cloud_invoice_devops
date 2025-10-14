import React, { useState, useEffect } from 'react'
import { api } from '../api'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'

// Extend dayjs with relativeTime plugin
dayjs.extend(relativeTime)

const Analytics = () => {
  const [metrics, setMetrics] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    fetchMetrics()
  }, [])

  const fetchMetrics = async () => {
    try {
      setLoading(true)
      const response = await api.getMetrics()
      setMetrics(response.data)
      setError('')
    } catch (err) {
      console.error('Error fetching metrics:', err)
      setError('Failed to load analytics metrics')
    } finally {
      setLoading(false)
    }
  }

  const createTextChart = (data, maxWidth = 20) => {
    if (!data || Object.keys(data).length === 0) {
      return 'No data available'
    }

    const maxValue = Math.max(...Object.values(data))
    if (maxValue === 0) return 'No events recorded'

    return Object.entries(data)
      .sort(([,a], [,b]) => b - a)
      .map(([key, value]) => {
        const barWidth = Math.max(1, Math.round((value / maxValue) * maxWidth))
        const bar = '█'.repeat(barWidth)
        const percentage = ((value / maxValue) * 100).toFixed(0)
        return `${key.padEnd(20)} ${bar} ${value} (${percentage}%)`
      })
      .join('\n')
  }

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        Loading analytics...
      </div>
    )
  }

  if (error) {
    return (
      <div>
        <h1>Analytics</h1>
        <div className="message error">
          {error}
        </div>
        <button onClick={fetchMetrics} className="btn btn-primary">
          Retry
        </button>
      </div>
    )
  }

  return (
    <div>
      <div className="flex-between mb-3">
        <h1>Analytics Dashboard</h1>
        <button 
          onClick={fetchMetrics} 
          className="btn btn-secondary"
        >
          Refresh
        </button>
      </div>

      {metrics ? (
        <>
          {/* Summary Metrics */}
          <div className="grid-3 mb-3">
            <div className="card">
              <div className="card-header">
                Invoices Created (24h)
              </div>
              <div className="card-body text-center">
                <div style={{ fontSize: '3rem', fontWeight: 'bold', color: '#007bff' }}>
                  {metrics.invoices_created_last_24h || 0}
                </div>
              </div>
            </div>

            <div className="card">
              <div className="card-header">
                Invoices Paid (24h)
              </div>
              <div className="card-body text-center">
                <div style={{ fontSize: '3rem', fontWeight: 'bold', color: '#28a745' }}>
                  {metrics.invoices_paid_last_24h || 0}
                </div>
              </div>
            </div>

            <div className="card">
              <div className="card-header">
                Payments Processed (24h)
              </div>
              <div className="card-body text-center">
                <div style={{ fontSize: '3rem', fontWeight: 'bold', color: '#17a2b8' }}>
                  {metrics.payments_processed_last_24h || 0}
                </div>
              </div>
            </div>
          </div>

          {/* Event Activity Chart */}
          <div className="card mb-3">
            <div className="card-header">
              Events by Type (Last Hour)
            </div>
            <div className="card-body">
              {metrics.events_last_1h_by_type && Object.keys(metrics.events_last_1h_by_type).length > 0 ? (
                <pre style={{ 
                  fontFamily: 'monospace', 
                  fontSize: '0.9rem',
                  lineHeight: '1.4',
                  margin: 0,
                  background: '#f8f9fa',
                  padding: '1rem',
                  borderRadius: '4px',
                  overflow: 'auto'
                }}>
                  {createTextChart(metrics.events_last_1h_by_type)}
                </pre>
              ) : (
                <div className="text-center" style={{ color: '#666', padding: '2rem' }}>
                  No events recorded in the last hour
                </div>
              )}
            </div>
          </div>

          {/* Activity Status */}
          <div className="grid-2">
            <div className="card">
              <div className="card-header">
                Last Event Time
              </div>
              <div className="card-body">
                {metrics.last_event_time ? (
                  <>
                    <div style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>
                      {dayjs(metrics.last_event_time).format('MMMM D, YYYY [at] h:mm:ss A')}
                    </div>
                    <div style={{ color: '#666', fontSize: '0.9rem' }}>
                      {dayjs(metrics.last_event_time).fromNow()}
                    </div>
                  </>
                ) : (
                  <div style={{ color: '#666' }}>No events recorded yet</div>
                )}
              </div>
            </div>

            <div className="card">
              <div className="card-header">
                System Health
              </div>
              <div className="card-body">
                <div className="flex" style={{ alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
                  <span style={{ 
                    width: '12px', 
                    height: '12px', 
                    borderRadius: '50%', 
                    background: '#28a745' 
                  }}></span>
                  <span>Analytics Service: Online</span>
                </div>
                <div className="flex" style={{ alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
                  <span style={{ 
                    width: '12px', 
                    height: '12px', 
                    borderRadius: '50%', 
                    background: metrics.last_event_time ? '#28a745' : '#ffc107' 
                  }}></span>
                  <span>Event Pipeline: {metrics.last_event_time ? 'Active' : 'Idle'}</span>
                </div>
                <div style={{ fontSize: '0.875rem', color: '#666', marginTop: '1rem' }}>
                  Last updated: {dayjs().format('h:mm:ss A')}
                </div>
              </div>
            </div>
          </div>

          {/* Raw Metrics (for debugging) */}
          <details className="mt-3">
            <summary style={{ cursor: 'pointer', color: '#666' }}>
              Show raw metrics data (debug)
            </summary>
            <pre style={{ 
              background: '#f8f9fa', 
              padding: '1rem', 
              borderRadius: '4px', 
              fontSize: '0.875rem',
              overflow: 'auto',
              marginTop: '0.5rem'
            }}>
              {JSON.stringify(metrics, null, 2)}
            </pre>
          </details>
        </>
      ) : (
        <div className="card">
          <div className="card-body text-center">
            <h3>No Metrics Available</h3>
            <p>Analytics service is not returning data.</p>
          </div>
        </div>
      )}
    </div>
  )
}

export default Analytics