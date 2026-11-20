import storageService from '../storage/storageService'
import { AccountItem, Order, OrderItem, TableSession } from '../../types'
import { ORDER_STATUS } from '../../types/orders'
import auditService from '../audit/auditService'

class OrderService {
  getOrders(): Order[] {
    return storageService.getOrders()
  }

  getOrder(id: string): Order | undefined {
    return this.getOrders().find(order => order.id === id)
  }

  getOrdersByStation(station: 'COCINA' | 'BARRA'): Order[] {
    return this.getOrders().filter(order => order.station === station)
  }

  getOrdersByStatus(status: Order['status']): Order[] {
    return this.getOrders().filter(order => order.status === status)
  }

  getPendingOrders(station: 'COCINA' | 'BARRA'): Order[] {
    return this.getOrdersByStation(station).filter(
      order =>
        order.status === ORDER_STATUS.PENDIENTE ||
        order.status === ORDER_STATUS.EN_PREPARACION
    )
  }

  getOrdersByTable(tableId: string): Order[] {
    return this.getOrders().filter(order => order.tableId === tableId)
  }

  private generateOrderNumber(): string {
    const timestamp = Date.now()
    const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0')
    return `CMD-${timestamp}-${random}`
  }

  sendOrderFromTable(
    tableId: string,
    userId: string,
    itemIds?: string[]
  ): Order[] {
    const table = storageService.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const itemsToSend = table.currentSession.items.filter(item =>
      !item.sent &&
      !item.cancelled &&
      (!itemIds || itemIds.includes(item.id))
    )
    if (itemsToSend.length === 0) {
      throw new Error('No hay artículos nuevos para enviar')
    }

    const itemsByStation: Record<'COCINA' | 'BARRA', AccountItem[]> = {
      COCINA: [],
      BARRA: []
    }

    for (const item of itemsToSend) {
      const product = storageService.getProduct(item.productId)
      if (!product) {
        throw new Error(`Producto no encontrado: ${item.productId}`)
      }
      itemsByStation[product.station].push(item)
    }

    const orders: Order[] = []
    for (const station of ['COCINA', 'BARRA'] as const) {
      const stationItems = itemsByStation[station]
      if (stationItems.length > 0) {
        orders.push(this.createOrder(tableId, stationItems, station, userId))
      }
    }

    this.markItemsAsSent(tableId, itemsToSend.map(item => item.id))

    for (const order of orders) {
      void auditService.logOrderAction('ENVIAR', order.id, tableId, {
        orderNumber: order.orderNumber,
        station: order.station,
        itemsCount: order.items.length
      }).catch((error: unknown) => {
        console.error('Error registrando auditoría de envío de orden:', error)
      })
    }

    return orders
  }

