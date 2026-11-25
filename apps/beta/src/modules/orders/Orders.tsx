import React, { useState } from 'react'
import { useOrders } from '../../hooks/useOrders'
import KitchenOrders from './KitchenOrders'
import BarOrders from './BarOrders'
import Select from '../../components/common/Select'
import Card from '../../components/common/Card'
import Badge from '../../components/common/Badge'
import { 
  ClockIcon,
  FireIcon,
  CheckCircleIcon
} from '@/components/common/Icon'

const Orders: React.FC = () => {
  const { 
    orders, 
    getStats, 
    kitchenOrders, 
    barOrders 
  } = useOrders()

  const [activeTab, setActiveTab] = useState<'general' | 'cocina' | 'barra'>('general')
  const [filterStation, setFilterStation] = useState('todas')

  const stats = getStats()

  const tabs = [
    { id: 'general', label: 'General', count: orders.length },
    { id: 'cocina', label: 'Cocina', count: kitchenOrders.length },
    { id: 'barra', label: 'Barra', count: barOrders.length }
  ]

  const stationOptions = [
    { value: 'todas', label: 'Todas las estaciones' },
    { value: 'COCINA', label: 'Cocina' },
    { value: 'BARRA', label: 'Barra' }
  ]

  const renderGeneralTab = () => (
    <div className="space-y-6">
      {/* Estadísticas */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-amalfi-turquoise">{stats.total}</div>
            <div className="text-xs text-gray-400">Total Órdenes</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-yellow-400">{stats.pending}</div>
            <div className="text-xs text-gray-400">Pendientes</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-amalfi-turquoise">{stats.inPreparation}</div>
            <div className="text-xs text-gray-400">En Preparación</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-green-400">{stats.delivered}</div>
            <div className="text-xs text-gray-400">Entregadas</div>
          </div>
        </Card>
      </div>

      {/* Tiempo promedio de preparación */}
      <Card title="Rendimiento de Cocina">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="text-center">
            <ClockIcon className="h-8 w-8 text-amalfi-turquoise mx-auto mb-2" />
            <div className="text-lg font-bold text-white">
              {stats.averagePreparationTime.toFixed(1)} min
            </div>
            <div className="text-xs text-gray-400">
              Tiempo promedio
            </div>
          </div>
          <div className="text-center">
            <FireIcon className="h-8 w-8 text-amalfi-turquoise mx-auto mb-2" />
            <div className="text-lg font-bold text-white">
              {stats.byStation.COCINA || 0}
            </div>
            <div className="text-xs text-gray-400">
              Órdenes Cocina
            </div>
          </div>
          <div className="text-center">
            <CheckCircleIcon className="h-8 w-8 text-green-400 mx-auto mb-2" />
            <div className="text-lg font-bold text-white">
              {stats.byStation.BARRA || 0}
            </div>
            <div className="text-xs text-gray-400">
              Órdenes Barra
            </div>
          </div>
        </div>
      </Card>

      {/* Órdenes recientes */}
      <Card title="Órdenes Recientes">
        <div className="space-y-3">
          {orders.slice(0, 5).map((order) => (
            <div key={order.id} className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
              <div className="flex items-center space-x-3">
                <div className={`
                  w-3 h-3 rounded-full
                  ${order.station === 'COCINA' ? 'bg-blue-500' : 'bg-orange-500'}
                `}></div>
                <div>
                  <div className="font-medium text-white">{order.orderNumber}</div>
                  <div className="text-xs text-gray-400">
                    Mesa {order.tableId} • {order.station}
                  </div>
                </div>
              </div>
              <div className="text-right">
                <Badge 
                  variant={
                    order.status === 'pendiente' ? 'warning' :
                    order.status === 'en preparación' ? 'info' :
                    order.status === 'listo' ? 'success' : 'default'
                  }
                  size="sm"
                >
                  {order.status}
                </Badge>
                <div className="text-xs text-gray-400 mt-1">
                  {new Date(order.createdAt).toLocaleTimeString()}
                </div>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  )

  return (
    <div className="space-y-6">
      {/* Header con pestañas */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Comandas</h2>
          <p className="text-gray-400">Gestiona todas las órdenes del sistema</p>
        </div>

        <div className="flex items-center space-x-4">
          <Select
            options={stationOptions}
            value={filterStation}
            onChange={(e) => setFilterStation(e.target.value)}
            className="w-48"
          />
        </div>
      </div>

      {/* Pestañas */}
      <div className="flex space-x-1 bg-gray-800 p-1 rounded-lg">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`
              flex-1 py-2 px-4 rounded-lg font-medium transition-colors
              ${activeTab === tab.id
                ? 'bg-amalfi-deep text-white'
                : 'text-gray-300 hover:bg-gray-700'
              }
            `}
          >
            {tab.label}
            <span className="ml-2 bg-black bg-opacity-20 px-2 rounded-full text-sm">
              {tab.count}
            </span>
          </button>
        ))}
      </div>

      {/* Contenido de pestañas */}
      {activeTab === 'general' && renderGeneralTab()}
      {activeTab === 'cocina' && <KitchenOrders />}
      {activeTab === 'barra' && <BarOrders />}
    </div>
  )
}

export default Orders