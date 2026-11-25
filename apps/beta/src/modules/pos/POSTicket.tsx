import React from 'react'
import { AccountItem } from '../../types'
import Button from '../../components/common/Button'
import Input from '../../components/common/Input'
import Badge from '../../components/common/Badge'
import Card from '../../components/common/Card'
import Icon from '../../components/common/Icon'
import {
  TrashIcon,
  PlusIcon,
  MinusIcon
} from '@/components/common/Icon'

interface POSTicketProps {
  items: AccountItem[]
  subtotalUSD: number
  iva: number
  igtf: number
  totalUSD: number
  exchangeRate: number
  onUpdateQuantity: (itemId: string, newQuantity: number) => void
  onRemoveItem: (itemId: string) => void
  onProceedToPayment: () => void
  onClearSale: () => void
}

const POSTicket: React.FC<POSTicketProps> = ({
  items,
  subtotalUSD,
  iva,
  igtf,
  totalUSD,
  exchangeRate,
  onUpdateQuantity,
  onRemoveItem,
  onProceedToPayment,
  onClearSale
}) => {
  const totalBs = totalUSD * exchangeRate
  const itemsCount = items.reduce((sum, item) => sum + item.quantity, 0)

  const handleQuantityChange = (item: AccountItem, change: number) => {
    const newQuantity = Math.max(0, item.quantity + change)
    if (newQuantity === 0) {
      onRemoveItem(item.id)
    } else {
      onUpdateQuantity(item.id, newQuantity)
    }
  }

  return (
    <Card
      title="Ticket de Venta"
      actions={<Badge variant="info" size="sm">{itemsCount} artículos</Badge>}
    >
      <div className="space-y-3 max-h-96 overflow-y-auto">
        {items.length === 0 ? (
          <div className="text-center py-8">
            <div className="text-gray-500 mb-2">
              <Icon name="receipt" size={48} className="mx-auto" />
            </div>
            <p className="text-gray-400">No hay artículos en la venta</p>
            <p className="text-sm text-gray-500 mt-1">
              Busca y agrega productos para comenzar
            </p>
          </div>
        ) : (
          items.map(item => (
            <div key={item.id} className="p-3 bg-gray-700 rounded-lg">
              <div className="flex items-start justify-between">
                <div className="flex-1 min-w-0">
                  <h4 className="font-medium text-white text-sm">
                    {item.product?.name || item.productId}
                  </h4>
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
                  <div className="flex items-center space-x-1">
                    <Button
                      type="button"
                      size="sm"
                      variant="secondary"
                      onClick={() => handleQuantityChange(item, -1)}
                      disabled={item.quantity <= 1}
                      aria-label={`Disminuir cantidad de ${item.product?.name || 'producto'}`}
                    >
                      <MinusIcon className="h-3 w-3" />
                    </Button>

                    <Input
                      type="number"
                      min="1"
                      step="1"
                      value={item.quantity}
                      aria-label={`Cantidad de ${item.product?.name || 'producto'}`}
                      onChange={event => {
                        const newQuantity = Number.parseInt(event.target.value, 10)
                        if (Number.isFinite(newQuantity) && newQuantity > 0) {
                          onUpdateQuantity(item.id, newQuantity)
                        }
                      }}
                      className="w-12 text-center"
                    />

                    <Button
                      type="button"
                      size="sm"
                      variant="secondary"
                      onClick={() => handleQuantityChange(item, 1)}
                      aria-label={`Aumentar cantidad de ${item.product?.name || 'producto'}`}
                    >
                      <PlusIcon className="h-3 w-3" />
                    </Button>
                  </div>

                  <Button
                    type="button"
                    size="sm"
                    variant="danger"
                    onClick={() => onRemoveItem(item.id)}
                    aria-label={`Eliminar ${item.product?.name || 'producto'} de la venta`}
                  >
                    <TrashIcon className="h-4 w-4" />
                  </Button>
                </div>
              </div>

              <div className="flex justify-between items-center mt-2 pt-2 border-t border-gray-600">
                <span className="text-xs text-gray-400">Subtotal</span>
                <span className="font-bold text-amalfi-turquoise">
                  ${(item.quantity * item.unitPrice).toFixed(2)}
                </span>
              </div>
            </div>
          ))
        )}
      </div>

      {items.length > 0 && (
        <div className="mt-4 pt-4 border-t border-gray-700">
          <div className="space-y-1 mb-4 text-sm">
            <div className="flex justify-between text-gray-300">
              <span>Subtotal:</span>
              <span>${subtotalUSD.toFixed(2)}</span>
            </div>
            {iva > 0 && (
              <div className="flex justify-between text-gray-300">
                <span>IVA:</span>
                <span>${iva.toFixed(2)}</span>
              </div>
            )}
            {igtf > 0 && (
              <div className="flex justify-between text-gray-300">
                <span>IGTF:</span>
                <span>${igtf.toFixed(2)}</span>
              </div>
            )}
          </div>

          <div className="flex justify-between items-center mb-4">
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

          <div className="space-y-2">
            <Button
              type="button"
              variant="primary"
              className="w-full"
              onClick={onProceedToPayment}
            >
              Proceder al Pago
            </Button>
            <Button
              type="button"
              variant="secondary"
              className="w-full"
              onClick={onClearSale}
            >
              Limpiar Venta
            </Button>
          </div>
        </div>
      )}
    </Card>
  )
}

export default POSTicket
