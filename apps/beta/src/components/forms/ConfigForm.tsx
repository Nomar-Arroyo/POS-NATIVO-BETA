import React, { useEffect, useState } from 'react'
import { useStore } from '../../store/store'
import Input from '../common/Input'
import Button from '../common/Button'

const ConfigForm: React.FC = () => {
  const { config, currentUser, setConfig, updateExchangeRate } = useStore()
  const [formData, setFormData] = useState(config)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const canManageRate = currentUser?.role === 'admin'

  useEffect(() => {
    setFormData(config)
  }, [config])

  const handleChange = (field: string, value: string | number) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: '' }))
    }
  }

  const validate = () => {
    const newErrors: Record<string, string> = {}
    
    if (!formData.establishmentName.trim()) {
      newErrors.establishmentName = 'El nombre del establecimiento es obligatorio'
    }
    
    if (!formData.taxId.trim()) {
      newErrors.taxId = 'El RIF/Cédula es obligatorio'
    }
    
    if (!Number.isFinite(formData.exchangeRate) || formData.exchangeRate <= 0) {
      newErrors.exchangeRate = 'La tasa de cambio debe ser mayor a 0'
    }

    if (!canManageRate && formData.exchangeRate !== config.exchangeRate) {
      newErrors.exchangeRate = 'Solo un administrador puede modificar la tasa'
    }
    
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validate()) {
      if (formData.exchangeRate !== config.exchangeRate) {
        setConfig({ ...formData, exchangeRate: config.exchangeRate })
        updateExchangeRate(formData.exchangeRate)
      } else {
        setConfig(formData)
      }
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Input
          label="Nombre del Establecimiento"
          value={formData.establishmentName}
          onChange={(e) => handleChange('establishmentName', e.target.value)}
          error={errors.establishmentName}
          placeholder="Ej: CAFÉ ANALÍTICA C.A."
        />
        
        <Input
          label="RIF / Cédula Fiscal"
          value={formData.taxId}
          onChange={(e) => handleChange('taxId', e.target.value)}
          error={errors.taxId}
          placeholder="Ej: J-12345678-9"
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Input
          label="Tasa de Cambio Bs./$"
          type="number"
          step="0.01"
          min="0.0001"
          value={formData.exchangeRate}
          disabled={!canManageRate}
          onChange={(e) => handleChange('exchangeRate', parseFloat(e.target.value) || 0)}
          error={errors.exchangeRate}
          helperText={!canManageRate
            ? 'Solo un administrador puede modificar la tasa.'
            : config.exchangeRateSource === 'MANUAL'
              ? 'La tasa manual se mantiene hasta volver a usar la tasa BCV.'
              : 'Al guardar un valor, quedará registrado como ajuste manual.'}
        />

        <Input
          label="Porcentaje IVA"
          type="number"
          step="0.01"
          min="0"
          max="100"
          value={formData.ivaRate * 100}
          onChange={(e) => setFormData(prev => ({ ...prev, ivaRate: (parseFloat(e.target.value) || 0) / 100 }))}
          helperText="Ej: 16%"
        />

        <Input
          label="Porcentaje IGTF"
          type="number"
          step="0.01"
          min="0"
          max="100"
          value={formData.igtfRate * 100}
          onChange={(e) => setFormData(prev => ({ ...prev, igtfRate: (parseFloat(e.target.value) || 0) / 100 }))}
          helperText="Ej: 3%"
        />
      </div>

      <div className="flex justify-end space-x-3">
        <Button type="submit" variant="primary">
          Guardar Configuración
        </Button>
      </div>
    </form>
  )
}

export default ConfigForm