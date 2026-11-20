import React, { useState } from 'react'
import { useOrders } from '../../hooks/useOrders'
import { Order, OrderItem } from '../../types'
import Card from '../../components/common/Card'
import Button from '../../components/common/Button'
import Badge from '../../components/common/Badge'
import Table from '../../components/common/Table'
import { 
  FireIcon, 
  CheckCircleIcon,
  XCircleIcon
} from '@/components/common/Icon'

const KitchenOrders: React.FC = () => {
  const { 
    kitchenOrders, 
    getElapsedTime, 
    updateStatus
  } = useOrders()

  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null)
  const [filterStatus, setFilterStatus] = useState('todas')

  // Filtrar órdenes
  const filteredOrders = React.useMemo(() => {
    if (filterStatus === 'todas') return kitchenOrders
    return kitchenOrders.filter(o => o.status === filterStatus)
  }, [kitchenOrders, filterStatus])

  const statusFilters = [
    { value: 'todas', label: 'Todas', count: kitchenOrders.length },
    { value: 'pendiente', label: 'Pendientes', count: kitchenOrders.filter(o => o.status === 'pendiente').length },
    { value: 'en preparación', label: 'En Preparación', count: kitchenOrders.filter(o => o.status === 'en preparación').length },
    { value: 'listo', label: 'Listos', count: kitchenOrders.filter(o => o.status === 'listo').length },
    { value: 'entregado', label: 'Entregados', count: kitchenOrders.filter(o => o.status === 'entregado').length }
  ]

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'pendiente':
        return <Badge variant="warning" size="sm">Pendiente</Badge>
      case 'en preparación':
        return <Badge variant="info" size="sm">En Preparación</Badge>
      case 'listo':
        return <Badge variant="success" size="sm">Listo</Badge>
      case 'entregado':
        return <Badge variant="default" size="sm">Entregado</Badge>
      case 'cancelado':
        return <Badge variant="error" size="sm">Cancelado</Badge>
      default:
        return <Badge variant="default" size="sm">{status}</Badge>
    }
  }

  const getPriorityIndicator = (order: Order) => {
    const elapsed = getElapsedTime(order)
    const minutes = parseInt(elapsed.split('m')[0]) || 0
    
    if (minutes > 30) {
      return <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
    } else if (minutes > 15) {
      return <div className="w-2 h-2 bg-yellow-500 rounded-full"></div>
    }
    return null
  }

  const handleStatusChange = (order: Order, newStatus: Order['status']) => {
    updateStatus(order.id, newStatus)
  }

  const columns = [
    {
      key: 'orderNumber' as keyof Order,
      header: 'Comanda',
      render: (orderNumber: string, order: Order) => (
        <div className="flex items-center space-x-2">
          {getPriorityIndicator(order)}
          <div>
            <div className="font-medium text-white">{orderNumber}</div>
            <div className="text-xs text-gray-400">
              Mesa {order.tableId}
            </div>
          </div>
        </div>
      )
    },
    {
      key: 'items' as keyof Order,
      header: 'Artículos',
      render: (items: OrderItem[]) => (
        <div className="text-sm">
          {items.map((item, index) => (
            <div key={index} className="text-gray-300">
              {item.quantity}x {item.productName}
            </div>
          ))}
        </div>
      ),
      className: 'max-w-xs'
    },
    {
      key: 'status' as keyof Order,
      header: 'Estado',
      render: (status: string) => getStatusBadge(status)
    },
    {
      key: 'createdAt' as keyof Order,
      header: 'Tiempo',
      render: (createdAt: Date, order: Order) => (
        <div className="text-center">
          <div className="text-sm font-medium">
            {getElapsedTime(order)}
          </div>
          <div className="text-xs text-gray-400">
            {new Date(createdAt).toLocaleTimeString()}
          </div>
        </div>
      )
    },
    {
      key: 'id' as keyof Order,
      header: 'Acciones',
      render: (id: string, order: Order) => (
        <div className="flex space-x-1">
          {order.status === 'pendiente' && (
            <Button
              size="sm"
              variant="primary"
              onClick={() => handleStatusChange(order, 'en preparación')}
            >
              <FireIcon className="h-4 w-4" />
            </Button>
          )}
          {order.status === 'en preparación' && (
            <Button
              size="sm"
              variant="success"
              onClick={() => handleStatusChange(order, 'listo')}
            >
              <CheckCircleIcon className="h-4 w-4" />
            </Button>
          )}
          {order.status === 'listo' && (
            <Button
              size="sm"
              variant="secondary"
              onClick={() => handleStatusChange(order, 'entregado')}
            >
              Entregar
            </Button>
          )}
          {order.status !== 'entregado' && order.status !== 'cancelado' && (
            <Button
              size="sm"
              variant="danger"
              onClick={() => {
                if (confirm(`¿Canceler la comanda ${order.orderNumber}?`)) {
                  handleStatusChange(order, 'cancelado')
                }
              }}
            >
              <XCircleIcon className="h-4 w-4" />
            </Button>
          )}
        </div>
      ),
      className: 'whitespace-nowrap'
    }
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Comandas de Cocina</h2>
          <p className="text-gray-400">Gestiona los pedidos de la cocina</p>
        </div>
        
        <div className="flex items-center space-x-2">
          <Badge variant="warning" size="sm">
            {kitchenOrders.filter(o => o.status === 'pendiente').length} Pendientes
          </Badge>
          <Badge variant="info" size="sm">
            {kitchenOrders.filter(o => o.status === 'en preparación').length} En preparación
          </Badge>
        </div>
      </div>

      {/* Filtros de estado */}
      <div className="flex flex-wrap gap-2">
        {statusFilters.map((filter) => (
          <button
            key={filter.value}
            onClick={() => setFilterStatus(filter.value)}
            className={`
              px-3 py-2 rounded-lg text-sm font-medium transition-colors
              ${filterStatus === filter.value
                ? 'bg-amalfi-deep text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }
            `}
          >
            {filter.label}
            <span className="ml-2 bg-black bg-opacity-20 px-2 rounded-full">
              {filter.count}
            </span>
          </button>
        ))}
      </div>

      {/* Lista de órdenes */}
      <Card title="Órdenes de Cocina">
        <Table
          data={filteredOrders}
          columns={columns}
          onRowClick={setSelectedOrder}
          emptyMessage="No hay comandas de cocina"
        />
      </Card>

      {/* Detalle de orden seleccionada */}
      {selectedOrder && (
        <Card title={`Comanda ${selectedOrder.orderNumber}`} actions={
          <Button size="sm" variant="secondary" onClick={() => setSelectedOrder(null)}>
            Cerrar
          </Button>
        }>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h4 className="font-medium text-white mb-3">Información General</h4>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Mesa:</span>
                  <span className="text-white">{selectedOrder.tableId}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Estado:</span>
                  {getStatusBadge(selectedOrder.status)}
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Hora envío:</span>
                  <span className="text-white">
                    {new Date(selectedOrder.createdAt).toLocaleTimeString()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Tiempo transcurrido:</span>
                  <span className="text-white">{getElapsedTime(selectedOrder)}</span>
                </div>
              </div>
            </div>

            <div>
              <h4 className="font-medium text-white mb-3">Artículos</h4>
              <div className="space-y-2">
                {selectedOrder.items.map((item, index) => (
                  <div key={index} className="flex justify-between items-center p-2 bg-gray-700 rounded">
                    <div>
                      <span className="font-medium text-white">
                        {item.quantity}x {item.productName}
                      </span>
                      {item.notes && (
                        <div className="text-xs text-gray-400">
                          Nota: {item.notes}
                        </div>
                      )}
                    </div>
                    <span className="text-amalfi-turquoise font-medium">
                      ${item.total.toFixed(2)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Card>
      )}
    </div>
  )
}

export default KitchenOrders