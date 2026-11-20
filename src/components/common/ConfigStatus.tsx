import React from 'react'
import { useConfig } from '../../hooks/useConfig'
import { 
  CheckCircleIcon, 
  ExclamationTriangleIcon 
} from '@/components/common/Icon'

const ConfigStatus: React.FC = () => {
  const { validate } = useConfig()
  const validation = validate()

  if (validation.isValid) {
    return (
      <div className="flex items-center space-x-2 text-green-400 text-sm">
        <CheckCircleIcon className="h-4 w-4" />
        <span>Configuración válida</span>
      </div>
    )
  }

  return (
    <div className="flex items-center space-x-2 text-yellow-400 text-sm">
      <ExclamationTriangleIcon className="h-4 w-4" />
      <span>Configuración con advertencias</span>
    </div>
  )
}

export default ConfigStatus