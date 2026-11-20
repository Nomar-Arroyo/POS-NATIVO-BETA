import React from 'react'
import { Order } from '../../types'

interface OrderTicketProps {
  order: Order
  width?: 58 | 80
}

const OrderTicket: React.FC<OrderTicketProps> = ({ order, width = 58 }) => {
  const ticketStyle = {
    width: width === 58 ? '58mm' : '80mm',
    fontFamily: 'monospace',
    fontSize: width === 58 ? '11px' : '12px',
    lineHeight: '1.3'
  }

  return (
    <div style={ticketStyle} className="p-2 bg-white text-black">
      {/* Header */}
      <div className="text-center border-b pb-2 mb-2">
        <h2 className="text-sm font-bold">CAFÉ ANALÍTICA C.A.</h2>
        <p className="text-xs">COMANDA {order.station}</p>
      </div>

      {/* Información de la comanda */}
      <div className="mb-2 text-xs">
        <div className="flex justify-between">
          <span>Comanda:</span>
          <span className="font-bold">{order.orderNumber}</span>
        </div>
        <div className="flex justify-between">
          <span>Mesa:</span>
          <span>{order.tableId}</span>
        </div>
        <div className="flex justify-between">
          <span>Fecha:</span>
          <span>{new Date(order.createdAt).toLocaleString()}</span>
        </div>
        {order.notes && (
          <div className="mt-1">
            <span>Notas: {order.notes}</span>
          </div>
        )}
      </div>

      {/* Artículos */}
      <div className="border-t border-b py-2 mb-2">
        {order.items.map((item, index) => (
          <div key={index} className="flex justify-between">
            <span>{item.quantity}x {item.productName}</span>
            <span>${item.total.toFixed(2)}</span>
          </div>
        ))}
      </div>

      {/* Footer */}
      <div className="text-center text-xs">
        <p>Estado: {order.status}</p>
        <p className="mt-1">¡Gracias por su preferencia!</p>
      </div>
    </div>
  )
}

export default OrderTicket