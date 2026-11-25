import React, { useState } from 'react'
import { usePrecuentas } from '../../hooks/usePrecuentas'
import { usePrinting } from '../../hooks/usePrinting'
import { Precuenta } from '../../types'
import Card from '../../components/common/Card'
import Button from '../../components/common/Button'
import PrintPreviewModal from '../../components/modals/PrintPreviewModal'
import {
  ReceiptRefundIcon,
  PrinterIcon,
  EyeIcon,
  XMarkIcon
} from '@/components/common/Icon'

interface PreCuentaManagerProps {
  tableId: string
  precuentas: Precuenta[]
  onClose: () => void
}

const PreCuentaManager: React.FC<PreCuentaManagerProps> = ({ 
  tableId, 
  precuentas, 
  onClose 
}) => {
  const { deletePrecuenta, markAsPaid } = usePrecuentas()
  const { printPrecuenta } = usePrinting()
  const [selectedPrecuenta, setSelectedPrecuenta] = useState<Precuenta | null>(null)
  const [showPrintPreview, setShowPrintPreview] = useState(false)

  const handlePrint = async (precuenta: Precuenta, width: 58 | 80 = 58) => {
    const success = await printPrecuenta(precuenta, width)
    if (success) {
      // Opcionalmente marcar como pagada después de imprimir
      // markAsPaid(precuenta.id)
    }
  }

  const handlePreview = (precuenta: Precuenta) => {
    setSelectedPrecuenta(precuenta)
    setShowPrintPreview(true)
  }

  const handleCancel = (precuentaId: string) => {
    if (confirm('¿Está seguro de cancelar esta precuenta?')) {
      deletePrecuenta(precuentaId)
    }
  }

  const handleMarkAsPaid = (precuentaId: string) => {
    if (confirm('¿Confirmar que esta precuenta ha sido pagada?')) {
      markAsPaid(precuentaId)
    }
  }

  if (precuentas.length === 0) {
    return (
      <Card>
        <div className="text-center py-8">
          <ReceiptRefundIcon className="h-12 w-12 text-gray-500 mx-auto mb-2" />
          <p className="text-gray-400">
            No hay precuentas para la mesa {tableId}
          </p>
          <Button variant="secondary" onClick={onClose} className="mt-4">
            Cerrar
          </Button>
        </div>
      </Card>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold text-white">
          Gestión de Precuentas - Mesa {tableId}
        </h3>
        <Button variant="secondary" onClick={onClose}>
          <XMarkIcon className="h-5 w-5 mr-2" />
          Cerrar
        </Button>
      </div>

      <div className="space-y-3">
        {precuentas.map((precuenta) => (
          <Card key={precuenta.id} title={`Precuenta ${precuenta.id}`}>
            <div className="space-y-3">
              {/* Información de la precuenta */}
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-gray-400">Fecha:</span>
                  <span className="text-white ml-2">
                    {new Date(precuenta.generatedAt).toLocaleString('es-ES')}
                  </span>
                </div>
                <div>
                  <span className="text-gray-400">Artículos:</span>
                  <span className="text-white ml-2">{precuenta.items.length}</span>
                </div>
                <div>
                  <span className="text-gray-400">Total USD:</span>
                  <span className="text-amalfi-turquoise font-bold ml-2">
                    ${precuenta.totalUSD.toFixed(2)}
                  </span>
                </div>
                <div>
                  <span className="text-gray-400">Total Bs:</span>
                  <span className="text-amalfi-turquoise font-bold ml-2">
                    Bs. {precuenta.totalBs.toFixed(2)}
                  </span>
                </div>
              </div>

              {/* Botones de acción */}
              <div className="flex space-x-2 pt-3 border-t border-gray-700">
                <Button 
                  size="sm" 
                  variant="secondary"
                  onClick={() => handlePreview(precuenta)}
                >
                  <EyeIcon className="h-4 w-4 mr-1" />
                  Previsualizar
                </Button>
                
                <Button 
                  size="sm" 
                  variant="primary"
                  onClick={() => handlePrint(precuenta)}
                >
                  <PrinterIcon className="h-4 w-4 mr-1" />
                  Imprimir
                </Button>
                
                <Button 
                  size="sm" 
                  variant="success"
                  onClick={() => handleMarkAsPaid(precuenta.id)}
                >
                  <ReceiptRefundIcon className="h-4 w-4 mr-1" />
                  Pagada
                </Button>
                
                <Button 
                  size="sm" 
                  variant="danger"
                  onClick={() => handleCancel(precuenta.id)}
                >
                  <XMarkIcon className="h-4 w-4 mr-1" />
                  Cancelar
                </Button>
              </div>
            </div>
          </Card>
        ))}
      </div>

      {/* Modal de previsualización de impresión */}
      <PrintPreviewModal
        isOpen={showPrintPreview}
        onClose={() => {
          setShowPrintPreview(false)
          setSelectedPrecuenta(null)
        }}
        precuenta={selectedPrecuenta}
        onPrint={handlePrint}
      />
    </div>
  )
}

export default PreCuentaManager