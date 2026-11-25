import React from 'react'
import { Table } from '../../types'
import Badge from '../../components/common/Badge'
import { 
  ClockIcon, 
  ShoppingBagIcon, 
  CurrencyDollarIcon 
} from '@/components/common/Icon'

interface TableCardProps {
  table: Table
  onClick: (tableId: string) => void
  onRightClick?: (tableId: string, event: React.MouseEvent) => void
}

const TableCard: React.FC<TableCardProps> = ({ 
  table, 
  onClick, 
  onRightClick 
}) => {
  const getStatusClasses = () => {
    switch (table.status) {
      case 'LIBRE':
        return 'border-gray-600 hover:border-gray-500 bg-gray-800 hover:bg-gray-750'
      case 'OCUPADA':
        return 'border-orange-500 bg-orange-900 bg-opacity-10 hover:bg-opacity-20'
      case 'PRECUENTA EMITIDA':
        return 'border-amalfi-turquoise bg-amalfi-turquoise bg-opacity-10 hover:bg-opacity-20'
      default:
        return 'border-gray-600 bg-gray-800'
    }
  }

  const getStatusBadge = () => {
    switch (table.status) {
      case 'LIBRE':
        return <Badge variant="default" size="sm">LIBRE</Badge>
      case 'OCUPADA':
        return <Badge variant="warning" size="sm">OCUPADA</Badge>
      case 'PRECUENTA EMITIDA':
        return <Badge variant="info" size="sm">PRECUENTA</Badge>
      default:
        return null
    }
  }

  const formatTime = (date: Date) => {
    const now = new Date()
    const diff = now.getTime() - new Date(date).getTime()
    const minutes = Math.floor(diff / 60000)
    
    if (minutes < 1) return 'Ahora'
    if (minutes < 60) return `${minutes}m`
    
    const hours = Math.floor(minutes / 60)
    return `${hours}h ${minutes % 60}m`
  }

  const handleRightClick = (e: React.MouseEvent) => {
    e.preventDefault()
    onRightClick?.(table.id, e)
  }

  return (
    <div
      className={`
        border-2 rounded-lg p-4 cursor-pointer transition-all duration-200
        ${getStatusClasses()}
        hover:transform hover:scale-105 hover:shadow-lg
      `}
      onClick={() => onClick(table.id)}
      onContextMenu={handleRightClick}
    >
      <div className="flex flex-col items-center text-center">
        {/* Nombre de la mesa */}
        <h3 className="font-bold text-lg text-white mb-1">
          {table.name}
        </h3>
        
        {/* Capacidad */}
        <p className="text-xs text-gray-400 mb-2">
          Capacidad: {table.capacity} personas
        </p>

        {/* Estado */}
        <div className="mb-2">
          {getStatusBadge()}
        </div>

        {/* Información de la sessión */}
        {table.status !== 'LIBRE' && table.currentSession && (
          <div className="w-full mt-2 space-y-1">
            {/* Tiempo transcurrido */}
            <div className="flex items-center justify-center space-x-1 text-xs text-gray-400">
              <ClockIcon className="h-3 w-3" />
              <span>{formatTime(table.currentSession.createdAt)}</span>
            </div>

            {/* Cantidad de artículos */}
            <div className="flex items-center justify-center space-x-1 text-xs text-gray-300">
              <ShoppingBagIcon className="h-3 w-3" />
              <span>
                {table.currentSession.items.filter(i => !i.cancelled).length} artículos
              </span>
            </div>

            {/* Total en USD */}
            <div className="flex items-center justify-center space-x-1 text-sm font-semibold text-amalfi-turquoise">
              <CurrencyDollarIcon className="h-4 w-4" />
              <span>${table.currentSession.totalUSD.toFixed(2)}</span>
            </div>

            {/* Total en Bs */}
            <div className="text-xs text-gray-400">
              Bs. {table.currentSession.totalBs.toFixed(2)}
            </div>

            {/* Indicador de precuenta */}
            {table.currentSession.precuentaGenerated && (
              <div className="mt-1">
                <Badge variant="info" size="sm">
                  Precuenta Emitida
                </Badge>
              </div>
            )}
          </div>
        )}

        {/* Mensaje para mesas libres */}
        {table.status === 'LIBRE' && (
          <div className="text-xs text-gray-500 mt-1">
            Clic para abrir
          </div>
        )}
      </div>
    </div>
  )
}

export default TableCard