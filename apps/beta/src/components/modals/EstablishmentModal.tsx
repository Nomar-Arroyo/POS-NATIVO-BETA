import React, { useState } from 'react'
import { useStore } from '../../store/store'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Button from '../common/Button'

interface EstablishmentModalProps {
  isOpen: boolean
  onClose: () => void
}

const EstablishmentModal: React.FC<EstablishmentModalProps> = ({ 
  isOpen, 
  onClose 
}) => {
  const { config, setConfig } = useStore()
  const [formData, setFormData] = useState({
    establishmentName: config.establishmentName,
    taxId: config.taxId
  })
  const [errors, setErrors] = useState<Record<string, string>>({})

  const validate = () => {
    const newErrors: Record<string, string> = {}
    
    if (!formData.establishmentName.trim()) {
      newErrors.establishmentName = 'El nombre del establecimiento es obligatorio'
    }
    
    if (!formData.taxId.trim()) {
      newErrors.taxId = 'El RIF/Cédula es obligatorio'
    }
    
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validate()) {
      setConfig({
        ...config,
        establishmentName: formData.establishmentName,
        taxId: formData.taxId
      })
      onClose()
    }
  }

  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose} 
      title="Configuración del Establecimiento" 
      size="md"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          label="Nombre del Establecimiento"
          value={formData.establishmentName}
          onChange={(e) => setFormData(prev => ({ 
            ...prev, 
            establishmentName: e.target.value 
          }))}
          error={errors.establishmentName}
          placeholder="Ej: CAFÉ ANALÍTICA C.A."
        />

        <Input
          label="RIF / Cédula Fiscal"
          value={formData.taxId}
          onChange={(e) => setFormData(prev => ({ 
            ...prev, 
            taxId: e.target.value 
          }))}
          error={errors.taxId}
          placeholder="Ej: J-12345678-9"
        />

        <div className="p-3 bg-blue-900 bg-opacity-20 rounded-lg border border-blue-700">
          <p className="text-sm text-blue-300">
            Estos datos aparecerán en todas las facturas y documentos del sistema.
          </p>
        </div>

        <div className="flex justify-end space-x-3 pt-4">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" variant="primary">
            Guardar Cambios
          </Button>
        </div>
      </form>
    </Modal>
  )
}

export default EstablishmentModal