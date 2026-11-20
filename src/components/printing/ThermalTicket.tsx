import React from 'react'
import { Precuenta } from '../../types'
import { useExchangeRate } from '../../hooks/useExchangeRate'

interface ThermalTicketProps {
  precuenta: Precuenta
  width?: 58 | 80
  showHeader?: boolean
}

const ThermalTicket: React.FC<ThermalTicketProps> = ({ 
  precuenta, 
  width = 58,
  showHeader = true 
}) => {
  const { formatDual } = useExchangeRate()

  const ticketStyle: React.CSSProperties = {
    width: width === 58 ? '58mm' : '80mm',
    fontFamily: '"Courier New", monospace',
    fontSize: width === 58 ? '12px' : '14px',
    lineHeight: '1.4',
    margin: '0 auto',
    padding: '10px',
    color: '#000',
    background: '#fff',
    minHeight: '100mm',
    border: '1px solid #ddd'
  }

  const formatCurrency = (amount: number) => {
    return `$${amount.toFixed(2)}`
  }

  return (
    <div style={ticketStyle} className="thermal-ticket">
      {/* Header del ticket */}
      {showHeader && (
        <div style={{ textAlign: 'center', marginBottom: '10px', paddingBottom: '10px', borderBottom: '1px dashed #000' }}>
          <h2 style={{ margin: '0 0 5px 0', fontSize: width === 58 ? '16px' : '18px', fontWeight: 'bold' }}>
            CAFÉ ANALÍTICA C.A.
          </h2>
          <p style={{ margin: '0 0 10px 0', fontSize: '10px' }}>
            RIF: J-12345678-9
          </p>
          
          <div style={{ marginBottom: '10px', fontSize: '10px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '3px' }}>
              <span>PRECUENTA:</span>
              <span style={{ fontWeight: 'bold' }}>{precuenta.id}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '3px' }}>
              <span>MESA:</span>
              <span>{precuenta.tableId}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '3px' }}>
              <span>FECHA:</span>
              <span>{new Date(precuenta.generatedAt).toLocaleString('es-ES')}</span>
            </div>
          </div>
        </div>
      )}

      {/* Items del ticket */}
      <div style={{ marginBottom: '10px' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid #000' }}>
              <th style={{ textAlign: 'left', paddingBottom: '5px', fontSize: '10px' }}>Cant</th>
              <th style={{ textAlign: 'left', paddingBottom: '5px', fontSize: '10px' }}>Producto</th>
              <th style={{ textAlign: 'right', paddingBottom: '5px', fontSize: '10px' }}>P.U.</th>
              <th style={{ textAlign: 'right', paddingBottom: '5px', fontSize: '10px' }}>Total</th>
            </tr>
          </thead>
          <tbody>
            {precuenta.items.map((item, index) => (
              <tr key={index}>
                <td style={{ padding: '3px 0', verticalAlign: 'top' }}>{item.quantity}x</td>
                <td style={{ padding: '3px 0', verticalAlign: 'top' }}>
                  {item.product?.name || item.productId}
                </td>
                <td style={{ textAlign: 'right', padding: '3px 0', verticalAlign: 'top' }}>
                  {formatCurrency(item.unitPrice)}
                </td>
                <td style={{ textAlign: 'right', padding: '3px 0', verticalAlign: 'top' }}>
                  {formatCurrency(item.quantity * item.unitPrice)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Totales */}
      <div style={{ borderTop: '1px solid #000', paddingTop: '10px', marginTop: '10px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px' }}>
          <span>Subtotal:</span>
          <span>{formatCurrency(precuenta.subtotalUSD)}</span>
        </div>
        <div style={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          fontWeight: 'bold',
          fontSize: width === 58 ? '14px' : '16px',
          borderTop: '1px solid #000',
          paddingTop: '5px',
          marginTop: '5px'
        }}>
          <span>TOTAL:</span>
          <span>{formatDual(precuenta.totalUSD)}</span>
        </div>
      </div>

      {/* Footer */}
      <div style={{ 
        textAlign: 'center', 
        marginTop: '15px', 
        paddingTop: '10px', 
        borderTop: '1px dashed #000',
        fontSize: '10px'
      }}>
        <div style={{ marginBottom: '5px' }}>PRECUENTA - DOCUMENTO NO FISCAL</div>
        <div style={{ marginBottom: '5px' }}>REVISE SU CUENTA</div>
        <div>¡Gracias por su preferencia!</div>
      </div>
    </div>
  )
}

export default ThermalTicket