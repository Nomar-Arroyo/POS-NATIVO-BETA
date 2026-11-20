import React, { useState } from 'react'
import Modal from '../common/Modal'
import Button from '../common/Button'
import { AccountItem } from '../../types'

interface SplitBillModalProps {
  isOpen: boolean
  onClose: () => void
  items: AccountItem[]
  onSplit: (splits: { items: AccountItem[]; name: string }[]) => void
}

const SplitBillModal: React.FC<SplitBillModalProps> = ({
  isOpen,
  onClose,
  items,
  onSplit
}) => {
  const [splits] = useState<{ items: AccountItem[]; name: string }[]>([
    { items: [], name: 'Cuenta 1' }
  ])
  const [selectedItems, setSelectedItems] = useState<Record<string, number>>({})

  const handleToggleItem = (itemId: string, splitIndex: number) => {
    setSelectedItems(prev => ({
      ...prev,
      [`${itemId}-${splitIndex}`]: (prev[`${itemId}-${splitIndex}`] || 0) + 1
    }))
  }

  const handleCreateSplit = () => {
    const newSplits = splits.map((split, index) => {
      const splitItems = items.filter(item => {
        const count = selectedItems[`${item.id}-${index}`] || 0
        return count > 0
      }).map(item => ({
        ...item,
        quantity: selectedItems[`${item.id}-${index}`] || 0
      }))

      return {
        ...split,
        items: splitItems
      }
    })

    onSplit(newSplits.filter(split => split.items.length > 0))
    onClose()
  }

  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose} 
      title="Dividir Cuenta" 
      size="lg"
    >
      <div className="space-y-4">
        <div className="bg-gray-700 rounded-lg p-4">
          <h3 className="font-medium text-white mb-2">Products to Split</h3>
          <div className="space-y-2">
            {items.map((item) => (
              <div key={item.id} className="flex items-center justify-between">
                <span>{item.quantity}x {item.product?.name || 'Product'}</span>
                <div className="flex space-x-2">
                  {splits.map((_, index) => (
                    <Button
                      key={index}
                      size="sm"
                      variant="secondary"
                      onClick={() => handleToggleItem(item.id, index)}
                    >
                      {selectedItems[`${item.id}-${index}`] || 0}
                    </Button>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="flex justify-end space-x-3">
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button variant="primary" onClick={handleCreateSplit}>
            Crear División
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default SplitBillModal