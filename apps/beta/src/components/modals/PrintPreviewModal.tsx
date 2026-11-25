import React, { useState } from 'react'
import { usePrecuentas } from '../../hooks/usePrecuentas'
import { usePrinting } from '../../hooks/usePrinting'
import Modal from '../common/Modal'
import Button from '../common/Button'
import { Precuenta } from '../../types'
import {
  PrinterIcon,
  ArrowDownTrayIcon
} from '@/components/common/Icon'

interface PrintPreviewModalProps {
  isOpen: boolean
  onClose: () => void
  precuenta: Precuenta | null
  onPrint?: (precuenta: Precuenta, width: 58 | 80) => void
}

const PrintPreviewModal: React.FC<PrintPreviewModalProps> = ({
  isOpen,
  onClose,
  precuenta,
  onPrint
}) => {
  const { getTicketHtml } = usePrecuentas()
  const { printHtml } = usePrinting()
  const [ticketWidth, setTicketWidth] = useState<58 | 80>(58)

  if (!precuenta) return null

  const ticketHtml = getTicketHtml(precuenta, ticketWidth)

  const handlePrint = async () => {
    try {
      const success = await printHtml(ticketHtml, `Precuenta ${precuenta.id}`, ticketWidth)
      
      if (success) {
        onPrint?.(precuenta, ticketWidth)
      } else {
        alert('Error al imprimir. Intente de nuevo.')
      }
    } catch (error) {
      console.error('Error printing:', error)
      alert('Error al imprimir la precuenta')
    }
  }

  const handleDownload = () => {
    const blob = new Blob([ticketHtml], { type: 'text/html' })
    const url = URL.createObjectURL(blob)
    
    const link = document.createElement('a')
    link.href = url
    link.download = `precuente-${precuenta.id}-${ticketWidth}mm.html`
    link.click()
    
    URL.revokeObjectURL(url)
  }

  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose} 
      title="Vista Previa de Impresión" 
      size="xl"
    >
      <div className="space-y-4">
        {/* Controles de impresión */}
        <div className="flex items-center justify-between p-4 bg-gray-700 rounded-lg">
          <div className="flex items-center space-x-4">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-2">
                Ancho del Ticket
              </label>
              <div className="flex space-x-2">
                <button
                  onClick={() => setTicketWidth(58)}
                  className={`
                    px-3 py-2 rounded-lg text-sm font-medium transition-colors
                    ${ticketWidth === 58
                      ? 'bg-amalfi-deep text-white'
                      : 'bg-gray-600 text-gray-300 hover:bg-gray-500'
                    }
                  `}
                >
                  58mm
                </button>
                <button
                  onClick={() => setTicketWidth(80)}
                  className={`
                    px-3 py-2 rounded-lg text-sm font-medium transition-colors
                    ${ticketWidth === 80
                      ? 'bg-amalfi-deep text-white'
                      : 'bg-gray-600 text-gray-300 hover:bg-gray-500'
                    }
                  `}
                >
                  80mm
                </button>
              </div>
            </div>
          </div>

          <div className="flex space-x-2">
            <Button variant="secondary" onClick={handleDownload}>
              <ArrowDownTrayIcon className="h-5 w-5 mr-2" />
              Descargar
            </Button>
            <Button variant="primary" onClick={handlePrint}>
              <PrinterIcon className="h-5 w-5 mr-2" />
              Imprimir
            </Button>
          </div>
        </div>

        {/* Vista previa del ticket */}
        <div className="border border-gray-700 rounded-lg overflow-hidden">
          <div className="bg-gray-800 p-3 border-b border-gray-700">
            <h3 className="font-medium text-white">Vista Previa</h3>
          </div>
          
          <div className="p-4 bg-white">
            <div 
              className="mx-auto bg-white shadow-lg rounded"
              style={{
                width: ticketWidth === 58 ? '58mm' : '80mm',
                minHeight: '100mm'
              }}
            >
              <div 
                dangerouslySetInnerHTML={{ __html: ticketHtml }}
                className="ticket-preview"
              />
            </div>
          </div>
        </div>

        {/* Información de la precuenta */}
        <div className="grid grid-cols-2 gap-4 p-4 bg-gray-700 rounded-lg">
          <div>
            <h4 className="font-medium text-white mb-2">Información de la Precuenta</h4>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-400">ID:</span>
                <span className="text-white">{precuenta.id}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Mesa:</span>
                <span className="text-white">{precuenta.tableId}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Fecha:</span>
                <span className="text-white">
                  {new Date(precuenta.generatedAt).toLocaleString('es-ES')}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Artículos:</span>
                <span className="text-white">{precuenta.items.length}</span>
              </div>
            </div>
          </div>
          
          <div>
            <h4 className="font-medium text-white mb-2">Totales</h4>
            <div className="space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-400">Subtotal:</span>
                <span className="text-white">${precuenta.subtotalUSD.toFixed(2)}</span>
              </div>
              <div className="flex justify-between font-bold">
                <span className="text-gray-400">Total:</span>
                <span className="text-amalfi-turquoise">
                  {`$${precuenta.totalUSD.toFixed(2)} / Bs. ${precuenta.totalBs.toFixed(2)}`}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Modal>
  )
}

export default PrintPreviewModal