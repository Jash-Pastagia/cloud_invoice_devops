import React from 'react'
import { safeRender } from '../utils/renderUtils'

const InvoiceItem = ({ item }) => {
  if (!item) return null

  const qty = parseFloat(item.qty || item.quantity || 1) || 0
  const price = parseFloat(item.price || item.amount || item.unitPrice || 0) || 0
  const desc = safeRender(item.desc || item.description || item.name, 'Item')

  return (
    <tr>
      <td>{desc}</td>
      <td>{qty}</td>
      <td>${price.toFixed(2)}</td>
      <td>${(qty * price).toFixed(2)}</td>
    </tr>
  )
}

export default InvoiceItem
