import React, { useState } from 'react'
import { useStore } from '../../store/store'
import { useCalculation } from '../../hooks/useCalculation'
import Input from '../common/Input'
import Select from '../common/Select'
import Button from '../common/Button'
import { Pago } from '../../types'

interface PaymentFormProps {
  totalUSD: number
  totalBs: number
  onSubmit: (pagos: Pago[]) => void
  onClose: () => void
}

const PaymentForm: React.FC<PaymentFormProps> = ({ 
  totalUSD, 
  totalBs, 
  onSubmit, 
  onClose 
}) => {
  const { config } = useStore()
  const { formatCurrency, validatePaymentComplete } = useCalculation()
  
  const [pagos, setPagos] = useState<Pago[]>([])
  const [currentPayment, setCurrentPayment] = useState<Pago>({
    id: '',
    method: 'EFECTIVO USD',
    amount: 0,
    currency: 'USD'
  })
  const [customerRif, setCustomerRif] = useState('')
  const [customerName, setCustomerName] = useState('')

  const methods = [
    { value: 'EFECTIVO USD', label: 'Efectivo USD' },
    { value: 'EFECTIVO Bs', label: 'Efectivo Bs' },
    { value: 'PUNTO DE VENTA', label: 'Punto de Venta' },
    { value: 'PAGO MÓVIL', label: 'Pago Móvil' },
    { value: 'ZELLE', label: 'Zelle' }
  ]

  const handleAddPayment = () => {
    if (currentPayment.amount <= 0) {
      alert('La cantidad debe ser mayor a 0')
      return
    }

    const newPayment: Pago = {
      ...currentPayment,
      id: `pago-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
    }

    setPagos(prev => [...prev, newPayment])
    setCurrentPayment({
      id: '',
      method: 'EFECTIVO USD',
      amount: 0,
      currency: 'USD'
    })
  }

  const handleRemovePayment = (id: string) => {
    setPagos(prev => prev.filter(p => p.id !== id))
  }

  const validation = validatePaymentComplete(totalUSD, pagos, config.exchangeRate)

  const handleSubmit = () => {
    if (!validation.isValid) {
      alert('El pago no cubre el total de la venta')
      return
    }
    onSubmit(pagos)
  }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-4 p-4 bg-gray-700 rounded-lg">
        <div>
          <p className="text-sm text-gray-400">Total a Pagar (USD)</p>
          <p className="text-xl font-bold text-amalfi-turquoise">{formatCurrency(totalUSD, 'USD')}</p>
        </div>
        <div>
          <p className="text-sm text-gray-400">Total a Pagar (Bs)</p>
          <p className="text-xl font-bold text-amalfi-turquoise">{formatCurrency(totalBs, 'Bs')}</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 p-4 bg-gray-700 rounded-lg">
        <div>
          <p className="text-sm text-gray-400">Pagado (USD)</p>
          <p className="text-lg font-semibold text-green-400">
            {formatCurrency(validation.totalPaidUSD, 'USD')}
          </p>
        </div>
        <div>
          <p className="text-sm text-gray-400">Pagado (Bs)</p>
          <p className="text-lg font-semibold text-green-400">
            {formatCurrency(validation.totalPaidBs, 'Bs')}
          </p>
        </div>
      </div>

      {validation.remainingUSD > 0.01 && (
        <div className="p-3 bg-yellow-900 bg-opacity-20 rounded-lg border border-yellow-700">
          <p className="text-sm text-yellow-300">
            Saldo pendiente: {formatCurrency(validation.remainingUSD, 'USD')}
          </p>
        </div>
      )}

      <div className="grid grid-cols-2 gap-4">
        <Input
          label="RIF / Cédula"
          value={customerRif}
          onChange={(e) => setCustomerRif(e.target.value)}
          placeholder="Ej: J-12345678-9"
        />
        <Input
          label="Nombre del Cliente"
          value={customerName}
          onChange={(e) => setCustomerName(e.target.value)}
          placeholder="Nombre o razón social"
        />
      </div>

      <div className="flex items-center">
        <input
          type="checkbox"
          id="finalConsumer"
          className="rounded bg-gray-700 border-gray-600 text-amalfi-turquoise"
          defaultChecked
        />
        <label htmlFor="finalConsumer" className="ml-2 text-sm text-gray-300">
          Consumidor Final / Sin RIF
        </label>
      </div>

      <div className="space-y-4">
        <h3 className="text-lg font-medium text-white">Registrar Pago</h3>
        
        <div className="grid grid-cols-2 gap-4">
          <Select
            label="Método de Pago"
            options={methods}
            value={currentPayment.method}
            onChange={(e) => {
              const method = e.target.value
              const currency = method === 'EFECTIVO Bs' ? 'Bs' : 'USD'
              setCurrentPayment(prev => ({ 
                ...prev, 
                method: method as any,
                currency,
                amount: 0 
              }))
            }}
          />
          
          <Input
            label="Monto"
            type="number"
            step="0.01"
            min="0"
            value={currentPayment.amount}
            onChange={(e) => setCurrentPayment(prev => ({ 
              ...prev, 
              amount: parseFloat(e.target.value) || 0 
            }))}
          />
        </div>

        <Button onClick={handleAddPayment} variant="primary" className="w-full">
          Agregar Pago
        </Button>
      </div>

      {pagos.length > 0 && (
        <div className="space-y-2">
          <h4 className="font-medium text-white">Pagos Registrados</h4>
          {pagos.map((pago) => (
            <div key={pago.id} className="flex items-center justify-between p-3 bg-gray-700 rounded">
              <div>
                <span className="font-medium">{pago.method}</span>
                <span className="ml-2">
                  {pago.currency === 'USD' ? '$' : 'Bs.'} {pago.amount.toFixed(2)}
                </span>
              </div>
              <Button
                variant="danger"
                size="sm"
                onClick={() => handleRemovePayment(pago.id)}
              >
                ×
              </Button>
            </div>
          ))}
        </div>
      )}

      <div className="flex justify-end space-x-3 pt-4 border-t border-gray-700">
        <Button variant="secondary" onClick={onClose}>
          Cancelar
        </Button>
        <Button 
          variant="success" 
          onClick={handleSubmit}
          disabled={!validation.isValid}
        >
          Confirmar Pago
        </Button>
      </div>
    </div>
  )
}

export default PaymentForm