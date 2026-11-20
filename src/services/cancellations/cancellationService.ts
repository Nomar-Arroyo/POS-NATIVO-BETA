import storageService from '../storage/storageService'
import {
  AccountItem,
  Cancellation,
  CANCELLATION_REASONS
} from '../../types'
import auditService from '../audit/auditService'
import calculationService from '../calculations/calculationService'

class CancellationService {
  getAvailableReasons(): string[] {
    return Object.values(CANCELLATION_REASONS)
  }

  async createCancellationRequest(
    type: Cancellation['type'],
    itemId: string,
    reason: string,
    customReason?: string,
    tableId?: string,
    orderId?: string
  ): Promise<Cancellation> {
    if (!reason.trim()) {
      throw new Error('Debe indicar el motivo de la anulación')
    }

    let productName = ''
    let quantity = 0
    let amount = 0
    let cancellationTableId = tableId
    let cancellationOrderId = orderId

    if (type === 'PRODUCT') {
      const product = storageService.getProduct(itemId)
      if (!product) throw new Error('Producto no encontrado')

      productName = product.name
      quantity = 1
      amount = product.price
    } else if (type === 'ORDER') {
      const order = storageService.getOrders().find(candidate => candidate.id === itemId)
      if (!order) throw new Error('Orden no encontrada')

      productName = `Orden ${order.orderNumber}`
      quantity = order.items.length
      amount = order.items.reduce((sum, item) => sum + item.total, 0)
      cancellationTableId = cancellationTableId || order.tableId
      cancellationOrderId = cancellationOrderId || order.id
    } else {
      const tables = storageService.getTables()
      let foundItem: AccountItem | undefined

      for (const table of tables) {
        if (cancellationTableId && table.id !== cancellationTableId) continue
        const item = table.currentSession?.items.find(candidate => candidate.id === itemId)
        if (!item) continue

        const product = storageService.getProduct(item.productId)
        productName = product?.name || 'Producto'
        quantity = item.quantity
        amount = item.quantity * item.unitPrice
        cancellationTableId = table.id
        foundItem = item
        break
      }

      if (!foundItem) throw new Error('Artículo no encontrado en una mesa')
    }

    const cancellation: Cancellation = {
      id: `cancel-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date(),
      user: auditService.getUser()?.name || 'Sistema',
      reason,
      customReason,
      type,
      itemId,
      productName,
      quantity,
      amount,
      tableId: cancellationTableId,
      orderId: cancellationOrderId,
      status: 'PENDING'
    }

    await auditService.logCancellation(cancellation)
    return cancellation
  }

  async approveCancellation(
    cancellationId: string,
    approvedBy: string
  ): Promise<Cancellation> {
    const cancellation = this.getCancellation(cancellationId)
    if (!cancellation) throw new Error('Anulación no encontrada')
    if (cancellation.status !== 'PENDING') {
      throw new Error('La solicitud de anulación ya fue resuelta')
    }

    const updatedCancellation: Cancellation = {
      ...cancellation,
      status: 'APPROVED',
      approvedBy,
      approvedAt: new Date()
    }

    await this.executeCancellation(updatedCancellation)
    await auditService.logAction('ANULACION_APROBADA', updatedCancellation, {
      tableId: cancellation.tableId,
      orderId: cancellation.orderId,
      category: 'ORDER',
      severity: 'WARNING'
    })

    return updatedCancellation
  }

  async rejectCancellation(
    cancellationId: string,
    rejectedBy: string,
    reason: string
  ): Promise<Cancellation> {
    const cancellation = this.getCancellation(cancellationId)
    if (!cancellation) throw new Error('Anulación no encontrada')
    if (cancellation.status !== 'PENDING') {
      throw new Error('La solicitud de anulación ya fue resuelta')
    }

    const updatedCancellation: Cancellation = {
      ...cancellation,
      status: 'REJECTED'
    }

    await auditService.logAction('ANULACION_RECHAZADA', {
      ...updatedCancellation,
      rejectedBy,
      rejectionReason: reason
    }, {
      tableId: cancellation.tableId,
      orderId: cancellation.orderId,
      category: 'ORDER',
      severity: 'WARNING'
    })

    return updatedCancellation
  }

  private async executeCancellation(cancellation: Cancellation): Promise<void> {
    switch (cancellation.type) {
      case 'PRODUCT':
        await this.cancelProduct(cancellation)
        break
      case 'ORDER':
        await this.cancelOrder(cancellation)
        break
      case 'ITEM':
        await this.cancelItem(cancellation)
        break
    }
  }

  private async cancelProduct(cancellation: Cancellation): Promise<void> {
    const product = storageService.getProduct(cancellation.itemId)
    if (!product) throw new Error('Producto no encontrado')

    storageService.updateProduct(cancellation.itemId, {
      active: false,
      available: false
    })

    await auditService.logProductAction('ELIMINAR', cancellation.itemId, {
      reason: cancellation.reason,
      cancelledBy: cancellation.user
    }, 'WARNING')
  }

  private async cancelOrder(cancellation: Cancellation): Promise<void> {
    const order = storageService.getOrders().find(
      candidate => candidate.id === cancellation.itemId
    )
    if (!order) throw new Error('Orden no encontrada')
    if (order.status === 'entregado') {
      throw new Error('No se puede anular una orden ya entregada')
    }

    storageService.updateOrder(cancellation.itemId, { status: 'cancelado' })

    await auditService.logOrderAction('CANCELAR', cancellation.itemId, order.tableId, {
      reason: cancellation.reason,
      orderNumber: order.orderNumber
    }, 'WARNING')
  }

  private async cancelItem(cancellation: Cancellation): Promise<void> {
    if (!cancellation.tableId) {
      throw new Error('La solicitud de anulación no identifica una mesa')
    }

    const table = storageService.getTable(cancellation.tableId)
    if (!table?.currentSession) {
      throw new Error('La mesa no tiene una sesión activa')
    }

    const item = table.currentSession.items.find(
      candidate => candidate.id === cancellation.itemId
    )
    if (!item) throw new Error('Artículo no encontrado en la sesión')

    const updatedItems = table.currentSession.items.map(candidate =>
      candidate.id === cancellation.itemId
        ? { ...candidate, cancelled: true }
        : candidate
    )
    const activeItems = updatedItems.filter(candidate => !candidate.cancelled)
    const totalUSD = calculationService.calculateSubtotal(activeItems)
    const totalBs = calculationService.convertUSDToBs(
      totalUSD,
      storageService.getConfig().exchangeRate
    )
    const updatedSession = {
      ...table.currentSession,
      items: updatedItems,
      totalUSD,
      totalBs,
      updatedAt: new Date()
    }

    storageService.updateTable(cancellation.tableId, {
      currentSession: updatedSession
    })

    await auditService.logTableAction('ANULACION', cancellation.tableId, {
      itemId: cancellation.itemId,
      productName: cancellation.productName,
      quantity: cancellation.quantity,
      reason: cancellation.reason
    }, 'WARNING')
  }

  private getCancellation(id: string): Cancellation | null {
    return this.getCancellationHistory().find(cancellation => cancellation.id === id) || null
  }

  getCancellationsByTable(tableId: string): Cancellation[] {
    return this.getCancellationHistory().filter(
      cancellation => cancellation.tableId === tableId
    )
  }

  getCancellationsByDateRange(startDate: Date, endDate: Date): Cancellation[] {
    return this.getCancellationHistory().filter(cancellation => {
      const timestamp = new Date(cancellation.timestamp)
      return timestamp >= startDate && timestamp <= endDate
    })
  }

  private getCancellationHistory(): Cancellation[] {
    const cancellationActions = new Set([
      'ANULACION',
      'ANULACION_APROBADA',
      'ANULACION_RECHAZADA'
    ])
    const latestById = new Map<string, { cancellation: Cancellation; loggedAt: number }>()

    for (const log of auditService.getAuditLogs()) {
      if (!cancellationActions.has(log.action)) continue
      const details = log.details as Partial<Cancellation> | null
      if (
        !details ||
        typeof details.id !== 'string' ||
        !details.timestamp ||
        !details.itemId ||
        !details.reason ||
        !details.status
      ) {
        continue
      }

      const loggedAt = new Date(log.timestamp).getTime()
      const previous = latestById.get(details.id)
      if (!previous || loggedAt >= previous.loggedAt) {
        latestById.set(details.id, {
          cancellation: details as Cancellation,
          loggedAt
        })
      }
    }

    return [...latestById.values()]
      .map(entry => entry.cancellation)
      .sort((a, b) =>
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      )
  }
}

export default new CancellationService()
