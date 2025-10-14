import React, { useState, useEffect } from 'react'
import { useParams, Link } from 'react-router-dom'
import { api, getCurrentUser } from '../api'
import dayjs from '../utils/dayjsSetup'
import { safeRenderCustomer, safeRender } from '../utils/renderUtils'
import InvoiceItem from '../components/InvoiceItem'

const InvoiceDetail = () => {
  const { id } = useParams()
  const [invoice, setInvoice] = useState(null)
  const [loading, setLoading] = useState(true)
  const [paying, setPaying] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')

  const currentUser = getCurrentUser()

  useEffect(() => {
    fetchInvoice()
  }, [id])

  const fetchInvoice = async () => {
    try {
      setLoading(true)
      const response = await api.getInvoice(id)
      setInvoice(response.data)
      setError('')
    } catch (err) {
      console.error('Error fetching invoice:', err)
      if (err.response?.status === 403) {
        setError('You do not have permission to view this invoice')
      } else {
        setError('Failed to load invoice details')
      }
    } finally {
      setLoading(false)
    }
  }

  const calculateInvoiceTotal = (invoice) => {
    // Use total_amount from database if available
    if (invoice && typeof invoice.total_amount === 'number') {
      return invoice.total_amount
    }
    
    // Fallback to totalAmount field
    if (invoice && typeof invoice.totalAmount === 'number') {
      return invoice.totalAmount
    }
    
    // Calculate from items
    if (!invoice || !invoice.items || !Array.isArray(invoice.items)) return 0
    return invoice.items.reduce((total, item) => {
      const qty = parseFloat(item.qty) || 0
      const price = parseFloat(item.price) || 0
      return total + (qty * price)
    }, 0)
  }

  const handlePayInvoice = async () => {
    if (!invoice) return

    setPaying(true)
    setError('')
    setMessage('')

    try {
      const totalAmount = calculateInvoiceTotal(invoice)
      const paymentData = {
        invoiceId: invoice.id,
        amount: totalAmount
      }

      const response = await api.createPayment(paymentData)
      
      setMessage(`Payment processed successfully! Amount: $${totalAmount.toFixed(2)}`)
      
      // Refresh the invoice to get updated status
      await fetchInvoice()
      
      // Clear message after 5 seconds
      setTimeout(() => setMessage(''), 5000)
      
    } catch (err) {
      console.error('Error processing payment:', err)
      setError(
        err.response?.data?.message || 
        err.response?.data?.error || 
        'Payment processing failed'
      )
    } finally {
      setPaying(false)
    }
  }

  const getStatusClass = (status) => {
    switch (status?.toLowerCase()) {
      case 'paid': return 'status paid'
      case 'sent': return 'status sent'
      case 'overdue': return 'status overdue'
      case 'pending': return 'status draft'
      default: return 'status draft'
    }
  }

  const canUserPay = () => {
    if (!invoice || !currentUser) return false
    
    // Only the assignee can pay the invoice
    const isAssignee = invoice.assignee_id === currentUser.id
    const isPending = invoice.status?.toLowerCase() === 'pending' || invoice.status?.toLowerCase() !== 'paid'
    
    return isAssignee && isPending
  }

  const getUserRole = () => {
    if (!invoice || !currentUser) return 'viewer'
    
    if (invoice.creator_id === currentUser.id) return 'creator'
    if (invoice.assignee_id === currentUser.id) return 'assignee'
    return 'viewer'
  }

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        Loading invoice details...
      </div>
    )
  }

  if (!invoice) {
    return (
      <div className="card">
        <div className="card-body text-center">
          <h3>Invoice Not Found</h3>
          <p>The requested invoice could not be found.</p>
          <Link to="/invoices" className="btn btn-primary">
            Back to Invoices
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div>
      <div className="flex-between mb-3">
        <h1>Invoice Details</h1>
        <Link to="/invoices" className="btn btn-secondary">
          Back to Invoices
        </Link>
      </div>

      {error && (
        <div className="message error">
          {error}
        </div>
      )}

      {message && (
        <div className="message success">
          {message}
        </div>
      )}

      <div className="card">
        <div className="card-header flex-between">
          <span>Invoice #{invoice.id?.substring(0, 8)}...</span>
          <span className={getStatusClass(invoice.status)}>
            {invoice.status || 'unpaid'}
          </span>
        </div>
        
        <div className="card-body">
          {/* User Role Badge */}
          <div className="mb-3">
            <span className={`badge ${getUserRole() === 'creator' ? 'badge-primary' : getUserRole() === 'assignee' ? 'badge-success' : 'badge-secondary'}`}>
              {getUserRole() === 'creator' ? 'You created this invoice' : 
               getUserRole() === 'assignee' ? 'This invoice is assigned to you' : 
               'You are viewing this invoice'}
            </span>
          </div>

          <div className="grid-2 mb-3">
            <div>
              <h3>Customer Information</h3>
                <p><strong>Name:</strong> {safeRenderCustomer(invoice.customer)}</p>
            </div>
            
            <div>
              <h3>Invoice Information</h3>
              <p>
                <strong>Total Amount:</strong> 
                <span style={{ fontSize: '1.5rem', color: '#28a745', marginLeft: '0.5rem' }}>
                  ${parseFloat(calculateInvoiceTotal(invoice) || 0).toFixed(2)}
                </span>
              </p>
              <p>
                <strong>Created:</strong> {' '}
                {(() => {
                  const created = invoice.created_at || invoice.createdAt || ''
                  return created ? dayjs(safeRender(created, '')).format('MMMM D, YYYY [at] h:mm A') : 'N/A'
                })()}
              </p>
              <p>
                <strong>Due Date:</strong> {' '}
                {(() => {
                  const due = invoice.due_date || invoice.dueDate || ''
                  return due ? dayjs(safeRender(due, '')).format('MMMM D, YYYY') : 'N/A'
                })()}
              </p>
            </div>
          </div>

          {/* Items Section */}
          {Array.isArray(invoice.items) && invoice.items.length > 0 ? (
            <div className="mb-3">
              <h3>Items</h3>
              <table className="table">
                <thead>
                  <tr>
                    <th>Description</th>
                    <th>Quantity</th>
                    <th>Unit Price</th>
                    <th>Total</th>
                  </tr>
                </thead>
                <tbody>
                  {invoice.items.map((item, index) => (
                    <InvoiceItem key={index} item={item} />
                  ))}
                </tbody>
                <tfoot>
                  <tr style={{ borderTop: '2px solid #28a745', fontWeight: 'bold' }}>
                    <td colSpan="3" style={{ textAlign: 'right' }}>Total Amount:</td>
                    <td style={{ color: '#28a745', fontSize: '1.2rem' }}>
                      ${parseFloat(calculateInvoiceTotal(invoice) || 0).toFixed(2)}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          ) : (
            <div className="mb-3">
              <h3>Items</h3>
              <div className="text-muted">No items available</div>
            </div>
          )}

          {/* Payment Status */}
          {invoice.paid_at && (
            <div className="mb-3">
              <div className="alert alert-success">
                <h4>✅ Payment Received</h4>
                <p><strong>Paid on:</strong> {dayjs(invoice.paid_at).format('MMMM D, YYYY [at] h:mm A')}</p>
              </div>
            </div>
          )}

          {/* Payment Section */}
          <div className="payment-section mt-3" style={{ borderTop: '1px solid #e0e0e0', paddingTop: '1rem' }}>
            {canUserPay() ? (
              <div className="text-center">
                <h4 style={{ color: '#28a745', marginBottom: '1rem' }}>
                  You can pay this invoice
                </h4>
                <button 
                  onClick={handlePayInvoice}
                  className="btn btn-success"
                  disabled={paying}
                  style={{ fontSize: '1.2rem', padding: '1rem 2rem' }}
                >
                  {paying ? (
                    <>
                      <span className="spinner" style={{ width: '16px', height: '16px', marginRight: '0.5rem' }}></span>
                      Processing Payment...
                    </>
                  ) : (
                    `💳 Pay $${calculateInvoiceTotal(invoice).toFixed(2)}`
                  )}
                </button>
              </div>
            ) : invoice.status?.toLowerCase() === 'paid' ? (
              <div className="text-center">
                <span className="btn btn-success" style={{ opacity: 0.8, cursor: 'default', fontSize: '1.1rem', padding: '0.75rem 2rem' }}>
                  ✅ Invoice Paid
                </span>
              </div>
            ) : getUserRole() !== 'assignee' ? (
              <div className="text-center">
                <div className="alert alert-info">
                  <h5>Payment Information</h5>
                  <p>
                    {getUserRole() === 'creator' ? 
                      'You created this invoice. Only the assigned user can pay it.' :
                      'You can view this invoice but cannot pay it. Only the assigned user can make payments.'
                    }
                  </p>
                </div>
              </div>
            ) : (
              <div className="text-center">
                <span className="btn btn-secondary" style={{ cursor: 'default', fontSize: '1.1rem', padding: '0.75rem 2rem' }}>
                  Payment Not Available
                </span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Raw Data (for debugging) */}
      <details className="mt-3">
        <summary style={{ cursor: 'pointer', color: '#666' }}>
          Show raw invoice data (debug)
        </summary>
        <pre style={{ 
          background: '#f8f9fa', 
          padding: '1rem', 
          borderRadius: '4px', 
          fontSize: '0.875rem',
          overflow: 'auto',
          marginTop: '0.5rem'
        }}>
          {JSON.stringify(invoice, null, 2)}
        </pre>
      </details>
    </div>
  )
}

export default InvoiceDetail