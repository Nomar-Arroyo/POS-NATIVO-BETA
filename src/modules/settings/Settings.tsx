import React from 'react'
import { useStore } from '../../store/store'
import CatalogConfig from './CatalogConfig'
import FiscalConfig from './FiscalConfig'
import DemoReset from './DemoReset'
import Button from '../../components/common/Button'

const Settings: React.FC = () => {
  const { saveState } = useStore()

  const handleSave = () => {
    saveState()
    // Mostrar notificación de éxito
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Configuración</h2>
        <Button variant="primary" onClick={handleSave}>
          Guardar Cambios
        </Button>
      </div>

      <div className="space-y-6">
        <CatalogConfig />
        <FiscalConfig />
        <DemoReset />
      </div>
    </div>
  )
}

export default Settings