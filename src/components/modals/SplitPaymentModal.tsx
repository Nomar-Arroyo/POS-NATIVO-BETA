import React, { useEffect, useState } from 'react'
import { useStore } from '../../store/store'
import type { Pago } from '../../types'
import type { Split, SplitPayment } from '../../types/splitBill'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Select from '../common/Select'
import Button from '../common/Button'

interface SplitPaymentModalProps {
  isOpen: boolean
  split: Split | null
  onClose: () => void
  onSubmit: (
    payment: Omit<SplitPayment, 'id' | 'timestamp'>
  ) => Promise<boolean>
}

const paymentMethods: Array<{ value: Pago['method']; label: string }> = [
  { value: 'EFECTIVO USD', label: 'Efectivo USD' },
  { value: 'EFECTIVO Bs', label: 'Efectivo Bs' },
  { value: 'PUNTO DE VENTA', label: 'Punto de Venta' },
  { value: 'PAGO MÓVIL', label: 'Pago Móvil' },
  { value: 'ZELLE', label: 'Zelle' }
]

const SplitPaymentModal: React.FC<SplitPaymentModalProps> = ({
  isOpen,
  split,
  onClose,
  onSubmit
}) => {
  const { config } = useStore()
  const [method, setMethod] = useState<Pago['method']>('EFECTIVO USD')
  const [amount, setAmount] = useState(0)
  const [reference, setReference] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  const paidUSD = split?.payments.reduce((sum, payment) => {
    const paymentUSD = payment.currency === 'USD'
      ? payment.amount
      : payment.amount / (payment.exchangeRate || config.exchangeRate)
    return sum + paymentUSD
  }, 0) || 0
  const remainingUSD = Math.max(
    0,
    Math.round(((split?.subtotalUSD || 0) - paidUSD) * 100) / 100
  )
  const currency: SplitPayment['currency'] =
    method === 'EFECTIVO Bs' ? 'Bs' : 'USD'
  const remainingInCurrency = currency === 'USD'
    ? remainingUSD
    : Math.round(remainingUSD * config.exchangeRate * 100) / 100

  useEffect(() => {
    if (isOpen) {
      setMethod('EFECTIVO USD')
      setAmount(remainingUSD)
      setReference('')
    }
  }, [isOpen, remainingUSD, split?.id])

  const handleMethodChange = (value: string) => {
    const selectedMethod = paymentMethods.find(option => option.value === value)
    if (!selectedMethod) return

    setMethod(selectedMethod.value)
    const nextCurrency = selectedMethod.value === 'EFECTIVO Bs' ? 'Bs' : 'USD'
    setAmount(nextCurrency === 'USD'
      ? remainingUSD
      : Math.round(remainingUSD * config.exchangeRate * 100) / 100
    )
  }

  const handleSubmit = async () => {
    if (!split || !Number.isFinite(amount) || amount <= 0 || isSubmitting) return

    setIsSubmitting(true)
    try {
      const success = await onSubmit({
        method,
        amount,
        currency,
        reference: reference.trim() || undefined
      })
      if (success) onClose()
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={split ? `Pago de ${split.name}` : 'Pago de cuenta'}
      size="md"
    >
      {split && (
        <div className="space-y-5">
          <div className="rounded-lg bg-gray-700 p-4">
            <p className="text-sm text-gray-400">Saldo pendiente</p>
            <p className="text-xl font-bold text-amalfi-turquoise">
              ${remainingUSD.toFixed(2)}
            </p>
            <p className="text-sm text-gray-400">
              Bs. {(remainingUSD * config.exchangeRate).toFixed(2)}
            </p>
          </div>

          <Select
            label="Método de pago"
            options={paymentMethods}
            value={method}
            onChange={event => handleMethodChange(event.target.value)}
            disabled={isSubmitting}
          />
          <Input
            label={`Monto (${currency})`}
            type="number"
            min="0.01"
            step="0.01"
            max={remainingInCurrency}
            value={amount}
            onChange={event => setAmount(Number.parseFloat(event.target.value) || 0)}
            disabled={isSubmitting}
          />
          <Input
            label="Referencia (opcional)"
            value={reference}
            onChange={event => setReference(event.target.value)}
            disabled={isSubmitting}
          />

          <div className="flex justify-end gap-3 border-t border-gray-700 pt-4">
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
              disabled={
                isSubmitting ||
                amount <= 0 ||
                amount > remainingInCurrency
              }
              loading={isSubmitting}
            >
              Registrar pago
            </Button>
          </div>
        </div>
      )}
    </Modal>
  )
}

export default SplitPaymentModal
