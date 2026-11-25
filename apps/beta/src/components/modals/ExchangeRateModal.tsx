import React, { useState, useEffect } from 'react'
import { useStore } from '../../store/store'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Button from '../common/Button'
import { useCalculation } from '../../hooks/useCalculation'
import { useBcvExchangeRate } from '../../hooks/useBcvExchangeRate'
import { isBcvRateEffective } from '../../services/exchangeRate/bcvExchangeRateService'

interface ExchangeRateModalProps {
  isOpen: boolean
  onClose: () => void
}

const ExchangeRateModal: React.FC<ExchangeRateModalProps> = ({ 
  isOpen, 
  onClose 
}) => {
  const { config, currentUser, updateExchangeRate } = useStore()
  const { formatCurrency } = useCalculation()
  const { isLoading, error: bcvError, refreshBcvRate } = useBcvExchangeRate()
  const [rate, setRate] = useState(config.exchangeRate)
  const [error, setError] = useState('')
  const canManageRate = currentUser?.role === 'admin'
  const bcvRateIsEffective = config.bcvRateDate
    ? isBcvRateEffective(config.bcvRateDate)
    : false

  // Actualizar cuando se abre el modal
  useEffect(() => {
    if (isOpen) {
      setRate(config.exchangeRate)
    }
  }, [isOpen, config.exchangeRate])

  const handleSave = () => {
    if (!canManageRate) return

    if (!Number.isFinite(rate) || rate <= 0) {
      setError('La tasa debe ser mayor a 0')
      return
    }

    setError('')
    updateExchangeRate(rate)
    onClose()
  }

  const formatRateDate = (date: string) => {
    const parsedDate = new Date(`${date}T12:00:00-04:00`)
    return new Intl.DateTimeFormat('es-VE', {
      dateStyle: 'long',
      timeZone: 'America/Caracas'
    }).format(parsedDate)
  }

  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose} 
      title="Cambiar Tasa de Cambio" 
      size="md"
    >
      <div className="space-y-6">
        {/* Tasa actual */}
        <div className="p-4 bg-gray-700 rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-400">Tasa actual</p>
              <p className="text-lg font-semibold text-white">
                1 USD = {formatCurrency(config.exchangeRate, 'Bs')}
              </p>
              <p className="mt-1 text-xs text-gray-400">
                {config.exchangeRateSource === 'MANUAL'
                  ? 'Ajuste manual del administrador'
                  : 'Tasa oficial BCV'}
              </p>
            </div>
            <div className="text-right">
              <p className="text-sm text-gray-400">Ejemplo</p>
              <p className="text-sm text-white">
                ${10} = {formatCurrency(10 * config.exchangeRate, 'Bs')}
              </p>
            </div>
          </div>
        </div>

        <div className="space-y-3 rounded-lg border border-gray-700 bg-gray-900/40 p-4">
          <div>
            <p className="text-sm font-medium text-white">
              {bcvRateIsEffective
                ? 'Tasa vigente del BCV'
                : 'Próxima tasa publicada por el BCV'}
            </p>
            {config.bcvRate && config.bcvRateDate ? (
              <p className="mt-1 text-sm text-gray-300">
                1 USD = {formatCurrency(config.bcvRate, 'Bs')} · vigente desde{' '}
                {formatRateDate(config.bcvRateDate)}
              </p>
            ) : (
              <p className="mt-1 text-sm text-gray-400">
                Aún no se ha consultado una tasa del BCV.
              </p>
            )}
            {config.bcvRateDate && !bcvRateIsEffective && (
              <p className="mt-2 text-xs text-yellow-300">
                Esta tasa aún no está vigente. La tasa actual se conservará hasta el{' '}
                {formatRateDate(config.bcvRateDate)}.
              </p>
            )}
          </div>
          <Button
            type="button"
            variant="secondary"
            loading={isLoading}
            disabled={!canManageRate}
            onClick={() => { void refreshBcvRate(true) }}
          >
            {config.exchangeRateSource === 'MANUAL'
              ? 'Actualizar y usar tasa BCV'
              : 'Actualizar tasa BCV'}
          </Button>
          {config.exchangeRateSource === 'MANUAL' && (
            <p className="text-xs text-gray-400">
              El ajuste manual se conserva hasta que el administrador seleccione
              usar nuevamente la tasa del BCV.
            </p>
          )}
          {bcvError && (
            <p role="alert" className="text-sm text-red-400">
              No se pudo completar la actualización BCV: {bcvError}. Se mantiene la tasa actual.
            </p>
          )}
          {!canManageRate && (
            <p className="text-xs text-gray-400">
              Solo un administrador puede modificar la tasa.
            </p>
          )}
        </div>

        {/* Nueva tasa */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Ajustar tasa manual (Bs/USD)
          </label>
          <Input
            type="number"
            step="0.0001"
            min="0.0001"
            value={rate}
            disabled={!canManageRate}
            onChange={(e) => {
              const value = parseFloat(e.target.value) || 0
              setRate(value)
              if (error) setError('')
            }}
            error={error}
            helperText={!canManageRate
              ? undefined
              : config.exchangeRateSource === 'MANUAL'
                ? 'El cambio manual prevalece hasta que vuelvas a usar la tasa BCV.'
                : 'Al guardar un valor, quedará registrado como ajuste manual.'}
          />
          <p className="mt-1 text-xs text-gray-400">
            La tasa oficial puede superar ampliamente valores históricos.
          </p>
        </div>

        {/* Advertencia */}
        <div className="p-3 bg-yellow-900 bg-opacity-20 rounded-lg border border-yellow-700">
          <p className="text-sm text-yellow-300">
            <strong>Importante:</strong> El cambio de tasa afectará a todas las 
            operaciones futuras. Las operaciones históricas mantendrán sus 
            importes originales.
          </p>
        </div>

        <div className="flex justify-end space-x-3 pt-4 border-t border-gray-700">
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button
            variant="primary"
            disabled={!canManageRate}
            onClick={handleSave}
          >
            Guardar tasa manual
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default ExchangeRateModal