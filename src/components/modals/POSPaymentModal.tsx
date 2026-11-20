import React, { useEffect, useState } from 'react'
import { useStore } from '../../store/store'
import { useCalculation } from '../../hooks/useCalculation'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Select from '../common/Select'
import Button from '../common/Button'
import { Pago } from '../../types'

interface POSPaymentModalProps {
  isOpen: boolean
  onClose: () => void
  totalUSD: number
  totalBs: number
  onSubmit: (
    pagos: Pago[],
    customerRif?: string,
    customerName?: string
  ) => Promise<boolean>
}

const paymentMethods: Array<{ value: Pago['method']; label: string }> = [
  { value: 'EFECTIVO USD', label: 'Efectivo USD' },
  { value: 'EFECTIVO Bs', label: 'Efectivo Bs' },
  { value: 'PUNTO DE VENTA', label: 'Punto de Venta' },
  { value: 'PAGO MÓVIL', label: 'Pago Móvil' },
  { value: 'ZELLE', label: 'Zelle' }
]

const isPaymentMethod = (value: string): value is Pago['method'] =>
  paymentMethods.some(method => method.value === value)

const POSPaymentModal: React.FC<POSPaymentModalProps> = ({
  isOpen,
  onClose,
  totalUSD,
  totalBs,
  onSubmit
}) => {
  const { config } = useStore()
  const { formatCurrency } = useCalculation()
  const [pagos, setPagos] = useState<Pago[]>([])
  const [currentPayment, setCurrentPayment] = useState<Pago>({
    id: '',
    method: 'EFECTIVO USD',
    amount: 0,
    currency: 'USD'
  })
  const [customerRif, setCustomerRif] = useState('')
  const [customerName, setCustomerName] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  useEffect(() => {
    if (!isOpen) {
      setPagos([])
      setCurrentPayment({
        id: '',
        method: 'EFECTIVO USD',
        amount: 0,
        currency: 'USD'
      })
      setCustomerRif('')
      setCustomerName('')
    }
  }, [isOpen])

  const totalPaidUSD = pagos
    .filter(payment => payment.currency === 'USD')
    .reduce((sum, payment) => sum + payment.amount, 0)
  const totalPaidBs = pagos
    .filter(payment => payment.currency === 'Bs')
    .reduce((sum, payment) => sum + payment.amount, 0)
  const paidInUSD = totalPaidUSD + totalPaidBs / config.exchangeRate
  const remainingUSD = Math.max(0, totalUSD - paidInUSD)
  const isPaymentComplete = Math.abs(paidInUSD - totalUSD) < 0.01

  const handleAddPayment = () => {
    if (!Number.isFinite(currentPayment.amount) || currentPayment.amount <= 0) {
      alert('La cantidad debe ser mayor a 0')
      return
    }

    setPagos(previous => [
      ...previous,
      {
        ...currentPayment,
        id: `pago-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
      }
    ])
    setCurrentPayment(previous => ({ ...previous, amount: 0 }))
  }

  const handleRemovePayment = (id: string) => {
    setPagos(previous => previous.filter(payment => payment.id !== id))
  }

  const handlePaymentMethodChange = (method: string) => {
    if (!isPaymentMethod(method)) {
      alert('Método de pago no válido')
      return
    }

    setCurrentPayment(previous => ({
      ...previous,
      method,
      currency: method === 'EFECTIVO Bs' ? 'Bs' : 'USD',
      amount: 0
    }))
  }

  const handleSubmit = async () => {
    if (!isPaymentComplete || isSubmitting) {
      alert('El pago no cubre exactamente el total de la venta')
      return
    }

    setIsSubmitting(true)
    try {
      const success = await onSubmit(
        pagos,
        customerRif.trim() || undefined,
        customerName.trim() || undefined
      )
      if (success) onClose()
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Procesar Pago"
      size="lg"
    >
      <div className="space-y-6">
        <div className="grid grid-cols-2 gap-4 p-4 bg-gray-700 rounded-lg">
          <div>
            <p className="text-sm text-gray-400">Total a Pagar (USD)</p>
            <p className="text-2xl font-bold text-amalfi-turquoise">
              {formatCurrency(totalUSD, 'USD')}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-400">Total a Pagar (Bs)</p>
            <p className="text-2xl font-bold text-amalfi-turquoise">
              {formatCurrency(totalBs, 'Bs')}
            </p>
          </div>
        </div>

        <div className="p-4 bg-gray-700 rounded-lg">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-gray-400">Pagado (USD)</p>
              <p className="text-lg font-semibold text-green-400">
                {formatCurrency(totalPaidUSD, 'USD')}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-400">Pagado (Bs)</p>
              <p className="text-lg font-semibold text-green-400">
                {formatCurrency(totalPaidBs, 'Bs')}
              </p>
            </div>
          </div>

          {remainingUSD > 0.01 && (
            <div className="mt-2 p-2 bg-yellow-900 bg-opacity-20 rounded border border-yellow-700">
              <p className="text-sm text-yellow-300">
                Saldo pendiente: {formatCurrency(remainingUSD, 'USD')}
              </p>
            </div>
          )}
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Input
            label="RIF / Cédula"
            value={customerRif}
            onChange={event => setCustomerRif(event.target.value)}
            disabled={isSubmitting}
            placeholder="Ej: J-12345678-9"
          />
          <Input
            label="Nombre del Cliente"
            value={customerName}
            onChange={event => setCustomerName(event.target.value)}
            disabled={isSubmitting}
            placeholder="Nombre o razón social"
          />
        </div>

        <div className="space-y-4">
          <h3 className="text-lg font-medium text-white">Registrar Pago</h3>
          <div className="grid grid-cols-2 gap-4">
            <Select
              label="Método de Pago"
              options={paymentMethods}
              value={currentPayment.method}
              onChange={event => handlePaymentMethodChange(event.target.value)}
              disabled={isSubmitting}
            />
            <Input
              label="Monto"
              type="number"
              step="0.01"
              min="0"
              value={currentPayment.amount}
              onChange={event => setCurrentPayment(previous => ({
                ...previous,
                amount: Number.parseFloat(event.target.value) || 0
              }))}
              disabled={isSubmitting}
            />
          </div>

          <Button
            type="button"
            onClick={handleAddPayment}
            variant="primary"
            className="w-full"
            disabled={isSubmitting}
          >
            Agregar Pago
          </Button>
        </div>

        {pagos.length > 0 && (
          <div className="space-y-2">
            <h4 className="font-medium text-white">Pagos Registrados</h4>
            {pagos.map(payment => (
              <div
                key={payment.id}
                className="flex items-center justify-between p-3 bg-gray-700 rounded"
              >
                <div>
                  <span className="font-medium">{payment.method}</span>
                  <span className="ml-2">
                    {payment.currency === 'USD' ? '$' : 'Bs.'} {payment.amount.toFixed(2)}
                  </span>
                </div>
                <Button
                  type="button"
                  variant="danger"
                  size="sm"
                  onClick={() => handleRemovePayment(payment.id)}
                  disabled={isSubmitting}
                  aria-label={`Eliminar pago ${payment.method}`}
                >
                  ×
                </Button>
              </div>
            ))}
          </div>
        )}

        <div className="flex justify-end space-x-3 pt-4 border-t border-gray-700">
          <Button
            type="button"
            variant="secondary"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Cancelar
          </Button>
          <Button
            type="button"
            variant="success"
            onClick={handleSubmit}
            disabled={!isPaymentComplete || pagos.length === 0}
            loading={isSubmitting}
          >
            Confirmar Pago
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default POSPaymentModal
