import React, { useEffect, useState } from 'react'
import { useCash } from '../../hooks/useCash'
import { useStore } from '../../store/store'
import type { CashSession } from '../../types/cash'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Button from '../common/Button'
import { BanknotesIcon, CalendarIcon } from '@/components/common/Icon'

interface OpenCashModalProps {
  isOpen: boolean
  onClose: () => void
  onCashOpened: (session: CashSession) => void
}

const OpenCashModal: React.FC<OpenCashModalProps> = ({
  isOpen,
  onClose,
  onCashOpened
}) => {
  const { openCash } = useCash()
  const { currentUser } = useStore()
  const [openingBalanceUSD, setOpeningBalanceUSD] = useState(0)
  const [openingBalanceBs, setOpeningBalanceBs] = useState(0)
  const [errors, setErrors] = useState<Record<string, string>>({})

  useEffect(() => {
    if (!isOpen) {
      setOpeningBalanceUSD(0)
      setOpeningBalanceBs(0)
      setErrors({})
    }
  }, [isOpen])

  const handleSubmit = () => {
    const nextErrors: Record<string, string> = {}
    if (!Number.isFinite(openingBalanceUSD) || openingBalanceUSD < 0) {
      nextErrors.openingBalanceUSD = 'Ingrese un saldo USD válido y no negativo'
    }
    if (!Number.isFinite(openingBalanceBs) || openingBalanceBs < 0) {
      nextErrors.openingBalanceBs = 'Ingrese un saldo Bs válido y no negativo'
    }
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length > 0) return

    const userId = currentUser?.id || '1'
    const userName = currentUser?.name || 'Administrador'
    const result = openCash(
      userId,
      userName,
      openingBalanceUSD,
      openingBalanceBs
    )
    if (result.success && result.session) {
      onCashOpened(result.session)
      onClose()
    }
  }

  const currentDateTime = new Date().toLocaleString('es-ES', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Abrir Caja" size="md">
      <div className="space-y-6">
        <div className="rounded-lg bg-gray-700 p-4">
          <div className="mb-2 flex items-center space-x-2">
            <CalendarIcon className="h-5 w-5 text-gray-400" />
            <span className="text-sm text-gray-300">Fecha y hora de apertura</span>
          </div>
          <p className="font-medium text-white">{currentDateTime}</p>
        </div>

        <div className="space-y-4">
          <h3 className="text-lg font-medium text-white">Saldos iniciales</h3>
          <Input
            label="Saldo inicial USD"
            type="number"
            step="0.01"
            min="0"
            value={openingBalanceUSD}
            onChange={event => setOpeningBalanceUSD(
              Number.parseFloat(event.target.value) || 0
            )}
            error={errors.openingBalanceUSD}
            helperText="Efectivo inicial en dólares"
          />
          <Input
            label="Saldo inicial Bs"
            type="number"
            step="0.01"
            min="0"
            value={openingBalanceBs}
            onChange={event => setOpeningBalanceBs(
              Number.parseFloat(event.target.value) || 0
            )}
            error={errors.openingBalanceBs}
            helperText="Efectivo inicial en bolívares"
          />
        </div>

        <div className="rounded-lg border border-blue-700 bg-blue-900 bg-opacity-20 p-3">
          <div className="flex items-start space-x-2">
            <BanknotesIcon className="mt-0.5 h-5 w-5 flex-shrink-0 text-amalfi-turquoise" />
            <p className="text-sm text-blue-200">
              Cuente el efectivo físicamente antes de abrir la sesión.
            </p>
          </div>
        </div>

        <div className="flex justify-end space-x-3 border-t border-gray-700 pt-4">
          <Button variant="secondary" onClick={onClose}>Cancelar</Button>
          <Button variant="primary" onClick={handleSubmit}>
            <BanknotesIcon className="mr-2 h-5 w-5" />
            Abrir Caja
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default OpenCashModal
