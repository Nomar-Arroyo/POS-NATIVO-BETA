import storageService from '../storage/storageService'
import { AccountItem, Table, TableSession } from '../../types'
import auditService from '../audit/auditService'
import calculationService from '../calculations/calculationService'

class TableService {
  getTables(): Table[] {
    return storageService.getTables()
  }

  getTable(id: string): Table | undefined {
    return storageService.getTable(id)
  }

  getTablesByStatus(status: Table['status']): Table[] {
    return this.getTables().filter(table => table.status === status)
  }

  getFreeTables(): Table[] {
    return this.getTablesByStatus('LIBRE')
  }

  getOccupiedTables(): Table[] {
    return this.getTablesByStatus('OCUPADA')
  }

  getPreCuentaTables(): Table[] {
    return this.getTablesByStatus('PRECUENTA EMITIDA')
  }

  openTable(tableId: string, userId: string): TableSession {
    const table = this.getTable(tableId)
    if (!table) {
      throw new Error(`Mesa no encontrada: ${tableId}`)
    }

    if (table.status !== 'LIBRE') {
      throw new Error(`La mesa ${table.name} no está libre`)
    }

    const newSession: TableSession = {
      sessionId: `session-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      tableId,
      items: [],
      precuentaGenerated: false,
      totalUSD: 0,
      totalBs: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, {
      status: 'OCUPADA',
      currentSession: newSession
    })

    void auditService.logTableAction('ABRIR', tableId, {
      sessionId: newSession.sessionId,
      userId
    })

    return newSession
  }

  closeTable(tableId: string): boolean {
    const table = this.getTable(tableId)
    if (!table) {
      throw new Error(`Mesa no encontrada: ${tableId}`)
    }

    storageService.updateTable(tableId, {
      status: 'LIBRE',
      currentSession: undefined
    })

    void auditService.logTableAction('CERRAR', tableId, {
      previousStatus: table.status
    })

    return true
  }

  addItemToTable(
    tableId: string,
    productId: string,
    quantity: number = 1,
    notes?: string
  ): AccountItem {
    const table = this.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const product = storageService.getProduct(productId)
    if (!product) {
      throw new Error(`Producto no encontrado: ${productId}`)
    }

    if (!product.active || !product.available) {
      throw new Error(`Producto ${product.name} no está disponible`)
    }

    if (quantity <= 0) {
      throw new Error('La cantidad debe ser mayor a 0')
    }

    if (product.stock !== undefined && product.stock < quantity) {
      throw new Error(
        `Stock insuficiente para ${product.name}. Solo hay ${product.stock} disponibles.`
      )
    }

    const newItem: AccountItem = {
      id: `item-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      productId,
      quantity,
      unitPrice: product.price,
      notes,
      sent: false,
      cancelled: false
    }

    const updatedItems = [...table.currentSession.items, newItem]
    const totalUSD = calculationService.calculateSubtotal(updatedItems)
    const totalBs = calculationService.convertUSDToBs(
      totalUSD,
      storageService.getConfig().exchangeRate
    )
    const updatedSession: TableSession = {
      ...table.currentSession,
      items: updatedItems,
      totalUSD,
      totalBs,
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, { currentSession: updatedSession })

    void auditService.logTableAction('AGREGAR', tableId, {
      productId,
      productName: product.name,
      quantity,
      totalUSD
    })

    return newItem
  }

  updateItemQuantity(
    tableId: string,
    itemId: string,
    newQuantity: number
  ): AccountItem | null {
    const table = this.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    if (newQuantity < 0) {
      throw new Error('La cantidad no puede ser negativa')
    }

    const item = table.currentSession.items.find(currentItem => currentItem.id === itemId)
    if (!item) {
      throw new Error(`Artículo no encontrado: ${itemId}`)
    }

    if (newQuantity === 0) {
      this.removeItemFromTable(tableId, itemId)
      return null
    }

    const updatedItems = table.currentSession.items.map(currentItem =>
      currentItem.id === itemId
        ? { ...currentItem, quantity: newQuantity }
        : currentItem
    )
    const totalUSD = calculationService.calculateSubtotal(updatedItems)
    const totalBs = calculationService.convertUSDToBs(
      totalUSD,
      storageService.getConfig().exchangeRate
    )
    const updatedSession: TableSession = {
      ...table.currentSession,
      items: updatedItems,
      totalUSD,
      totalBs,
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, { currentSession: updatedSession })

    void auditService.logTableAction('ACTUALIZAR', tableId, {
      itemId,
      oldQuantity: item.quantity,
      newQuantity
    })

    return { ...item, quantity: newQuantity }
  }

  removeItemFromTable(tableId: string, itemId: string): boolean {
    const table = this.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const item = table.currentSession.items.find(currentItem => currentItem.id === itemId)
    if (!item) {
      throw new Error(`Artículo no encontrado: ${itemId}`)
    }

    const updatedItems = table.currentSession.items.filter(
      currentItem => currentItem.id !== itemId
    )
    const totalUSD = calculationService.calculateSubtotal(updatedItems)
    const totalBs = calculationService.convertUSDToBs(
      totalUSD,
      storageService.getConfig().exchangeRate
    )
    const updatedSession: TableSession = {
      ...table.currentSession,
      items: updatedItems,
      totalUSD,
      totalBs,
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, { currentSession: updatedSession })

    void auditService.logTableAction('ELIMINAR', tableId, {
      itemId,
      productId: item.productId,
      quantity: item.quantity
    })

    return true
  }

