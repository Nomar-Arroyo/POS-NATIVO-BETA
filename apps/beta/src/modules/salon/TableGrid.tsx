import React, { useState, useRef } from 'react'
import { useTables } from '../../hooks/useTables'
import TableCard from './TableCard'
import Input from '../../components/common/Input'
import Select from '../../components/common/Select'
import Badge from '../../components/common/Badge'
import { 
  MagnifyingGlassIcon,
  Squares2X2Icon,
  ListBulletIcon
} from '@/components/common/Icon'

interface TableGridProps {
  onTableSelect: (tableId: string) => void
  onTableRightClick?: (tableId: string, event: React.MouseEvent) => void
}

const TableGrid: React.FC<TableGridProps> = ({ 
  onTableSelect, 
  onTableRightClick 
}) => {
  const { tables, getStats, search } = useTables()
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('TODAS')
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid')
  const gridRef = useRef<HTMLDivElement>(null)

  const stats = getStats()

  // Filtrar mesas
  const filteredTables = React.useMemo(() => {
    let result = tables

    // Filtrar por búsqueda
    if (searchTerm) {
      result = search(searchTerm)
    }

    // Filtrar por estado
    if (statusFilter !== 'TODAS') {
      result = result.filter(table => table.status === statusFilter)
    }

    // Ordenar por posición (para la cuadrícula)
    return result.sort((a, b) => {
      if (a.position.y !== b.position.y) {
        return a.position.y - b.position.y
      }
      return a.position.x - b.position.x
    })
  }, [tables, searchTerm, statusFilter, search])

  const statusOptions = [
    { value: 'TODAS', label: 'Todas las Mesas' },
    { value: 'LIBRE', label: 'Libres' },
    { value: 'OCUPADA', label: 'Ocupadas' },
    { value: 'PRECUENTA EMITIDA', label: 'Con Precuenta' }
  ]

  const handleDragStart = (e: React.DragEvent<HTMLDivElement>, tableId: string) => {
    e.dataTransfer.setData('text/plain', tableId)
  }

  const handleDrop = (e: React.DragEvent, targetTableId: string) => {
    e.preventDefault()
    const draggedTableId = e.dataTransfer.getData('text/plain')
    
    if (draggedTableId !== targetTableId) {
      // Aquí se podría implementar el reordenamiento de mesas
      console.log('Reordenar:', draggedTableId, 'a', targetTableId)
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
  }

  return (
    <div className="space-y-6">
      {/* Header con controles */}
      <div className="flex flex-col md:flex-row md:items-center justify-between space-y-4 md:space-y-0">
        <div>
          <h2 className="text-2xl font-bold text-white">Salón y Mesas</h2>
          <p className="text-gray-400">Gestiona el estado de todas las mesas</p>
        </div>

        <div className="flex items-center space-x-4">
          {/* Estadísticas rápidas */}
          <div className="hidden lg:flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <Badge variant="success" size="sm">
                {stats.free} Libres
              </Badge>
            </div>
            <div className="flex items-center space-x-2">
              <Badge variant="warning" size="sm">
                {stats.occupied} Ocupadas
              </Badge>
            </div>
            <div className="flex items-center space-x-2">
              <Badge variant="info" size="sm">
                {stats.precuenta} Precuenta
              </Badge>
            </div>
            <div className="text-sm text-gray-400">
              Ocupación: {stats.occupancyRate.toFixed(1)}%
            </div>
          </div>

          {/* Controles de vista */}
          <div className="flex items-center space-x-2">
            <button
              onClick={() => setViewMode('grid')}
              className={`
                p-2 rounded-lg transition-colors
                ${viewMode === 'grid' 
                  ? 'bg-amalfi-deep text-white' 
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }
              `}
            >
              <Squares2X2Icon className="h-5 w-5" />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={`
                p-2 rounded-lg transition-colors
                ${viewMode === 'list' 
                  ? 'bg-amalfi-deep text-white' 
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }
              `}
            >
              <ListBulletIcon className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Filtros y búsqueda */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="md:col-span-2">
          <Input
            placeholder="Busca por nombre o número de mesa..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div>
          <Select
            options={statusOptions}
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          />
        </div>
      </div>

      {/* Cuadrícula de mesas */}
      <div 
        ref={gridRef}
        className={`
          grid gap-4 
          ${viewMode === 'grid' 
            ? 'grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8'
            : 'grid-cols-1'
          }
        `}
      >
        {filteredTables.map((table) => (
          <div
            key={table.id}
            draggable={viewMode === 'grid'}
            onDragStart={(e) => handleDragStart(e, table.id)}
            onDrop={(e) => handleDrop(e, table.id)}
            onDragOver={handleDragOver}
          >
            <TableCard
              table={table}
              onClick={onTableSelect}
              onRightClick={onTableRightClick}
            />
          </div>
        ))}
      </div>

      {/* Estado vacío */}
      {filteredTables.length === 0 && (
        <div className="text-center py-12">
          <div className="text-gray-500 mb-4">
            <MagnifyingGlassIcon className="h-16 w-16 mx-auto mb-4" />
          </div>
          <h3 className="text-lg font-medium text-gray-400 mb-2">
            No se encontraron mesas
          </h3>
          <p className="text-gray-500">
            Prueba a cambiar los filtros o buscar con otro término
          </p>
        </div>
      )}
    </div>
  )
}

export default TableGrid