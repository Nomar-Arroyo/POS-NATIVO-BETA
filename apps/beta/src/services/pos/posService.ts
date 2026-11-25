import storageService from '../storage/storageService'
import { AccountItem, Factura, Order, Pago, Product } from '../../types'
import calculationService from '../calculations/calculationService'
import auditService from '../audit/auditService'

interface DirectSaleItemInput {
  productId: string
  quantity: number
  notes?: string
  unitPrice?: number
}

interface DirectSaleResult {
  saleId: string
  totalUSD: number
  totalBs: number
  items: AccountItem[]
}

class POSService {
  createDirectSale(
    items: DirectSaleItemInput[],
    userId: string
  ): DirectSaleResult {
    if (items.length === 0) {
      throw new Error('No hay artículos en la venta')
    }

    if (!userId.trim()) {
      throw new Error('Se requiere un usuario para registrar la venta')
    }

    const productsById = new Map<string, Product>()
    const quantitiesByProduct = new Map<string, number>()

    for (const item of items) {
      if (!Number.isFinite(item.quantity) || item.quantity <= 0) {
        throw new Error('La cantidad debe ser un número mayor a 0')
      }

      const product = storageService.getProduct(item.productId)
      if (!product) {
        throw new Error(`Producto no encontrado: ${item.productId}`)
      }
      if (!product.active || !product.available) {
        throw new Error(`Producto ${product.name} no está disponible`)
      }
      if (
        item.unitPrice !== undefined &&
        (!Number.isFinite(item.unitPrice) || item.unitPrice < 0)
      ) {
        throw new Error(`Precio inválido para ${product.name}`)
      }

      productsById.set(product.id, product)
      quantitiesByProduct.set(
        product.id,
        (quantitiesByProduct.get(product.id) || 0) + item.quantity
      )
    }

    for (const [productId, quantity] of quantitiesByProduct) {
      const product = productsById.get(productId)
      if (
        product?.stock !== undefined &&
        product.stock < quantity
      ) {
        throw new Error(
          `Stock insuficiente para ${product.name}. Solo hay ${product.stock} disponibles.`
        )
      }
    }

    const saleItems: AccountItem[] = items.map(item => {
      const product = productsById.get(item.productId)
      if (!product) {
        throw new Error(`Producto no encontrado: ${item.productId}`)
      }

      return {
        id: `item-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
        productId: product.id,
        product,
        quantity: item.quantity,
        unitPrice: item.unitPrice ?? product.price,
        notes: item.notes,
        sent: true,
        cancelled: false
      }
    })

    const subtotalUSD = calculationService.calculateSubtotal(saleItems)
    const config = storageService.getConfig()
    const invoiceTotals = calculationService.calculateTotalFactura(
      subtotalUSD,
      config.ivaRate,
      config.igtfRate
    )
    const totalBs = calculationService.convertUSDToBs(
      invoiceTotals.total,
      config.exchangeRate
    )
    const now = new Date()
    const order: Order = {
      id: `order-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      tableId: 'direct-sale',
      items: saleItems.map(item => ({
        productId: item.productId,
        productName: item.product?.name || 'Producto',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        notes: item.notes,
        total: item.quantity * item.unitPrice
      })),
      station: 'BARRA',
      status: 'entregado',
      createdAt: now,
      sentAt: now,
      deliveredAt: now,
      userId,
      orderNumber: `VD-${Date.now()}-${Math.random().toString(36).substr(2, 3).toUpperCase()}`
    }

    storageService.addOrder(order)

    for (const [productId, quantity] of quantitiesByProduct) {
      const product = productsById.get(productId)
      if (product?.stock !== undefined) {
        const remainingStock = product.stock - quantity
        storageService.updateProduct(productId, {
          stock: remainingStock,
          available: remainingStock > 0
        })
      }
    }

    void auditService.logOrderAction('ENVIAR', order.id, order.tableId, {
      orderNumber: order.orderNumber,
      totalUSD: invoiceTotals.total,
      itemsCount: saleItems.length
    }).catch((error: unknown) => {
      console.error('Error registrando auditoría de venta directa:', error)
    })

    return {
      saleId: order.id,
      totalUSD: invoiceTotals.total,
      totalBs,
      items: saleItems
    }
  }

  processDirectSalePayment(
    saleId: string,
    pagos: Pago[],
    customerRif?: string,
    customerName?: string
  ): Factura {
    const order = storageService.getOrders().find(candidate => candidate.id === saleId)
    if (!order || order.tableId !== 'direct-sale') {
      throw new Error(`Venta directa no encontrada: ${saleId}`)
    }

    if (storageService.getFacturas().some(factura => factura.orderId === saleId)) {
      throw new Error('Esta venta ya fue facturada')
    }

    const config = storageService.getConfig()
    const subtotal = calculationService.calculateSubtotal(
      order.items.map(item => ({
        id: `${order.id}-${item.productId}`,
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        notes: item.notes,
        sent: true,
        cancelled: false
      }))
    )
    const totals = calculationService.calculateTotalFactura(
      subtotal,
      config.ivaRate,
      config.igtfRate
    )

    this.validatePayments(pagos, totals.total, config.exchangeRate)

    const now = new Date()
    const factura: Factura = {
      id: `fact-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      orderId: order.id,
      number: `FAC-${Date.now()}-${Math.random().toString(36).substr(2, 3).toUpperCase()}`,
      controlNumber: calculationService.generateControlNumber(),
      tableId: 'direct-sale',
      items: order.items.map((item, index) => ({
        id: `${order.id}-item-${index + 1}`,
        productId: item.productId,
        product: storageService.getProduct(item.productId),
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        notes: item.notes,
        sent: true,
        cancelled: false
      })),
      subtotal,
      iva: totals.iva,
      igtf: totals.igtf,
      total: totals.total,
      payments: pagos,
      customerRif,
      customerName,
      createdAt: now,
      simulated: config.fiscalSimulation
    }

    storageService.addFactura(factura)

    void auditService.logPaymentAction('PAGO', factura.id, 'direct-sale', {
      factNumber: factura.number,
      total: factura.total,
      paymentsCount: pagos.length
    }).catch((error: unknown) => {
      console.error('Error registrando auditoría del pago de venta directa:', error)
    })

    return factura
  }

  processSale(
    items: AccountItem[],
    pagos: Pago[],
    userId: string,
    customerRif?: string,
    customerName?: string
  ): Factura {
    const config = storageService.getConfig()
    const subtotal = calculationService.calculateSubtotal(items)
    const totals = calculationService.calculateTotalFactura(
      subtotal,
      config.ivaRate,
      config.igtfRate
    )
    this.validatePayments(pagos, totals.total, config.exchangeRate)

    const sale = this.createDirectSale(
      items.map(item => ({
        productId: item.productId,
        quantity: item.quantity,
        notes: item.notes,
        unitPrice: item.unitPrice
      })),
      userId
    )
    return this.processDirectSalePayment(
      sale.saleId,
      pagos,
      customerRif,
      customerName
    )
  }

  searchProducts(query: string, category?: string): Product[] {
    let products = storageService.getProducts().filter(
      product => product.active && product.available &&
        (product.stock === undefined || product.stock > 0)
    )

    const searchTerm = query.toLowerCase().trim()
    if (searchTerm) {
      products = products.filter(product =>
        product.name.toLowerCase().includes(searchTerm) ||
        product.description.toLowerCase().includes(searchTerm) ||
        product.category.toLowerCase().includes(searchTerm)
      )
    }

    if (category && category !== 'Todas') {
      products = products.filter(product => product.category === category)
    }

    return products
  }

  getCategories(): string[] {
    return [...new Set(
      this.searchProducts('').map(product => product.category)
    )].sort()
  }

  getPopularProducts(limit: number = 8): Product[] {
    const safeLimit = Math.max(0, Math.floor(limit))
    return this.searchProducts('')
      .sort((a, b) => (b.stock ?? Number.MAX_SAFE_INTEGER) - (a.stock ?? Number.MAX_SAFE_INTEGER))
      .slice(0, safeLimit)
  }

  getProductsByCategory(category: string): Product[] {
    return this.searchProducts('', category)
  }

  calculateSaleTotals(items: AccountItem[]): {
    subtotal: number
    iva: number
    igtf: number
    total: number
    itemsCount: number
  } {
    const activeItems = items.filter(item => !item.cancelled)
    const subtotal = calculationService.calculateSubtotal(activeItems)
    const config = storageService.getConfig()
    const totals = calculationService.calculateTotalFactura(
      subtotal,
      config.ivaRate,
      config.igtfRate
    )
    const itemsCount = activeItems.reduce((sum, item) => sum + item.quantity, 0)

    return {
      subtotal,
      iva: totals.iva,
      igtf: totals.igtf,
      total: totals.total,
      itemsCount
    }
  }

  private validatePayments(
    pagos: Pago[],
    total: number,
    exchangeRate: number
  ): void {
    if (pagos.length === 0) {
      throw new Error('Debe registrar al menos un pago')
    }

    for (const pago of pagos) {
      if (!Number.isFinite(pago.amount) || pago.amount <= 0) {
        throw new Error('Todos los pagos deben tener un monto mayor a 0')
      }

      const expectedCurrency = pago.method === 'EFECTIVO Bs' ? 'Bs' : 'USD'
      if (pago.currency !== expectedCurrency) {
        throw new Error(`La moneda no corresponde al método ${pago.method}`)
      }
    }

    const validation = calculationService.validatePaymentComplete(
      total,
      pagos,
      exchangeRate
    )
    if (!validation.isValid) {
      throw new Error('El pago no cubre el total de la venta')
    }
  }
}

export default new POSService()
