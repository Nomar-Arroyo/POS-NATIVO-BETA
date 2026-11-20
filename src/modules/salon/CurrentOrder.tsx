import React from 'react'
import { AccountItem } from '../../types'
import { useProducts } from '../../hooks/useProducts'
import { useExchangeRate } from '../../hooks/useExchangeRate'
import Button from '../../components/common/Button'
import Input from '../../components/common/Input'
import Badge from '../../components/common/Badge'
import Card from '../../components/common/Card'
import Icon from '../../components/common/Icon'
import { 
  PlusIcon, 
  MinusIcon,
  XMarkIcon
} from '@/components/common/Icon'

interface CurrentOrderProps {
  items: AccountItem[]
  onUpdateQuantity: (itemId: string, newQuantity: number) => void
  onRemoveItem: (itemId: string) => void
  onCancelItem: (item: AccountItem) => void
  onAddNotes?: (itemId: string, notes: string) => void
}

const CurrentOrder: React.FC<CurrentOrderProps> = ({ 
  items, 
  onUpdateQuantity, 
  onRemoveItem,
  onCancelItem
}) => {
  const { products } = useProducts()
  const { formatDual } = useExchangeRate()

  const handleQuantityChange = (item: AccountItem, change: number) => {
    const newQuantity = Math.max(0, item.quantity + change)
    if (newQuantity === 0) {
      onRemoveItem(item.id)
    } else {
      onUpdateQuantity(item.id, newQuantity)
    }
  }

  const totalUSD = items.reduce((sum, item) => sum + (item.quantity * item.unitPrice), 0)
  const totalBs = totalUSD * 20 // Usar tasa actual

  if (items.length === 0) {
    return (
      <Card title="Cuenta Actual">
        <div className="text-center py-8">
          <div className="text-gray-500 mb-2">
            <Icon name="receipt" size={48} className="mx-auto" />
          </div>
          <p className="text-gray-400">No hay artículos en la cuenta</p>
          <p className="text-sm text-gray-500 mt-1">
            Busca y agrega productos para comenzar
          </p>
        </div>
      </Card>
    )
  }

  return (
    <Card title="Cuenta Actual" actions={
      <Badge variant="info" size="sm">
        {items.length} artículos
      </Badge>
    }>
      <div className="space-y-3 max-h-96 overflow-y-auto">
        {items.map((item) => {
          const product = products.find(candidate => candidate.id === item.productId)
          const productName = product?.name || 'Producto'
          
          return (
            <div key={item.id} className="p-3 bg-gray-700 rounded-lg">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-2">
                    <h4 className="font-medium text-white text-sm">
                      {productName}
                    </h4>
                    {item.sent && (
                      <Badge variant="success" size="sm">
                        Enviado
                      </Badge>
                    )}
                    {item.cancelled && (
                      <Badge variant="error" size="sm">
                        Cancelado
                      </Badge>
                    )}
                  </div>
                  
                  <div className="flex items-center space-x-2 mt-1">
                    <span className="text-xs text-gray-400">
                      ${item.unitPrice.toFixed(2)} c/u
                    </span>
                    {item.notes && (
                      <span className="text-xs text-gray-400">
                        Nota: {item.notes}
                      </span>
                    )}
                  </div>
                </div>

                <div className="flex items-center space-x-2">
                  {/* Cantidad */}
                  <div className="flex items-center space-x-1">
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() => handleQuantityChange(item, -1)}
                      disabled={item.quantity <= 1}
                    >
                      <MinusIcon className="h-3 w-3" />
                    </Button>
                    
                    <Input
                      type="number"
                      min="1"
                      value={item.quantity}
                      onChange={(e) => {
                        const newQty = parseInt(e.target.value) || 1
                        onUpdateQuantity(item.id, newQty)
                      }}
                      className="w-12 text-center"
                    />
                    
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() => handleQuantityChange(item, 1)}
                    >
                      <PlusIcon className="h-3 w-3" />
                    </Button>
                  </div>

                  {/* Eliminar */}
                  <Button
                    size="sm"
                    variant="danger"
                    onClick={() => onCancelItem(item)}
                    disabled={item.cancelled}
                    aria-label={`Solicitar anulación de ${productName}`}
                    title="Solicitar anulación"
                  >
                    <XMarkIcon className="h-4 w-4" />
                  </Button>
                </div>
              </div>

              {/* Total del artículo */}
              <div className="flex justify-between items-center mt-2 pt-2 border-t border-gray-600">
                <span className="text-xs text-gray-400">
                  Subtotal
                </span>
                <span className="font-bold text-amalfi-turquoise">
                  {formatDual(item.quantity * item.unitPrice)}
                </span>
              </div>
            </div>
          )
        })}
      </div>

      {/* Total de la cuenta */}
      <div className="mt-4 pt-4 border-t border-gray-700">
        <div className="flex justify-between items-center">
          <span className="text-lg font-medium text-white">Total</span>
          <div className="text-right">
            <div className="text-xl font-bold text-amalfi-turquoise">
              ${totalUSD.toFixed(2)}
            </div>
            <div className="text-sm text-gray-400">
              Bs. {totalBs.toFixed(2)}
            </div>
          </div>
        </div>
      </div>
    </Card>
  )
}

export default CurrentOrder