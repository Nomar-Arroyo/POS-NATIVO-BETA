import React from 'react'
import { Factura } from '../../types'

interface InvoiceTemplateProps {
  invoice: Factura
}

const InvoiceTemplate: React.FC<InvoiceTemplateProps> = ({ invoice }) => {
  return (
    <div className="invoice-template p-6 font-mono text-sm bg-white text-black">
      <div className="text-center border-b pb-4 mb-4">
        <h2 className="text-lg font-bold">CAFÉ ANALÍTICA C.A.</h2>
        <p>RIF: J-12345678-9</p>
        <p className="text-xs">FACTURA SIMULADA</p>
      </div>

      <div className="mb-4">
        <p><strong>Número de Factura:</strong> {invoice.number}</p>
        <p><strong>Número de Control:</strong> {invoice.controlNumber}</p>
        <p><strong>Fecha:</strong> {new Date(invoice.createdAt).toLocaleString()}</p>
        <p><strong>Cliente:</strong> {invoice.customerName || 'Consumidor Final'}</p>
        <p><strong>RIF Cliente:</strong> {invoice.customerRif || 'N/A'}</p>
      </div>

      <div className="border-t border-b py-2 mb-4">
        {invoice.items.map((item, index) => (
          <div key={index} className="flex justify-between">
            <span>{item.quantity}x {item.product?.name || 'Product'}</span>
            <span>${(item.quantity * item.unitPrice).toFixed(2)}</span>
          </div>
        ))}
      </div>

      <div className="space-y-1">
        <div className="flex justify-between">
          <span>Subtotal:</span>
          <span>${invoice.subtotal.toFixed(2)}</span>
        </div>
        <div className="flex justify-between">
          <span>IVA (16%):</span>
          <span>${invoice.iva.toFixed(2)}</span>
        </div>
        {invoice.igtf && (
          <div className="flex justify-between">
            <span>IGTF (3%):</span>
            <span>${invoice.igtf.toFixed(2)}</span>
          </div>
        )}
        <div className="flex justify-between font-bold border-t pt-2">
          <span>TOTAL:</span>
          <span>${invoice.total.toFixed(2)}</span>
        </div>
      </div>

      <div className="mt-4 text-center">
        <p className="text-xs">VALIDADO FISCALMENTE</p>
        <p className="text-xs text-red-600">(SIMULACIÓN BETA SENIAT)</p>
      </div>
    </div>
  )
}

export default InvoiceTemplate