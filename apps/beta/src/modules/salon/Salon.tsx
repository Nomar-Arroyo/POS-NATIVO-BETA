import React from 'react'
import { useTables } from '../../hooks/useTables'
import TableGrid from './TableGrid'
import TableSession from './TableSession'
import Button from '../../components/common/Button'
import Card from '../../components/common/Card'

const Salon: React.FC = () => {
  const { selectedTable, setSelectedTable } = useTables()

  if (selectedTable) {
    return (
      <div>
        <Button
          variant="secondary"
          onClick={() => setSelectedTable(null)}
          className="mb-4"
        >
          Volver al Salón
        </Button>
        <TableSession
          tableId={selectedTable}
          onClose={() => setSelectedTable(null)}
        />
      </div>
    )
  }

  return (
    <div className="space-y-4 sm:space-y-6">
      <TableGrid onTableSelect={setSelectedTable} />
      <Card title="Leyenda">
        <div className="flex flex-wrap items-center gap-x-6 gap-y-3 text-sm">
          <div className="flex items-center gap-2">
            <div className="h-4 w-4 rounded border-2 border-gray-600" />
            <span className="text-gray-300">Mesa Libre</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="h-4 w-4 rounded border-2 border-orange-500 bg-orange-900 bg-opacity-10" />
            <span className="text-gray-300">Mesa Ocupada</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="h-4 w-4 rounded border-2 border-amalfi-turquoise bg-amalfi-turquoise bg-opacity-10" />
            <span className="text-gray-300">Precuenta Emitida</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="h-4 w-4 rounded-full bg-gray-700" />
            <span className="text-gray-300">Clic para abrir mesa</span>
          </div>
        </div>
      </Card>
    </div>
  )
}

export default Salon
