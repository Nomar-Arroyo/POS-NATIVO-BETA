import React from 'react'
import { useStore } from '../../store/store'
import Input from '../../components/common/Input'
import Button from '../../components/common/Button'
import Card from '../../components/common/Card'

const FiscalConfig: React.FC = () => {
  const { config, setConfig } = useStore()

  const handleFiscalConfigChange = (field: string, value: any) => {
    setConfig({ ...config, [field]: value })
  }

  return (
    <Card title="Configuración Fiscal">
      <div className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Input
            label="RIF del Emisor"
            value={config.taxId}
            onChange={(e) => handleFiscalConfigChange('taxId', e.target.value)}
            placeholder="Ej: J-12345678-9"
          />

          <div className="flex items-center">
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={config.fiscalSimulation}
                onChange={(e) => handleFiscalConfigChange('fiscalSimulation', e.target.checked)}
                className="rounded bg-gray-700 border-gray-600 text-amalfi-turquoise focus:ring-amalfi-turquoise"
              />
              <span className="ml-2 text-sm text-gray-300">
                Simulación fiscal SENIAT activada
              </span>
            </label>
          </div>
        </div>

        <div className="p-4 bg-blue-900 bg-opacity-20 rounded-lg border border-blue-700">
          <h4 className="font-medium text-blue-300 mb-2">Información Fiscal</h4>
          <p className="text-sm text-gray-300">
            La simulación fiscal SENIAT es exclusivamente para demostración. 
            No genera documentos fiscales legalmente válidos.
          </p>
        </div>

        <div className="flex justify-end">
          <Button variant="primary">
            Guardar Configuración Fiscal
          </Button>
        </div>
      </div>
    </Card>
  )
}

export default FiscalConfig