  private createOrder(
    tableId: string,
    items: AccountItem[],
    station: 'COCINA' | 'BARRA',
    userId: string
  ): Order {
    const table = storageService.getTable(tableId)
    if (!table) {
      throw new Error(`Mesa no encontrada: ${tableId}`)
    }

    const orderItems: OrderItem[] = items.map(item => {
      const product = storageService.getProduct(item.productId)
      if (!product) {
        throw new Error(`Producto no encontrado: ${item.productId}`)
      }

      const total = Math.round(item.quantity * item.unitPrice * 100) / 100
      return {
        productId: item.productId,
        productName: product.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        notes: item.notes,
        total
      }
    })

    const now = new Date()
    const newOrder: Order = {
      id: `order-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      tableId,
      items: orderItems,
      station,
      status: ORDER_STATUS.PENDIENTE,
      createdAt: now,
      sentAt: now,
      userId,
      orderNumber: this.generateOrderNumber()
    }

    storageService.addOrder(newOrder)
    return newOrder
  }

  private markItemsAsSent(tableId: string, itemIds: string[]): void {
    const table = storageService.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const updatedItems = table.currentSession.items.map(item =>
      itemIds.includes(item.id) ? { ...item, sent: true } : item
    )
    const updatedSession: TableSession = {
      ...table.currentSession,
      items: updatedItems,
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, { currentSession: updatedSession })
  }

  updateOrderStatus(orderId: string, status: Order['status']): Order {
    const order = this.getOrder(orderId)
    if (!order) {
      throw new Error(`Orden no encontrada: ${orderId}`)
    }

    const updates: Partial<Order> = { status }
    const now = new Date()
    switch (status) {
      case ORDER_STATUS.LISTO:
        updates.readyAt = now
        break
      case ORDER_STATUS.ENTREGADO:
        updates.deliveredAt = now
        break
    }

    storageService.updateOrder(orderId, updates)
    void auditService.logOrderAction('ESTADO', orderId, order.tableId, {
      orderNumber: order.orderNumber,
      oldStatus: order.status,
      newStatus: status
    }).catch((error: unknown) => {
      console.error('Error registrando auditoría de cambio de estado:', error)
    })

    return { ...order, ...updates }
  }

  cancelOrder(orderId: string, reason: string): Order {
    const order = this.getOrder(orderId)
    if (!order) {
      throw new Error(`Orden no encontrada: ${orderId}`)
    }
    if (order.status === ORDER_STATUS.ENTREGADO) {
      throw new Error('No se puede cancelar una orden ya entregada')
    }

    const updatedOrder = this.updateOrderStatus(orderId, ORDER_STATUS.CANCELADO)
    void auditService.logOrderAction('CANCELAR', orderId, order.tableId, {
      orderNumber: order.orderNumber,
      reason
    }).catch((error: unknown) => {
      console.error('Error registrando auditoría de cancelación de orden:', error)
    })

    return updatedOrder
  }

  resendOrderItems(tableId: string, userId: string): Order[] {
    return this.sendOrderFromTable(tableId, userId)
  }

  getElapsedTime(order: Order): string {
    const startTime = new Date(order.sentAt ?? order.createdAt).getTime()
    const diff = Math.max(0, Date.now() - startTime)
    const minutes = Math.floor(diff / 60000)
    const seconds = Math.floor((diff % 60000) / 1000)

    if (minutes < 1) return `${seconds}s`
    if (minutes < 60) return `${minutes}m ${seconds}s`

    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60
    return `${hours}h ${remainingMinutes}m`
  }

  getOrderStats(): {
    total: number
    pending: number
    inPreparation: number
    ready: number
    delivered: number
    cancelled: number
    byStation: Record<string, number>
    averagePreparationTime: number
  } {
    const orders = this.getOrders()
    const stats = {
      total: orders.length,
      pending: orders.filter(order => order.status === ORDER_STATUS.PENDIENTE).length,
      inPreparation: orders.filter(order => order.status === ORDER_STATUS.EN_PREPARACION).length,
      ready: orders.filter(order => order.status === ORDER_STATUS.LISTO).length,
      delivered: orders.filter(order => order.status === ORDER_STATUS.ENTREGADO).length,
      cancelled: orders.filter(order => order.status === ORDER_STATUS.CANCELADO).length,
      byStation: {} as Record<string, number>,
      averagePreparationTime: 0
    }

    for (const order of orders) {
      stats.byStation[order.station] = (stats.byStation[order.station] || 0) + 1
    }

    const completedOrders = orders.filter(order => order.readyAt && order.sentAt)
    if (completedOrders.length > 0) {
      const totalTime = completedOrders.reduce((sum, order) => {
        return sum +
          new Date(order.readyAt!).getTime() -
          new Date(order.sentAt!).getTime()
      }, 0)
      stats.averagePreparationTime = totalTime / completedOrders.length / 60000
    }

    return stats
  }

  searchOrders(query: string): Order[] {
    const searchTerm = query.toLowerCase().trim()
    if (!searchTerm) return this.getOrders()

    return this.getOrders().filter(order =>
      order.orderNumber.toLowerCase().includes(searchTerm) ||
      order.tableId.toLowerCase().includes(searchTerm) ||
      order.items.some(item =>
        item.productName.toLowerCase().includes(searchTerm)
      )
    )
  }

  cleanupOldOrders(daysToKeep: number = 7): number {
    const cutoffTime = Date.now() - daysToKeep * 24 * 60 * 60 * 1000
    return this.getOrders().filter(order =>
      new Date(order.createdAt).getTime() < cutoffTime &&
      order.status === ORDER_STATUS.ENTREGADO
    ).length
  }
}

export default new OrderService()
