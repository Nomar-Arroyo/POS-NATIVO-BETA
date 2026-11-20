import { useCallback } from 'react'
import { useStore } from '../store/store'
import storageService from '../services/storage/storageService'
import posService from '../services/pos/posService'
import { AccountItem, Factura, Pago, Product } from '../types'

export const usePOS = () => {
  const { products, currentUser } = useStore()

  const searchProducts = useCallback((query: string, category?: string) => {
    return posService.searchProducts(query, category)
  }, [])

  const getCategories = useCallback(() => {
    return posService.getCategories()
  }, [])

  const getPopularProducts = useCallback((limit?: number) => {
    return posService.getPopularProducts(limit)
  }, [])

  const getProductsByCategory = useCallback((category: string) => {
    return posService.getProductsByCategory(category)
  }, [])

  const calculateTotals = useCallback((items: AccountItem[]) => {
    return posService.calculateSaleTotals(items)
  }, [])

  const addItem = useCallback((
    currentItems: AccountItem[],
    product: Product,
    quantity: number = 1,
    notes?: string
  ): AccountItem[] => {
    if (!Number.isFinite(quantity) || quantity <= 0) {
      throw new Error('La cantidad debe ser un número mayor a 0')
    }

    if (!product.active || !product.available) {
      throw new Error(`Producto ${product.name} no está disponible`)
    }

    const existingItem = currentItems.find(item => item.productId === product.id)
    const newQuantity = (existingItem?.quantity || 0) + quantity
    if (product.stock !== undefined && newQuantity > product.stock) {
      throw new Error(
        `Stock insuficiente para ${product.name}. Solo hay ${product.stock} disponibles.`
      )
    }

    if (existingItem) {
      return currentItems.map(item =>
        item.id === existingItem.id
          ? {
              ...item,
              quantity: newQuantity,
              notes: notes ?? item.notes,
              product
            }
          : item
      )
    }

    const newItem: AccountItem = {
      id: `item-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      productId: product.id,
      product,
      quantity,
      unitPrice: product.price,
      notes,
      sent: false,
      cancelled: false
    }
    return [...currentItems, newItem]
  }, [])

  const updateItemQuantity = useCallback((
    items: AccountItem[],
    itemId: string,
    newQuantity: number
  ): AccountItem[] => {
    if (!Number.isFinite(newQuantity)) {
      throw new Error('La cantidad debe ser un número válido')
    }
    if (newQuantity <= 0) {
      return items.filter(item => item.id !== itemId)
    }

    return items.map(item =>
      item.id === itemId ? { ...item, quantity: newQuantity } : item
    )
  }, [])

  const removeItem = useCallback((
    items: AccountItem[],
    itemId: string
  ): AccountItem[] => {
    return items.filter(item => item.id !== itemId)
  }, [])

  const clearItems = useCallback((): AccountItem[] => [], [])

  const processSale = useCallback((
    items: AccountItem[],
    pagos: Pago[],
    customerRif?: string,
    customerName?: string
  ): Factura => {
    if (!currentUser) {
      throw new Error('Debe seleccionar un usuario para procesar la venta')
    }

    try {
      return posService.processSale(
        items,
        pagos,
        currentUser.id,
        customerRif,
        customerName
      )
    } finally {
      useStore.setState({
        products: storageService.getProducts(),
        orders: storageService.getOrders(),
        facturas: storageService.getFacturas(),
        auditLogs: storageService.getAuditLogs()
      })
    }
  }, [currentUser])

  return {
    products,
    searchProducts,
    getCategories,
    getPopularProducts,
    getProductsByCategory,
    calculateTotals,
    addItem,
    updateItemQuantity,
    removeItem,
    clearItems,
    processSale
  }
}

export default usePOS
