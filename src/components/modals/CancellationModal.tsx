import React, { useEffect, useState } from 'react'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Select from '../common/Select'
import Button from '../common/Button'
import Badge from '../common/Badge'
import { CANCELLATION_REASONS } from '../../types'
import { ExclamationTriangleIcon } from '@/components/common/Icon'

interface CancellationModalProps {
  isOpen: boolean
  onClose: () => void
  type: 'PRODUCT' | 'ORDER' | 'ITEM'
  itemId: string
  itemName: string
  tableId?: string
  orderId?: string
  quantity?: number
  amount?: number
  onSubmit: (reason: string, customReason?: string) => void
}

const CancellationModal: React.FC<CancellationModalProps> = ({
  isOpen,
  onClose,
  type,
  itemName,
  tableId,
  orderId,
  quantity = 1,
  amount = 0,
  onSubmit
}) => {
  const [reason, setReason] = useState('')
  const [customReason, setCustomReason] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})

  useEffect(() => {
    if (isOpen) {
      setReason('')
      setCustomReason('')
      setErrors({})
    }
  }, [isOpen])

  const reasonOptions = [
    { value: '', label: 'Seleccione un motivo...' },
    ...Object.values(CANCELLATION_REASONS).map(value => ({
      value,
      label: value
    }))
  ]

  const validate = () => {
    const newErrors: Record<string, string> = {}

    if (!reason.trim()) {
      newErrors.reason = 'El motivo es obligatorio'
    }

    if (reason === CANCELLATION_REASONS.OTHER && !customReason.trim()) {
      newErrors.customReason = 'Por favor, especifique el motivo'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    if (!validate()) return

    onSubmit(
      reason,
      reason === CANCELLATION_REASONS.OTHER ? customReason.trim() : undefined
    )
  }

  const getTypeText = () => {
    switch (type) {
      case 'PRODUCT':
        return 'Producto'
      case 'ORDER':
        return 'Orden'
      case 'ITEM':
        return 'Artículo'
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Solicitud de Anulación"
      size="md"
    >
      <div className="space-y-4">
        <div className="p-3 bg-red-900 bg-opacity-20 rounded-lg border border-red-700">
          <div className="flex items-start space-x-2">
            <ExclamationTriangleIcon className="h-5 w-5 text-red-400 flex-shrink-0 mt-0.5" />
            <div>
              <h4 className="font-medium text-red-300">Zona de Anulación</h4>
              <p className="text-sm text-red-200 mt-1">
                Esta acción registrará la anulación y será auditada.
                Asegúrese de que la anulación esté justificada.
              </p>
            </div>
          </div>
        </div>

        <div className="p-3 bg-gray-700 rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-400">{getTypeText()} a anular:</p>
              <p className="font-medium text-white">{itemName}</p>
              {tableId && (
                <p className="text-xs text-gray-400">Mesa: {tableId}</p>
              )}
              {orderId && (
                <p className="text-xs text-gray-400">Orden: {orderId}</p>
              )}
            </div>
            <div className="text-right">
              {quantity > 1 && (
                <Badge variant="info" size="sm" className="mb-1">
                  Cantidad: {quantity}
                </Badge>
              )}
              {amount > 0 && (
                <p className="font-bold text-amalfi-turquoise">
                  ${amount.toFixed(2)}
                </p>
              )}
            </div>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <Select
            label="Motivo de Anulación *"
            options={reasonOptions}
            value={reason}
            onChange={event => {
              setReason(event.target.value)
              if (errors.reason) {
                setErrors(previous => ({ ...previous, reason: '' }))
              }
            }}
            error={errors.reason}
          />

          {reason === CANCELLATION_REASONS.OTHER && (
            <Input
              label="Especifique el motivo *"
              value={customReason}
              onChange={event => {
                setCustomReason(event.target.value)
                if (errors.customReason) {
                  setErrors(previous => ({ ...previous, customReason: '' }))
                }
              }}
              error={errors.customReason}
              placeholder="Describa el motivo de la anulación"
            />
          )}

          <div className="p-3 bg-blue-900 bg-opacity-20 rounded-lg border border-blue-700">
            <p className="text-sm text-blue-300">
              <strong>Nota:</strong> La anulación será registrada en el sistema
              de auditoría y requerirá aprobación para ser ejecutada.
            </p>
          </div>

          <div className="flex justify-end space-x-3 pt-4 border-t border-gray-700">
            <Button type="button" variant="secondary" onClick={onClose}>
              Cancelar
            </Button>
            <Button type="submit" variant="danger">
              Enviar Solicitud
            </Button>
          </div>
        </form>
      </div>
    </Modal>
  )
}

export default CancellationModal