  sendOrder(tableId: string): string[] {
    const table = this.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const unsentItems = table.currentSession.items.filter(
      item => !item.sent && !item.cancelled
    )
    if (unsentItems.length === 0) {
      throw new Error('No hay artículos nuevos para enviar')
    }

    const updatedItems = table.currentSession.items.map(item =>
      unsentItems.some(unsentItem => unsentItem.id === item.id)
        ? { ...item, sent: true }
        : item
    )
    const updatedSession: TableSession = {
      ...table.currentSession,
      items: updatedItems,
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, { currentSession: updatedSession })

    return unsentItems.map(item => item.id)
  }

  markAllAsSent(tableId: string): void {
    const table = this.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const updatedItems = table.currentSession.items.map(item => ({
      ...item,
      sent: true
    }))
    const updatedSession: TableSession = {
      ...table.currentSession,
      items: updatedItems,
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, { currentSession: updatedSession })
  }

  generatePreCuenta(tableId: string): {
    precuentaId: string
    ticketHtml: string
  } {
    const table = this.getTable(tableId)
    if (!table || !table.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const session = table.currentSession
    const precuentaId = `pre-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
    const updatedSession: TableSession = {
      ...session,
      precuentaGenerated: true,
      updatedAt: new Date()
    }

    storageService.updateTable(tableId, {
      status: 'PRECUENTA EMITIDA',
      currentSession: updatedSession
    })

    const ticketHtml = this.generateTicketHtml(table, session)
    void auditService.logTableAction('PRECUENTA', tableId, {
      precuentaId,
      totalUSD: session.totalUSD,
      totalBs: session.totalBs
    })

    return { precuentaId, ticketHtml }
  }

  private generateTicketHtml(table: Table, session: TableSession): string {
    const config = storageService.getConfig()
    const itemsHtml = session.items.map(item => {
      const product = storageService.getProduct(item.productId)
      const productName = product?.name || 'Producto'
      const total = item.quantity * item.unitPrice

      return `
        <tr>
          <td>${item.quantity}x</td>
          <td>${productName}</td>
          <td>$${item.unitPrice.toFixed(2)}</td>
          <td>$${total.toFixed(2)}</td>
        </tr>
      `
    }).join('')

    return `
      <div class="ticket">
        <h3>${config.establishmentName}</h3>
        <p>RIF: ${config.taxId}</p>
        <p>Mesa: ${table.name}</p>
        <p>Fecha: ${new Date().toLocaleString()}</p>
        <hr>
        <table>
          <thead>
            <tr>
              <th>Cant</th>
              <th>Producto</th>
              <th>P.U.</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            ${itemsHtml}
          </tbody>
        </table>
        <hr>
        <div class="totals">
          <p>Subtotal: $${session.totalUSD.toFixed(2)}</p>
          <p><strong>TOTAL: $${session.totalUSD.toFixed(2)} / Bs. ${session.totalBs.toFixed(2)}</strong></p>
        </div>
        <p class="footer">REVISE SU CUENTA</p>
        <p class="footer">DOCUMENTO NO FISCAL</p>
      </div>
    `
  }

  getTableStats(): {
    total: number
    free: number
    occupied: number
    precuenta: number
    occupancyRate: number
  } {
    const total = this.getTables().length
    const free = this.getFreeTables().length
    const occupied = this.getOccupiedTables().length
    const precuenta = this.getPreCuentaTables().length
    const occupancyRate = total > 0 ? ((occupied + precuenta) / total) * 100 : 0

    return { total, free, occupied, precuenta, occupancyRate }
  }

  searchTables(query: string): Table[] {
    const searchTerm = query.toLowerCase().trim()
    if (!searchTerm) return this.getTables()

    return this.getTables().filter(table =>
      table.name.toLowerCase().includes(searchTerm) ||
      table.id.toLowerCase().includes(searchTerm)
    )
  }

  updateTablePosition(tableId: string, x: number, y: number): void {
    const table = this.getTable(tableId)
    if (!table) {
      throw new Error(`Mesa no encontrada: ${tableId}`)
    }

    storageService.updateTable(tableId, { position: { x, y } })
  }

  changeTableStatus(tableId: string, status: Table['status']): void {
    const table = this.getTable(tableId)
    if (!table) {
      throw new Error(`Mesa no encontrada: ${tableId}`)
    }

    const updates: Partial<Table> = { status }
    if (status === 'LIBRE') {
      updates.currentSession = undefined
    }

    storageService.updateTable(tableId, updates)
    void auditService.logTableAction('ESTADO', tableId, {
      oldStatus: table.status,
      newStatus: status
    })
  }
}

export default new TableService()
