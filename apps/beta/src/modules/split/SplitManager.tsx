import React, { useState } from 'react'
import { useSplitBill } from '../../hooks/useSplitBill'
import { useCheckout } from '../../hooks/useCheckout'
import { useStore } from '../../store/store'
import type { Pago } from '../../types'
import type { Split, SplitPayment } from '../../types/splitBill'
import SplitPaymentModal from '../../components/modals/SplitPaymentModal'
import Card from '../../components/common/Card'
import Button from '../../components/common/Button'
import Badge from '../../components/common/Badge'
import {
  CheckCircleIcon,
  CurrencyDollarIcon,
  UsersIcon,
  XMarkIcon
} from '@/components/common/Icon'

interface SplitManagerProps {
  tableId: string
  onClose: () => void
}

const paymentMethodValues = new Set<string>([
  'EFECTIVO USD',
  'EFECTIVO Bs',
  'PUNTO DE VENTA',
  'PAGO MÓVIL',
  'ZELLE'
])

const isPaymentMethod = (method: string): method is Pago['method'] =>
  paymentMethodValues.has(method)

const SplitManager: React.FC<SplitManagerProps> = ({ tableId, onClose }) => {
  const { getSplitByTable, addPayment, cancelSplit } = useSplitBill()
  const { processPayment } = useCheckout()
  const { addNotification } = useStore()
  const [selectedSplit, setSelectedSplit] = useState<Split | null>(null)

  const splitBill = getSplitByTable(tableId)
  const canCancel = splitBill?.status === 'ACTIVE' &&
    splitBill.splits.every(split => split.payments.length === 0)

  const handleCancelSplit = () => {
    if (!splitBill || !window.confirm('¿Desea cancelar la división de esta cuenta?')) {
      return
    }

    const result = cancelSplit(splitBill.id)
    if (result.success) onClose()
  }

  const handlePaymentSubmit = async (
    payment: Omit<SplitPayment, 'id' | 'timestamp'>
  ): Promise<boolean> => {
    if (!splitBill || !selectedSplit) return false

    const result = addPayment(splitBill.id, selectedSplit.id, payment)
    if (!result.success || !result.splitBill) return false

    if (result.splitBill.status === 'COMPLETED') {
      for (const split of result.splitBill.splits) {
        const pagos: Pago[] = []
        for (const splitPayment of split.payments) {
          if (!isPaymentMethod(splitPayment.method)) {
            addNotification({
              type: 'error',
              message: `Método de pago no válido para facturar ${split.name}`
            })
            return true
          }
          pagos.push({
            id: splitPayment.id,
            method: splitPayment.method,
            amount: splitPayment.amount,
            currency: splitPayment.currency,
            reference: splitPayment.reference
          })
        }

        const invoiceResult = await processPayment(
          split.items,
          pagos,
          undefined,
          split.name,
          tableId,
          '1',
          { releaseTable: false }
        )
        if (!invoiceResult.success) return true
      }
    }

    return true
  }

  if (!splitBill) {
    return (
      <div className="space-y-4">
        <p className="text-gray-300">No hay una división activa para esta mesa.</p>
        <Button variant="secondary" onClick={onClose}>Cerrar</Button>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Gestión de División</h2>
          <p className="text-gray-400">
            Mesa {tableId} - {splitBill.splits.length} cuentas
          </p>
        </div>
        <div className="flex gap-2">
          {canCancel && (
            <Button variant="danger" onClick={handleCancelSplit}>
              Cancelar división
            </Button>
          )}
          <Button variant="secondary" onClick={onClose}>
            <XMarkIcon className="mr-2 h-5 w-5" />
            Cerrar
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {splitBill.splits.map(split => (
          <Card key={split.id} title={split.name}>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <UsersIcon className="h-5 w-5 text-gray-400" />
                  <span className="text-gray-400">
                    {split.items.length} artículos
                  </span>
                </div>
                <Badge variant={split.paid ? 'success' : 'warning'} size="sm">
                  {split.paid ? 'Pagada' : 'Pendiente'}
                </Badge>
              </div>

              <div className="space-y-2">
                {split.items.map((item, index) => (
                  <div
                    key={`${item.id}-${index}`}
                    className="flex justify-between text-sm"
                  >
                    <span className="text-gray-300">
                      {item.quantity}x {item.product?.name || item.productId}
                    </span>
                    <span className="text-amalfi-turquoise">
                      ${(item.quantity * item.unitPrice).toFixed(2)}
                    </span>
                  </div>
                ))}
              </div>

              <div className="border-t border-gray-700 pt-3">
                <div className="flex items-center justify-between">
                  <span className="font-medium text-white">Total:</span>
                  <div className="text-right">
                    <div className="font-bold text-amalfi-turquoise">
                      ${split.subtotalUSD.toFixed(2)}
                    </div>
                    <div className="text-sm text-gray-400">
                      Bs. {split.subtotalBs.toFixed(2)}
                    </div>
                  </div>
                </div>
              </div>

              {split.payments.length > 0 && (
                <div className="space-y-2">
                  <h4 className="text-sm font-medium text-gray-300">Pagos:</h4>
                  {split.payments.map(payment => (
                    <div
                      key={payment.id}
                      className="flex justify-between text-sm"
                    >
                      <span className="text-gray-400">{payment.method}</span>
                      <span className="text-green-400">
                        {payment.currency === 'USD' ? '$' : 'Bs.'}{' '}
                        {payment.amount.toFixed(2)}
                      </span>
                    </div>
                  ))}
                </div>
              )}

              {!split.paid && (
                <Button
                  variant="primary"
                  className="w-full"
                  onClick={() => setSelectedSplit(split)}
                >
                  <CurrencyDollarIcon className="mr-2 h-5 w-5" />
                  Pagar Cuenta
                </Button>
              )}

              {split.paid && split.paidAt && (
                <div className="flex items-center space-x-2 text-sm text-green-400">
                  <CheckCircleIcon className="h-5 w-5" />
                  <span>Pagada el {new Date(split.paidAt).toLocaleString()}</span>
                </div>
              )}
            </div>
          </Card>
        ))}

        <Card title="Resumen Total">
          <div className="space-y-4">
            <div className="flex justify-between">
              <span className="text-gray-400">Cuentas:</span>
              <span className="text-white">{splitBill.splits.length}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Pagadas:</span>
              <span className="text-green-400">
                {splitBill.splits.filter(split => split.paid).length}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Pendientes:</span>
              <span className="text-yellow-400">
                {splitBill.splits.filter(split => !split.paid).length}
              </span>
            </div>
            <div className="border-t border-gray-700 pt-3">
              <div className="flex justify-between">
                <span className="font-medium text-white">Total División:</span>
                <div className="text-right">
                  <div className="font-bold text-amalfi-turquoise">
                    ${splitBill.totalUSD.toFixed(2)}
                  </div>
                  <div className="text-sm text-gray-400">
                    Bs. {splitBill.totalBs.toFixed(2)}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <SplitPaymentModal
        isOpen={selectedSplit !== null}
        split={selectedSplit}
        onClose={() => setSelectedSplit(null)}
        onSubmit={handlePaymentSubmit}
      />
    </div>
  )
}

export default SplitManager
