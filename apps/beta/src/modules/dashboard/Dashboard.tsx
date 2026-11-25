import React from 'react'
import { useStore } from '../../store/store'
import Card from '../../components/common/Card'
import { 
  ChartBarIcon, 
  TableCellsIcon, 
  CurrencyDollarIcon,
  ShoppingBagIcon
} from '@/components/common/Icon'

const Dashboard: React.FC = () => {
  const { tables, facturas, cashSessions } = useStore()

  const occupiedTables = tables.filter(t => t.status !== 'LIBRE').length
  const totalSales = facturas.reduce((sum, f) => sum + f.total, 0)
  const activeCashSession = cashSessions.find(s => s.status === 'OPEN')

  const stats = [
    {
      title: 'Mesas Ocupadas',
      value: `${occupiedTables}/${tables.length}`,
      icon: TableCellsIcon,
      color: 'text-amalfi-turquoise'
    },
    {
      title: 'Ventas del Día',
      value: `$${totalSales.toFixed(2)}`,
      icon: CurrencyDollarIcon,
      color: 'text-green-400'
    },
    {
      title: 'Facturas Emitidas',
      value: facturas.length,
      icon: ShoppingBagIcon,
      color: 'text-amalfi-turquoise'
    },
    {
      title: 'Estado de Caja',
      value: activeCashSession ? 'Abierta' : 'Cerrada',
      icon: ChartBarIcon,
      color: activeCashSession ? 'text-green-400' : 'text-red-400'
    }
  ]

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Dashboard</h2>
        <p className="text-gray-400">Resumen del sistema</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat, index) => (
          <Card key={index}>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-400">{stat.title}</p>
                <p className="text-2xl font-bold text-white">{stat.value}</p>
              </div>
              <stat.icon className={`h-8 w-8 ${stat.color}`} />
            </div>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card title="Mesas Recientes">
          <div className="space-y-2">
            {tables.slice(0, 5).map((table) => (
              <div key={table.id} className="flex justify-between items-center">
                <span>{table.name}</span>
                <span className={`
                  px-2 py-1 rounded text-xs
                  ${table.status === 'LIBRE' ? 'bg-gray-700 text-gray-300' :
                    table.status === 'OCUPADA' ? 'bg-orange-900 text-orange-300' :
                    'bg-amalfi-deep text-white'}
                `}>
                  {table.status}
                </span>
              </div>
            ))}
          </div>
        </Card>

        <Card title="Últimas Facturas">
          <div className="space-y-2">
            {facturas.slice(0, 5).map((factura) => (
              <div key={factura.id} className="flex justify-between items-center">
                <span>{factura.number}</span>
                <span className="text-green-400">${factura.total.toFixed(2)}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  )
}

export default Dashboard