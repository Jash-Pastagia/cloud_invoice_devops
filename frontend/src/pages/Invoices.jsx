import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { api, getCurrentUser } from '../api'
import dayjs from '../utils/dayjsSetup'
import { safeRenderCustomer, safeRender } from '../utils/renderUtils'
import InvoiceItem from '../components/InvoiceItem'

const Invoices = () => {
  const [invoices, setInvoices] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [creating, setCreating] = useState(false)
  const [message, setMessage] = useState('')
  const [filter, setFilter] = useState('created') // 'created', 'assigned', 'all'
  const [availableUsers, setAvailableUsers] = useState([])

  // Create form state with multiple items support
  const [newInvoice, setNewInvoice] = useState({
    customer: '',
    dueDate: '',
    assigneeId: '',
    items: [{ desc: '', qty: 1, price: 0 }]
  })

  const currentUser = getCurrentUser()

  useEffect(() => {
    fetchInvoices()
    // In a real app, you'd have an endpoint to get all users for the assignee dropdown
    // For now, we'll use hardcoded users that should match the seeded users
    setAvailableUsers([
      { id: 'demo-user-id', username: 'demo', fullName: 'Demo User' },
      { id: 'user2-user-id', username: 'user2', fullName: 'User Two' }
    ])
  }, [filter])

  const fetchInvoices = async () => {
    try {
      setLoading(true)
      const response = await api.getInvoices(filter)
      setInvoices(response.data || [])
      setError('')
    } catch (err) {
      console.error('Error fetching invoices:', err)
      setError('Failed to load invoices')
    } finally {
      setLoading(false)
    }
  }

  const handleCreateChange = (e) => {
    const { name, value } = e.target
    setNewInvoice(prev => ({
      ...prev,
      [name]: value
    }))
  }

  const handleItemChange = (index, field, value) => {
    setNewInvoice(prev => ({
      ...prev,
      items: prev.items.map((item, i) => 
        i === index ? { ...item, [field]: value } : item
      )
    }))
  }

  const addItem = () => {
    setNewInvoice(prev => ({
      ...prev,
      items: [...prev.items, { desc: '', qty: 1, price: 0 }]
    }))
  }

  const removeItem = (index) => {
    if (newInvoice.items.length > 1) {
      setNewInvoice(prev => ({
        ...prev,
        items: prev.items.filter((_, i) => i !== index)
      }))
    }
  }

  const calculateTotal = () => {
    return newInvoice.items.reduce((total, item) => {
      return total + (parseFloat(item.qty) || 0) * (parseFloat(item.price) || 0)
    }, 0)
  }

  const handleCreateSubmit = async (e) => {
    e.preventDefault()
    setCreating(true)
    setError('')
    setMessage('')

    try {
      // Validate form
      if (!newInvoice.customer.trim()) {
        setError('Customer name is required')
        setCreating(false)
        return
      }

      if (!newInvoice.assigneeId) {
        setError('Please select an assignee')
        setCreating(false)
        return
      }

      if (!newInvoice.dueDate) {
        setError('Due date is required')
        setCreating(false)
        return
      }

      // Validate items
      const validItems = newInvoice.items.filter(item => 
        item.desc.trim() && parseFloat(item.qty) > 0 && parseFloat(item.price) >= 0
      )

      if (validItems.length === 0) {
        setError('At least one valid item is required')
        setCreating(false)
        return
      }

      const invoiceData = {
        customer: { name: newInvoice.customer.trim() },
        items: validItems.map(item => ({
          desc: item.desc.trim(),
          qty: parseFloat(item.qty),
          price: parseFloat(item.price)
        })),
        dueDate: newInvoice.dueDate,
        assigneeId: newInvoice.assigneeId
      }

      const response = await api.createInvoice(invoiceData)
      
      setMessage('Invoice created successfully!')
      setShowCreateForm(false)
      setNewInvoice({
        customer: '',
        dueDate: '',
        assigneeId: '',
        items: [{ desc: '', qty: 1, price: 0 }]
      })
      
      // Refresh the list
      await fetchInvoices()
      
      // Clear message after 3 seconds
      setTimeout(() => setMessage(''), 3000)
      
    } catch (err) {
      console.error('Error creating invoice:', err)
      setError(err.response?.data?.message || 'Failed to create invoice')
    } finally {
      setCreating(false)
    }
  }

  const getStatusClass = (status) => {
    switch (status?.toLowerCase()) {
      case 'paid': return 'status paid'
      case 'sent': return 'status sent'
      case 'overdue': return 'status overdue'
      default: return 'status draft'
    }
  }

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        Loading invoices...
      </div>
    )
  }

  return (
    <div>
      <div className="flex-between mb-3">
        <h1>Invoices</h1>
        <button 
          className="btn btn-primary"
          onClick={() => setShowCreateForm(!showCreateForm)}
        >
          {showCreateForm ? 'Cancel' : 'Create Invoice'}
        </button>
      </div>

      {/* Filter Tabs */}
      <div className="card mb-3">
        <div className="card-body" style={{ padding: '1rem' }}>
          <div className="flex" style={{ gap: '1rem', alignItems: 'center' }}>
            <span style={{ fontWeight: 'bold', color: '#666' }}>View:</span>
            <button 
              className={`btn ${filter === 'created' ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setFilter('created')}
              style={{ fontSize: '0.875rem', padding: '0.5rem 1rem' }}
            >
              Created by Me
            </button>
            <button 
              className={`btn ${filter === 'assigned' ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setFilter('assigned')}
              style={{ fontSize: '0.875rem', padding: '0.5rem 1rem' }}
            >
              Assigned to Me
            </button>
            <button 
              className={`btn ${filter === 'all' ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setFilter('all')}
              style={{ fontSize: '0.875rem', padding: '0.5rem 1rem' }}
            >
              All My Invoices
            </button>
          </div>
        </div>
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

      {/* Create Invoice Form */}
      {showCreateForm && (
        <div className="card mb-3">
          <div className="card-header">
            Create New Invoice
          </div>
          <div className="card-body">
            <form onSubmit={handleCreateSubmit}>
              <div className="grid-3">
                <div className="form-group">
                  <label htmlFor="customer">Customer Name *</label>
                  <input
                    type="text"
                    id="customer"
                    name="customer"
                    className="form-control"
                    value={newInvoice.customer}
                    onChange={handleCreateChange}
                    required
                    placeholder="Enter customer name"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="dueDate">Due Date *</label>
                  <input
                    type="date"
                    id="dueDate"
                    name="dueDate"
                    className="form-control"
                    value={newInvoice.dueDate}
                    onChange={handleCreateChange}
                    required
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="assigneeId">Assign To *</label>
                  <select
                    id="assigneeId"
                    name="assigneeId"
                    className="form-control"
                    value={newInvoice.assigneeId}
                    onChange={handleCreateChange}
                    required
                  >
                    <option value="">Select user to assign invoice</option>
                    {availableUsers.map(user => (
                      <option key={user.id} value={user.id}>
                        {user.fullName} (@{user.username})
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <h4 style={{ marginTop: '1.5rem', marginBottom: '1rem', color: '#333', display: 'flex', alignItems: 'center', gap: '1rem' }}>
                Items
                <button 
                  type="button" 
                  onClick={addItem}
                  className="btn btn-primary"
                  style={{ fontSize: '0.875rem', padding: '0.5rem 1rem' }}
                >
                  Add Item
                </button>
              </h4>
              
              {newInvoice.items.map((item, index) => (
                <div key={index} className="card mb-2" style={{ background: '#f8f9fa', border: '1px solid #e9ecef' }}>
                  <div className="card-body" style={{ padding: '1rem' }}>
                    <div className="flex-between mb-2">
                      <h5 style={{ margin: 0, color: '#495057' }}>Item {index + 1}</h5>
                      {newInvoice.items.length > 1 && (
                        <button 
                          type="button" 
                          onClick={() => removeItem(index)}
                          className="btn btn-danger"
                          style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                        >
                          Remove
                        </button>
                      )}
                    </div>
                    
                    <div className="grid-3">
                      <div className="form-group">
                        <label>Description *</label>
                        <input
                          type="text"
                          className="form-control"
                          value={item.desc}
                          onChange={(e) => handleItemChange(index, 'desc', e.target.value)}
                          required
                          placeholder="e.g. Web Development"
                        />
                      </div>

                      <div className="form-group">
                        <label>Quantity *</label>
                        <input
                          type="number"
                          className="form-control"
                          value={item.qty}
                          onChange={(e) => handleItemChange(index, 'qty', e.target.value)}
                          required
                          min="1"
                          step="1"
                        />
                      </div>

                      <div className="form-group">
                        <label>Price ($) *</label>
                        <input
                          type="number"
                          className="form-control"
                          value={item.price}
                          onChange={(e) => handleItemChange(index, 'price', e.target.value)}
                          required
                          min="0"
                          step="0.01"
                        />
                      </div>
                    </div>
                    
                    <div style={{ textAlign: 'right', color: '#666', fontSize: '0.875rem', marginTop: '0.5rem' }}>
                      Subtotal: ${((parseFloat(item.qty) || 0) * (parseFloat(item.price) || 0)).toFixed(2)}
                    </div>
                  </div>
                </div>
              ))}

              {/* Total Amount Display */}
              <div className="form-group" style={{ background: '#e8f5e8', padding: '1rem', borderRadius: '4px', border: '2px solid #28a745' }}>
                <h3 style={{ margin: 0, color: '#28a745', textAlign: 'center' }}>
                  Total Amount: ${calculateTotal().toFixed(2)}
                </h3>
              </div>

              <div className="flex" style={{ gap: '1rem', marginTop: '1.5rem' }}>
                <button 
                  type="submit" 
                  className="btn btn-success"
                  disabled={creating}
                >
                  {creating ? 'Creating...' : 'Create Invoice'}
                </button>
                <button 
                  type="button" 
                  className="btn btn-secondary"
                  onClick={() => setShowCreateForm(false)}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Invoices List */}
      {invoices.length === 0 ? (
        <div className="card">
          <div className="card-body text-center">
            <p>No invoices found. Create your first invoice!</p>
          </div>
        </div>
      ) : (
        <div className="card">
          <table className="table">
            <thead>
              <tr>
                <th>Invoice ID</th>
                <th>Customer</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Created</th>
                <th>Due Date</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {invoices.map((invoice) => {
                // Defensive checks: ensure invoice is an object and has an id
                if (!invoice || typeof invoice !== 'object') return null
                const invoiceId = invoice.id || invoice._id || Math.random().toString(36).slice(2, 9)

                // Compute total (fallback to total_amount or calculate from items)
                const totalStr = (() => {
                  if (invoice.total_amount) return parseFloat(invoice.total_amount).toFixed(2)
                  if (invoice.totalAmount && typeof invoice.totalAmount === 'number') return invoice.totalAmount.toFixed(2)
                  if (Array.isArray(invoice.items)) {
                    const tt = invoice.items.reduce((s, it) => {
                      const pa = parseFloat(it.price || it.amount || it.unitPrice || 0) || 0
                      const qa = parseFloat(it.qty || it.quantity || 1) || 0
                      return s + pa * qa
                    }, 0)
                    return tt.toFixed(2)
                  }
                  return '0.00'
                })()

                return (
                  <tr key={invoiceId}>
                    <td>
                      <Link to={`/invoices/${invoice.id}`} style={{ color: '#007bff', textDecoration: 'none' }}>
                        {String(invoice.id || invoiceId).substring(0, 8)}...
                      </Link>
                    </td>
                    <td>{safeRenderCustomer(invoice.customer)}</td>
                    <td>${totalStr}</td>
                    <td>
                      <span className={getStatusClass(invoice.status)}>
                        {safeRender(invoice.status, 'draft')}
                      </span>
                    </td>
                    <td>{invoice.created_at || invoice.createdAt ? dayjs(safeRender(invoice.created_at || invoice.createdAt, '')).format('MMM D, YYYY') : 'N/A'}</td>
                    <td>{invoice.due_date || invoice.dueDate ? dayjs(safeRender(invoice.due_date || invoice.dueDate, '')).format('MMM D, YYYY') : 'N/A'}</td>
                    <td className="actions">
                      <Link to={`/invoices/${invoice.id}`} className="btn btn-primary" style={{ fontSize: '0.875rem', padding: '0.5rem' }}>
                        View
                      </Link>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default Invoices