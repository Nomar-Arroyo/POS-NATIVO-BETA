import React, { useState } from 'react'
import { useStore } from '../../store/store'
import { useCheckout } from '../../hooks/useCheckout'
import { useCalculation } from '../../hooks/useCalculation'
import { Pago } from '../../types'
import PaymentForm from '../../components/forms/PaymentForm'
import FiscalProgress from '../../components/fiscal/FiscalProgress'
import FacturaSimulada from '../../components/fiscal/FacturaSimulada'
import Button from '../../components/common/Button'
import Card from '../../components/common/Card'
import {
  CreditCardIcon,
  ReceiptRefundIcon
} from '@/components/common/Icon'

const Checkout: React.FC = () => {
  const { 
    selectedTable, 
    tables, 
    config,
    addNotification 
  } = useStore()
  
  const { processPayment, calculatePaymentSummary } = useCheckout()
  const { formatCurrency, calculateTotal } = useCalculation()

  const [showPaymentForm, setShowPaymentForm] = useState(false)
  const [showFiscalProgress, setShowFiscalProgress] = useState(false)
  const [showFactura, setShowFactura] = useState(false)
  const [currentFactura, setCurrentFactura] = useState<any>(null)
  const [pagos, setPagos] = useState<Pago[]>([])

  const table = tables.find(t => t.id === selectedTable)
  const session = table?.currentSession

  if (!session) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-gray-400">No hay una cuenta activa para procesar</p>
      </div>
    )
  }

  const items = session.items.filter(item => !item.cancelled)
  const totalUSD = calculateTotal(items)
  const totalBs = totalUSD * config.exchangeRate

  const handlePaymentSubmit = async (pagosRegistrados: Pago[]) => {
    setPagos(pagosRegistrados)
    setShowPaymentForm(false)
    setShowFiscalProgress(true)
  }

  const handleFiscalComplete = async () => {
    try {
      const result = await processPayment(
        items,
        pagos,
        undefined, // customerRif - se puede agregar después
        undefined, // customerName - se puede agregar después
        selectedTable || undefined
      )

      if (result.success && result.factId) {
        // Obtener la factura generada
        const facturas = useStore.getState().facturas
        const factura = facturas.find(f => f.id === result.factId)
        
        if (factura) {
          setCurrentFactura(factura)
          setShowFactura(true)
        }
      } else {
        addNotification({
          type: 'error',
          message: result.message
        })
      }
    } catch (error) {
      addNotification({
        type: 'error',
        message: 'Error procesando la factura fiscal'
      })
    }
    
    setShowFiscalProgress(false)
  }

  const summary = calculatePaymentSummary(pagos, totalUSD, config.exchangeRate)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Checkout</h2>
          <p className="text-gray-400">Procesar pago y emisión fiscal</p>
        </div>
        
        {table && (
          <div className="text-right">
            <p className="text-sm text-gray-400">Mesa</p>
            <p className="font-medium text-white">{table.name}</p>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Resumen de productos */}
        <Card title="Resumen de Productos">
          <div className="space-y-3">
            {items.map((item, index) => (
              <div key={index} className="flex justify-between items-center p-3 bg-gray-700 rounded-lg">
                <div>
                  <span className="font-medium text-white">
                    {item.quantity}x {item.product?.name || item.productId}
                  </span>
                  {item.notes && (
                    <div className="text-xs text-gray-400">
                      Nota: {item.notes}
                    </div>
                  )}
                </div>
                <span className="font-bold text-amalfi-turquoise">
                  ${formatCurrency(item.quantity * item.unitPrice, 'USD')}
                </span>
              </div>
            ))}
          </div>

          <div className="mt-4 pt-4 border-t border-gray-700 space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-400">Subtotal:</span>
              <span className="text-white">{formatCurrency(totalUSD, 'USD')}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">IVA (16%):</span>
              <span className="text-white">
                {formatCurrency(totalUSD * config.ivaRate, 'USD')}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">IGTF (3%):</span>
              <span className="text-white">
                {formatCurrency(totalUSD * config.igtfRate, 'USD')}
              </span>
            </div>
            <div className="flex justify-between text-lg font-bold border-t border-gray-700 pt-2">
              <span className="text-white">TOTAL:</span>
              <span className="text-amalfi-turquoise">
                {formatCurrency(totalUSD + (totalUSD * config.ivaRate) + (totalUSD * config.igtfRate), 'USD')}
              </span>
            </div>
          </div>
        </Card>

        {/* Payment summary y acciones */}
        <Card title="Estado de Pago">
          <div className="space-y-4">
            {/* Totales de pago */}
            <div className="grid grid-cols-2 gap-4">
              <div className="p-3 bg-gray-700 rounded-lg">
                <p className="text-xs text-gray-400">Pagado USD</p>
                <p className="text-lg font-bold text-green-400">
                  {formatCurrency(summary.paidUSD, 'USD')}
                </p>
              </div>
              <div className="p-3 bg-gray-700 rounded-lg">
                <p className="text-xs text-gray-400">Pagado Bs</p>
                <p className="text-lg font-bold text-green-400">
                  {formatCurrency(summary.paidBs, 'Bs')}
                </p>
              </div>
            </div>

            {/* Saldo pendiente */}
            {summary.remainingUSD > 0.01 && (
              <div className="p-3 bg-yellow-900 bg-opacity-20 rounded-lg border border-yellow-700">
                <p className="text-sm text-yellow-300">
                  Saldo pendiente: {formatCurrency(summary.remainingUSD, 'USD')}
                </p>
              </div>
            )}

            {/* Botones de acción */}
            <div className="space-y-2">
              <Button 
                variant="primary" 
                className="w-full"
                onClick={() => setShowPaymentForm(true)}
                disabled={summary.isComplete}
              >
                <CreditCardIcon className="h-5 w-5 mr-2" />
                {summary.isComplete ? 'Pago Completo' : 'Registrar Pago'}
              </Button>

              {summary.isComplete && (
                <Button 
                  variant="success" 
                  className="w-full"
                  onClick={handleFiscalComplete}
                >
                  <ReceiptRefundIcon className="h-5 w-5 mr-2" />
                  Emitir Factura Fiscal
                </Button>
              )}
            </div>
          </div>
        </Card>
      </div>

      {/* Formulario de pago */}
      {showPaymentForm && (
        <PaymentForm
          totalUSD={totalUSD}
          totalBs={totalBs}
          onSubmit={handlePaymentSubmit}
          onClose={() => setShowPaymentForm(false)}
        />
      )}

      {/* Progreso fiscal */}
      <FiscalProgress
        isVisible={showFiscalProgress}
        onComplete={handleFiscalComplete}
      />

      {/* Factura simulada */}
      {showFactura && currentFactura && (
        <FacturaSimulada
          factura={currentFactura}
          onClose={() => setShowFactura(false)}
        />
      )}
    </div>
  )
}

export default Checkout