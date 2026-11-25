import React, { useState } from 'react'
import { useTables } from '../../hooks/useTables'
import { useProducts } from '../../hooks/useProducts'
import { useExchangeRate } from '../../hooks/useExchangeRate'
import { usePrecuentas } from '../../hooks/usePrecuentas'
import { useStore } from '../../store/store'
import { AccountItem } from '../../types'
import ProductSearch from '../../components/products/ProductSearch'
import SplitConfigModal from '../../components/modals/SplitConfigModal'
import SplitManager from '../split/SplitManager'
import ProductGrid from './ProductGrid'
import CurrentOrder from './CurrentOrder'
import PreCuentaManager from './PreCuentaManager'
import CancellationModal from '../../components/modals/CancellationModal'
import Button from '../../components/common/Button'
import Card from '../../components/common/Card'
import Badge from '../../components/common/Badge'
import { 
  ArrowLeftIcon,
  PaperAirplaneIcon,
  ReceiptRefundIcon,
  UsersIcon,
  XMarkIcon
} from '@/components/common/Icon'

interface TableSessionProps {
  tableId: string
  onClose: () => void
}

const TableSession: React.FC<TableSessionProps> = ({ tableId, onClose }) => {
  const { 
    selectedTableData, 
    selectedActions,
    closeTable
  } = useTables()
  
  const { products, getActiveProducts } = useProducts()
  const { formatDual } = useExchangeRate()
  const { precuentas, generatePrecuenta } = usePrecuentas()
  const { createCancellation, addNotification } = useStore()
  
  const searchTerm = ''
  const [selectedCategory, setSelectedCategory] = useState('Todas')
  const [showCancellation, setShowCancellation] = useState(false)
  const [showPreCuentaManager, setShowPreCuentaManager] = useState(false)
  const [showSplitConfig, setShowSplitConfig] = useState(false)
  const [showSplitManager, setShowSplitManager] = useState(false)
  const [cancellationItem, setCancellationItem] = useState<AccountItem | null>(null)

  const table = selectedTableData
  const session = table?.currentSession
  const tablePrecuentas = precuentas.filter(precuenta => precuenta.tableId === tableId)

  if (!table || !session) {
    return (
      <div className="flex h-64 flex-col items-center justify-center gap-4">
        <p className="text-gray-400">Sesión de mesa no disponible</p>
        <Button variant="secondary" onClick={onClose}>Volver al Salón</Button>
      </div>
    )
  }

  const handleAddProduct = (product: any) => {
    selectedActions.addItem(product.id, 1)
  }

  const handleSendOrder = () => {
    const result = selectedActions.sendOrder()
    if (result.success) {
      // Mostrar notificación de éxito
    }
  }

  const handleGeneratePreCuenta = () => {
    const result = generatePrecuenta(tableId)
    if (result.success) {
      setShowPreCuentaManager(true)
    }
  }

  const handleBack = () => {
    onClose()
  }

  const handleCloseTable = () => {
    if (session.splitBillId) {
      addNotification({
        type: 'warning',
        message: 'No se puede cerrar una mesa con una división pendiente'
      })
      return
    }

    const result = closeTable(tableId)
    if (!result.success) {
      addNotification({
        type: 'error',
        message: result.message || 'No se pudo cerrar la mesa'
      })
      return
    }
    onClose()
  }

  const handleCancelItem = (item: AccountItem) => {
    setCancellationItem(item)
    setShowCancellation(true)
  }

  const handleCancellationClose = () => {
    setShowCancellation(false)
    setCancellationItem(null)
  }

  const handleSplitCreated = () => {
    setShowSplitConfig(false)
    setShowSplitManager(true)
  }

  const handleCancellationSubmit = async (
    reason: string,
    customReason?: string
  ) => {
    if (!cancellationItem) return

    const result = await createCancellation(
      'ITEM',
      cancellationItem.id,
      reason,
      customReason,
      tableId
    )

    if (!result.success) {
      addNotification({ type: 'error', message: result.message })
      return
    }

    addNotification({
      type: 'success',
      message: 'Solicitud registrada y pendiente de aprobación'
    })
    handleCancellationClose()
  }

  const categories = ['Todas', ...new Set(getActiveProducts().map(p => p.category))]

  return (
    <div className="space-y-6">
      {/* Header de la mesa */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <Button variant="secondary" onClick={handleBack}>
            <ArrowLeftIcon className="h-5 w-5 mr-2" />
            Volver al Salón
          </Button>
          
          <div>
            <h2 className="text-2xl font-bold text-white">
              {table.name}
            </h2>
            <div className="flex items-center space-x-2 mt-1">
              <Badge 
                variant={table.status === 'OCUPADA' ? 'warning' : 'info'}
                size="sm"
              >
                {table.status}
              </Badge>
              <span className="text-sm text-gray-400">
                Creada: {session.createdAt.toLocaleTimeString()}
              </span>
            </div>
          </div>
        </div>

        <div className="flex items-center space-x-3">
          <div className="text-right">
            <p className="text-sm text-gray-400">Total</p>
            <p className="text-xl font-bold text-amalfi-turquoise">
              {formatDual(session.totalUSD)}
            </p>
          </div>
          
          <Button variant="danger" size="sm" onClick={handleCloseTable}>
            <XMarkIcon className="h-4 w-4 mr-1" />
            Cerrar Mesa
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Columna izquierda: Productos */}
        <div className="lg:col-span-2 space-y-6">
          {/* Búsqueda de productos */}
          <Card title=" Buscar Productos">
            <ProductSearch 
              onProductSelect={handleAddProduct}
              placeholder=" Buscar producto por nombre..."
            />
          </Card>

          {/* Filtros por categoría */}
          <Card title=" Categorías">
            <div className="flex flex-wrap gap-2">
              {categories.map((category) => (
                <button
                  key={category}
                  onClick={() => setSelectedCategory(category)}
                  className={`
                    px-3 py-1 rounded-full text-sm font-medium transition-colors
                    ${selectedCategory === category
                      ? 'bg-amalfi-deep text-white'
                      : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                    }
                  `}
                >
                  {category}
                </button>
              ))}
            </div>
          </Card>

          {/* Grid de productos */}
          <ProductGrid 
            products={getActiveProducts().filter(p => 
              selectedCategory === 'Todas' || p.category === selectedCategory
            )}
            onAddProduct={handleAddProduct}
            searchTerm={searchTerm}
          />
        </div>

        {/* Columna derecha: Cuenta actual */}
        <div className="space-y-6">
          <CurrentOrder 
            items={session.items}
            onUpdateQuantity={selectedActions.updateQuantity}
            onRemoveItem={selectedActions.removeItem}
            onCancelItem={handleCancelItem}
          />

          {/* Acciones rápidas */}
          <Card title=" Acciones">
            <div className="space-y-3">
              <Button 
                variant="primary" 
                className="w-full"
                onClick={handleSendOrder}
                disabled={session.items.every(i => i.sent)}
              >
                <PaperAirplaneIcon className="h-5 w-5 mr-2" />
                Enviar Comanda
              </Button>

              {table.status !== 'PRECUENTA EMITIDA' && (
                <Button
                  variant="secondary"
                  className="w-full"
                  onClick={handleGeneratePreCuenta}
                  disabled={!session.items.some(item => !item.cancelled)}
                >
                  <ReceiptRefundIcon className="h-5 w-5 mr-2" />
                  Generar Precuenta
                </Button>
              )}

              {table.status === 'PRECUENTA EMITIDA' && (
                <div className="space-y-2">
                  <Badge variant="info" size="sm" className="w-full justify-center">
                    Precuenta Emitida
                  </Badge>
                  <Button
                    variant="secondary"
                    className="w-full"
                    onClick={() => setShowPreCuentaManager(true)}
                  >
                    Gestionar Precuenta
                  </Button>
                </div>
              )}

              {!session.splitBillId && (
                <Button
                  variant="secondary"
                  className="w-full"
                  onClick={() => setShowSplitConfig(true)}
                  disabled={!session.items.some(item => !item.cancelled)}
                >
                  <UsersIcon className="mr-2 h-5 w-5" />
                  Dividir Cuenta
                </Button>
              )}

              {session.splitBillId && (
                <Button
                  variant="secondary"
                  className="w-full"
                  onClick={() => setShowSplitManager(true)}
                >
                  <UsersIcon className="mr-2 h-5 w-5" />
                  Gestionar División
                </Button>
              )}

              <div className="pt-3 border-t border-gray-700">
                <p className="text-xs text-gray-400 mb-2">Atajos de teclado:</p>
                <div className="space-y-1 text-xs text-gray-300">
                  <div className="flex justify-between">
                    <span>+F1</span>
                    <span>Environmentar</span>
                  </div>
                  <div className="flex justify-between">
                    <span>+F2</span>
                    <span>Precuenta</span>
                  </div>
                  <div className="flex justify-between">
                    <span>+Esc</span>
                    <span>,Volver</span>
                  </div>
                </div>
              </div>
            </div>
          </Card>
        </div>
      </div>

      {cancellationItem && (
        <CancellationModal
          isOpen={showCancellation}
          onClose={handleCancellationClose}
          type="ITEM"
          itemId={cancellationItem.id}
          itemName={
            products.find(product => product.id === cancellationItem.productId)
              ?.name || 'Producto'
          }
          tableId={tableId}
          quantity={cancellationItem.quantity}
          amount={cancellationItem.quantity * cancellationItem.unitPrice}
          onSubmit={handleCancellationSubmit}
        />
      )}

      {showPreCuentaManager && (
        <PreCuentaManager
          tableId={tableId}
          precuentas={tablePrecuentas}
          onClose={() => setShowPreCuentaManager(false)}
        />
      )}

      <SplitConfigModal
        isOpen={showSplitConfig}
        onClose={() => setShowSplitConfig(false)}
        tableId={tableId}
        items={session.items.filter(item => !item.cancelled)}
        totalUSD={session.totalUSD}
        totalBs={session.totalBs}
        onSplitCreated={handleSplitCreated}
      />

      {showSplitManager && (
        <SplitManager
          tableId={tableId}
          onClose={() => setShowSplitManager(false)}
        />
      )}
    </div>
  )
}

export default TableSession