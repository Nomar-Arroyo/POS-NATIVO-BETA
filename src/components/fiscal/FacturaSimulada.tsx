import React from 'react'
import { Factura } from '../../types'
import { useCalculation } from '../../hooks/useCalculation'
import Modal from '../common/Modal'
import Button from '../common/Button'
import Badge from '../common/Badge'
import Icon from '../common/Icon'
import {
  PrinterIcon,
  ArrowDownTrayIcon,
  XMarkIcon
} from '@/components/common/Icon'

interface FacturaSimuladaProps {
  factura: Factura
  onClose: () => void
}

const FacturaSimulada: React.FC<FacturaSimuladaProps> = ({ 
  factura, 
  onClose 
}) => {
  const { formatCurrency } = useCalculation()

  const handlePrint = () => {
    // Lógica para imprimir la factura
    window.print()
  }

  const handleDownload = () => {
    // Lógica para descargar la factura
    const factHtml = generateFacturaHtml(factura)
    const blob = new Blob([factHtml], { type: 'text/html' })
    const url = URL.createObjectURL(blob)
    
    const link = document.createElement('a')
    link.href = url
    link.download = `factura-${factura.number}.html`
    link.click()
    
    URL.revokeObjectURL(url)
  }

  const generateFacturaHtml = (factura: Factura): string => {
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Factura ${factura.number}</title>
        <style>
          body { font-family: monospace; margin: 20px; }
          .header { text-align: center; border-bottom: 2px solid #000; padding-bottom: 10px; }
          .footer { text-align: center; border-top: 2px solid #000; padding-top: 10px; margin-top: 20px; }
          table { width: 100%; border-collapse: collapse; margin: 10px 0; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          .total { font-weight: bold; font-size: 1.2em; }
          .simulated { color: red; font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>CAFÉ ANALÍTICA C.A.</h1>
          <p>RIF: J-12345678-9</p>
          <h2>FACTURA SIMULADA</h2>
        </div>
        
        <p><strong>Número:</strong> ${factura.number}</p>
        <p><strong>Control:</strong> ${factura.controlNumber}</p>
        <p><strong>Fecha:</strong> ${new Date(factura.createdAt).toLocaleString()}</p>
        <p><strong>Cliente:</strong> ${factura.customerName || 'CONSUMIDOR FINAL'}</p>
        <p><strong>RIF:</strong> ${factura.customerRif || 'N/A'}</p>
        
        <table>
          <thead>
            <tr>
              <th>Producto</th>
              <th>Cant</th>
              <th>P.U.</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            ${factura.items.map(item => `
              <tr>
                <td>${item.product?.name || item.productId}</td>
                <td>${item.quantity}</td>
                <td>${formatCurrency(item.unitPrice, 'USD')}</td>
                <td>${formatCurrency(item.quantity * item.unitPrice, 'USD')}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
        
        <div class="total">
          <p>Subtotal: ${formatCurrency(factura.subtotal, 'USD')}</p>
          <p>Base Imponible: ${formatCurrency(factura.baseImponible || 0, 'USD')}</p>
          <p>IVA (16%): ${formatCurrency(factura.iva, 'USD')}</p>
          <p>IGTF (3%): ${formatCurrency(factura.igtf || 0, 'USD')}</p>
          <p>TOTAL: ${formatCurrency(factura.total, 'USD')}</p>
        </div>
        
        <div class="footer">
          <p class="simulated">VALIDADO FISCALMENTE (SIMULACIÓN BETA SENIAT)</p>
          <p>Este documento es una simulación para fines de demostración</p>
          <p>¡Gracias por su preferencia!</p>
        </div>
      </body>
      </html>
    `
  }

  return (
    <Modal 
      isOpen={true} 
      onClose={onClose} 
      title="Factura Fiscal Simulada" 
      size="xl"
    >
      <div className="space-y-4">
        {/* Header de la factura */}
        <div className="text-center border-b pb-4">
          <h2 className="text-xl font-bold">CAFÉ ANALÍTICA C.A.</h2>
          <p className="text-sm text-gray-400">RIF: J-12345678-9</p>
          <Badge variant="warning" size="sm" className="mt-2">
            SIMULACIÓN BETA SENIAT
          </Badge>
        </div>

        {/* Datos de la factura */}
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-gray-400">Número de Factura:</span>
            <span className="text-white ml-2 font-medium">{factura.number}</span>
          </div>
          <div>
            <span className="text-gray-400">Número de Control:</span>
            <span className="text-white ml-2 font-medium">{factura.controlNumber}</span>
          </div>
          <div>
            <span className="text-gray-400">Fecha:</span>
            <span className="text-white ml-2">
              {new Date(factura.createdAt).toLocaleString('es-ES')}
            </span>
          </div>
          <div>
            <span className="text-gray-400">Estado:</span>
            <Badge variant="success" size="sm" className="ml-2">
              Simulada
            </Badge>
          </div>
        </div>

        {/* Datos del cliente */}
        <div className="p-4 bg-gray-700 rounded-lg">
          <h3 className="font-medium text-white mb-2">Datos del Cliente</h3>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div>
              <span className="text-gray-400">Nombre:</span>
              <span className="text-white ml-2">
                {factura.customerName || 'CONSUMIDOR FINAL'}
              </span>
            </div>
            <div>
              <span className="text-gray-400">RIF/Cédula:</span>
              <span className="text-white ml-2">
                {factura.customerRif || 'N/A'}
              </span>
            </div>
          </div>
        </div>

        {/* Productos */}
        <div>
          <h3 className="font-medium text-white mb-2">Detalles de Productos</h3>
          <table className="w-full border border-gray-700 rounded-lg overflow-hidden">
            <thead className="bg-gray-700">
              <tr>
                <th className="p-2 text-left">Producto</th>
                <th className="p-2 text-right">cantidad</th>
                <th className="p-2 text-right">Precio Unit.</th>
                <th className="p-2 text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              {factura.items.map((item, index) => (
                <tr key={index} className="border-t border-gray-700">
                  <td className="p-2">{item.product?.name || item.productId}</td>
                  <td className="p-2 text-right">{item.quantity}</td>
                  <td className="p-2 text-right">{formatCurrency(item.unitPrice, 'USD')}</td>
                  <td className="p-2 text-right">
                    {formatCurrency(item.quantity * item.unitPrice, 'USD')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Totales fiscales */}
        <div className="grid grid-cols-2 gap-6">
          <div className="p-4 bg-gray-700 rounded-lg">
            <h3 className="font-medium text-white mb-2">Valores Fiscales</h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-400">Subtotal:</span>
                <span className="text-white">{formatCurrency(factura.subtotal, 'USD')}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Base Imponible:</span>
                <span className="text-white">{formatCurrency(factura.baseImponible || 0, 'USD')}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">IVA (16%):</span>
                <span className="text-white">{formatCurrency(factura.iva, 'USD')}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">IGTF (3%):</span>
                <span className="text-white">{formatCurrency(factura.igtf || 0, 'USD')}</span>
              </div>
            </div>
          </div>

          <div className="p-4 bg-gray-700 rounded-lg">
            <h3 className="font-medium text-white mb-2">Total y Pagos</h3>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-400">Total Factura:</span>
                <span className="text-amalfi-turquoise font-bold">
                  {formatCurrency(factura.total, 'USD')}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Métodos de Pago:</span>
                <span className="text-white">
                  {factura.payments.map(p => p.method).join(', ')}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Advertencia fiscal */}
        <div className="p-4 bg-red-900 bg-opacity-20 rounded-lg border border-red-700">
          <div className="flex items-start space-x-2">
            <div className="flex-shrink-0">
              <Icon name="alert" size={20} color="#F87171" />
            </div>
            <div>
              <h4 className="font-medium text-red-300">AVISO IMPORTANTE</h4>
              <p className="text-sm text-red-200 mt-1">
                Esta es una <strong>SIMULACIÓN FISCAL</strong> para fines de demostración. 
                No es un documento fiscal legalmente válido ante el SENIAT. 
                No ha sido transmitido a ningún sistema fiscal real.
              </p>
            </div>
          </div>
        </div>

        {/* Botones de acción */}
        <div className="flex justify-end space-x-3 pt-4 border-t border-gray-700">
          <Button variant="secondary" onClick={handleDownload}>
            <ArrowDownTrayIcon className="h-5 w-5 mr-2" />
            Descargar
          </Button>
          <Button variant="primary" onClick={handlePrint}>
            <PrinterIcon className="h-5 w-5 mr-2" />
            Imprimir
          </Button>
          <Button variant="secondary" onClick={onClose}>
            <XMarkIcon className="h-5 w-5 mr-2" />
            Cerrar
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default FacturaSimulada