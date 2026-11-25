import React, { useMemo, useState } from 'react'
import { usePOS } from '../../hooks/usePOS'
import { useStore } from '../../store/store'
import { AccountItem, Pago, Product } from '../../types'
import ProductGridPOS from './ProductGridPOS'
import POSTicket from './POSTicket'
import POSPaymentModal from '../../components/modals/POSPaymentModal'
import Input from '../../components/common/Input'
import Select from '../../components/common/Select'
import Card from '../../components/common/Card'
import Badge from '../../components/common/Badge'
import { MagnifyingGlassIcon, ShoppingBagIcon } from '@/components/common/Icon'

const Pos: React.FC = () => {
  const {
    searchProducts,
    getCategories,
    getPopularProducts,
    addItem,
    updateItemQuantity,
    removeItem,
    clearItems,
    calculateTotals,
    processSale
  } = usePOS()
  const { config, addNotification } = useStore()

  const [currentItems, setCurrentItems] = useState<AccountItem[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('Todas')
  const [showPaymentModal, setShowPaymentModal] = useState(false)

  const filteredProducts = useMemo(() => {
    if (searchTerm.trim() || selectedCategory !== 'Todas') {
      return searchProducts(
        searchTerm,
        selectedCategory !== 'Todas' ? selectedCategory : undefined
      )
    }
    return getPopularProducts(12)
  }, [searchTerm, selectedCategory, searchProducts, getPopularProducts])

  const categories = ['Todas', ...getCategories()]
  const totals = calculateTotals(currentItems)

  const handleAddProduct = (product: Product) => {
    try {
      setCurrentItems(items => addItem(items, product))
      addNotification({
        type: 'success',
        message: `${product.name} agregado`
      })
    } catch (error) {
      addNotification({
        type: 'error',
        message: error instanceof Error
          ? error.message
          : 'No se pudo agregar el producto'
      })
    }
  }

  const handleUpdateQuantity = (itemId: string, quantity: number) => {
    try {
      setCurrentItems(items => updateItemQuantity(items, itemId, quantity))
    } catch (error) {
      addNotification({
        type: 'error',
        message: error instanceof Error
          ? error.message
          : 'No se pudo actualizar la cantidad'
      })
    }
  }

  const handleRemoveItem = (itemId: string) => {
    setCurrentItems(items => removeItem(items, itemId))
  }

  const handleClearSale = () => {
    if (confirm('¿Está seguro de limpiar la venta actual?')) {
      setCurrentItems(clearItems())
    }
  }

  const handleProceedToPayment = () => {
    if (currentItems.length === 0) {
      addNotification({
        type: 'warning',
        message: 'No hay artículos en la venta'
      })
      return
    }
    setShowPaymentModal(true)
  }

  const handlePaymentSubmit = async (
    pagos: Pago[],
    customerRif?: string,
    customerName?: string
  ): Promise<boolean> => {
    try {
      const factura = processSale(
        currentItems,
        pagos,
        customerRif,
        customerName
      )
      addNotification({
        type: 'success',
        message: `Venta procesada correctamente. Factura ${factura.number}`
      })
      setCurrentItems(clearItems())
      setShowPaymentModal(false)
      return true
    } catch (error) {
      addNotification({
        type: 'error',
        message: error instanceof Error
          ? error.message
          : 'Error al procesar la venta'
      })
      return false
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="flex items-center text-2xl font-bold text-white">
            <ShoppingBagIcon className="h-6 w-6 mr-2 text-amalfi-turquoise" />
            POS - Venta Directa
          </h2>
          <p className="text-gray-400">
            Realice ventas rápidas sin necesidad de mesa
          </p>
        </div>

        <div className="flex items-center space-x-2">
          <Badge variant="info" size="sm">
            {totals.itemsCount} artículos
          </Badge>
          <Badge variant="warning" size="sm">
            ${totals.total.toFixed(2)}
          </Badge>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <Card title="Buscador de Productos">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="md:col-span-2">
                <Input
                  placeholder="Buscar producto por nombre..."
                  value={searchTerm}
                  onChange={event => setSearchTerm(event.target.value)}
                  leftIcon={<MagnifyingGlassIcon className="h-5 w-5" />}
                />
              </div>
              <Select
                label="Categoría"
                options={categories.map(category => ({
                  value: category,
                  label: category
                }))}
                value={selectedCategory}
                onChange={event => setSelectedCategory(event.target.value)}
              />
            </div>
          </Card>

          <Card title="Catálogo de Productos">
            <ProductGridPOS
              products={filteredProducts}
              onAddProduct={handleAddProduct}
              searchTerm={searchTerm}
              selectedCategory={selectedCategory}
            />
          </Card>
        </div>

        <div className="space-y-6">
          <POSTicket
            items={currentItems}
            subtotalUSD={totals.subtotal}
            iva={totals.iva}
            igtf={totals.igtf}
            totalUSD={totals.total}
            exchangeRate={config.exchangeRate}
            onUpdateQuantity={handleUpdateQuantity}
            onRemoveItem={handleRemoveItem}
            onProceedToPayment={handleProceedToPayment}
            onClearSale={handleClearSale}
          />
        </div>
      </div>

      <POSPaymentModal
        isOpen={showPaymentModal}
        onClose={() => setShowPaymentModal(false)}
        totalUSD={totals.total}
        totalBs={totals.total * config.exchangeRate}
        onSubmit={handlePaymentSubmit}
      />
    </div>
  )
}

export default Pos
