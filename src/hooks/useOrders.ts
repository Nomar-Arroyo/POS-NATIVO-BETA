import { useMemo } from 'react'
import { useStore } from '../store/store'
import orderService from '../services/orders/orderService'
import { Order } from '../types'

export const useOrders = () => {
  const { 
    orders, 
    setOrders, 
    updateOrder,
    addNotification
  } = useStore()

  const actions = useMemo(() => ({
    // Obtener todas las órdenes
    getAll: () => orders,

    // Obtener por ID
    getOrder: (id: string) => orders.find(o => o.id === id),

    // Obtener por estación
    getByStation: (station: 'COCINA' | 'BARRA') => 
      orderService.getOrdersByStation(station),

    // Obtener por estado
    getByStatus: (status: Order['status']) => 
      orderService.getOrdersByStatus(status),

    // Obtener pendientes
    getPending: (station: 'COCINA' | 'BARRA') => 
      orderService.getPendingOrders(station),

    // Enviar comanda desde mesa
    sendOrderFromTable: (tableId: string, userId: string, itemIds?: string[]) => {
      try {
        const newOrders = orderService.sendOrderFromTable(tableId, userId, itemIds)
        
        setOrders(orderService.getOrders())

        addNotification({
          type: 'success',
          message: `Comanda enviada: ${newOrders.map(o => o.orderNumber).join(', ')}`
        })

        return { success: true, orders: newOrders }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Actualizar estado
    updateStatus: (orderId: string, status: Order['status']) => {
      try {
        const updatedOrder = orderService.updateOrderStatus(orderId, status)
        if (updatedOrder) {
          updateOrder(orderId, { status })
          
          const statusMessages = {
            'pendiente': 'Pendiente',
            'en preparación': 'En preparación',
            'listo': 'Listo',
            'entregado': 'Entregado',
            'cancelado': 'Cancelado'
          }

          addNotification({
            type: status === 'cancelado' ? 'warning' : 'success',
            message: `Orden ${updatedOrder.orderNumber}: ${statusMessages[status]}`
          })
        }
        return { success: true, order: updatedOrder }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Cancelar orden
    cancelOrder: (orderId: string, reason: string) => {
      try {
        const updatedOrder = orderService.cancelOrder(orderId, reason)
        if (updatedOrder) {
          updateOrder(orderId, { status: 'cancelado' })
          return { success: true, order: updatedOrder }
        }
        throw new Error('Orden no encontrada')
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Buscar órdenes
    search: (query: string) => orderService.searchOrders(query),

    // Estadísticas
    getStats: () => orderService.getOrderStats(),

    // Tiempo transcurrido
    getElapsedTime: (order: Order) => orderService.getElapsedTime(order)
  }), [orders, setOrders, updateOrder, addNotification])

  // Órdenes por estación
  const kitchenOrders = useMemo(() => 
    actions.getByStation('COCINA'), [actions]
  )

  const barOrders = useMemo(() => 
    actions.getByStation('BARRA'), [actions]
  )

  // Órdenes pendientes
  const pendingKitchen = useMemo(() => 
    actions.getPending('COCINA'), [actions]
  )

  const pendingBar = useMemo(() => 
    actions.getPending('BARRA'), [actions]
  )

  return {
    orders,
    kitchenOrders,
    barOrders,
    pendingKitchen,
    pendingBar,
    ...actions
  }
}

export default useOrders