import React, { useState } from 'react'
import { useStore } from '../../store/store'
import { useSplitBill } from '../../hooks/useSplitBill'
import type { AccountItem } from '../../types'
import { SPLIT_MODES, type SplitBill, type SplitOptions } from '../../types/splitBill'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Select from '../common/Select'
import Button from '../common/Button'
import Card from '../common/Card'
import { 
  PlusIcon, 
  MinusIcon, 
  UsersIcon
} from '@/components/common/Icon'

const isSplitMode = (value: string): value is keyof typeof SPLIT_MODES =>
  Object.keys(SPLIT_MODES).includes(value)

interface SplitConfigModalProps {
  isOpen: boolean
  onClose: () => void
  tableId: string
  items: AccountItem[]
  totalUSD: number
  totalBs: number
  onSplitCreated: (splitBill: SplitBill) => void
}

const SplitConfigModal: React.FC<SplitConfigModalProps> = ({
  isOpen,
  onClose,
  tableId,
  items,
  totalUSD,
  onSplitCreated
}) => {
  const { createSplit } = useSplitBill()
  const { config } = useStore()
  const [splitCount, setSplitCount] = useState(2)
  const [splitMode, setSplitMode] = useState<keyof typeof SPLIT_MODES>(SPLIT_MODES.BY_ITEM)
  const [splitNames, setSplitNames] = useState<Record<string, string>>({
    'split-1': 'Cuenta 1',
    'split-2': 'Cuenta 2'
  })
  const [assignItems, setAssignItems] = useState<Record<string, string[]>>({
    'split-1': [],
    'split-2': []
  })
  const [percentages, setPercentages] = useState<Record<string, number>>({
    'split-1': 50,
    'split-2': 50
  })
  const [amounts, setAmounts] = useState<Record<string, number>>({
    'split-1': 0,
    'split-2': 0
  })

  const modeOptions = [
    { value: SPLIT_MODES.BY_ITEM, label: 'Por Artículos' },
    { value: SPLIT_MODES.BY_PERCENTAGE, label: 'Por Porcentaje' },
    { value: SPLIT_MODES.BY_AMOUNT, label: 'Por Monto' },
    { value: SPLIT_MODES.EQUAL, label: 'Igualitario' }
  ]

  const handleSplitCountChange = (newCount: number) => {
    if (newCount < 2 || newCount > 6) return

    const newSplits: Record<string, string> = {}
    const newAssign: Record<string, string[]> = {}
    const newPercentages: Record<string, number> = {}
    const newAmounts: Record<string, number> = {}

    for (let i = 1; i <= newCount; i++) {
      const splitId = `split-${i}`
      newSplits[splitId] = splitNames[`split-${i}`] || `Cuenta ${i}`
      newAssign[splitId] = assignItems[`split-${i}`] || []
      const defaultPercentage = Math.round((100 / newCount) * 100) / 100
      newPercentages[splitId] = i === newCount
        ? 100 - defaultPercentage * (newCount - 1)
        : defaultPercentage
      newAmounts[splitId] = amounts[`split-${i}`] || 0
    }

    setSplitCount(newCount)
    setSplitNames(newSplits)
    setAssignItems(newAssign)
    setPercentages(newPercentages)
    setAmounts(newAmounts)
  }

  const handleNameChange = (splitId: string, name: string) => {
    setSplitNames(prev => ({ ...prev, [splitId]: name }))
  }

  const handleItemAssignment = (itemId: string, splitId: string) => {
    setAssignItems(prev => {
      const newAssign = { ...prev }
      
      // Remover el artículo de todos los splits
      Object.keys(newAssign).forEach(id => {
        newAssign[id] = newAssign[id].filter(id => id !== itemId)
      })
      
      // Agregar al split seleccionado
      if (!newAssign[splitId].includes(itemId)) {
        newAssign[splitId].push(itemId)
      }
      
      return newAssign
    })
  }

  const handlePercentageChange = (splitId: string, percentage: number) => {
    setPercentages(prev => ({ ...prev, [splitId]: percentage }))
  }

  const handleAmountChange = (splitId: string, amount: number) => {
    setAmounts(prev => ({ ...prev, [splitId]: amount }))
  }

  const handleSubmit = () => {
    const options: SplitOptions = {
      mode: splitMode,
      splitCount,
      assignItems,
      percentages: splitMode === SPLIT_MODES.BY_PERCENTAGE ? percentages : undefined,
      amounts: splitMode === SPLIT_MODES.BY_AMOUNT ? amounts : undefined,
      names: splitNames
    }

    const result = createSplit(tableId, options)
    
    if (result.success && result.splitBill) {
      onSplitCreated(result.splitBill)
      onClose()
    }
  }

  const calculateSplitPreview = () => {
    const splits = []
    
    for (let i = 1; i <= splitCount; i++) {
      const splitId = `split-${i}`
      let splitItems: AccountItem[] = []
      let subtotalUSD = 0

      switch (splitMode) {
        case SPLIT_MODES.BY_ITEM:
          splitItems = items.filter(item => 
            assignItems[splitId]?.includes(item.id)
          )
          subtotalUSD = splitItems.reduce((sum, item) => 
            sum + (item.quantity * item.unitPrice), 0
          )
          break
        case SPLIT_MODES.BY_PERCENTAGE:
          const percentage = percentages[splitId] || 0
          subtotalUSD = totalUSD * (percentage / 100)
          break
        case SPLIT_MODES.BY_AMOUNT:
          subtotalUSD = amounts[splitId] || 0
          break
        case SPLIT_MODES.EQUAL:
          subtotalUSD = totalUSD / splitCount
          break
      }

      splits.push({
        id: splitId,
        name: splitNames[splitId] || `Cuenta ${i}`,
        items: splitItems,
        subtotalUSD,
        subtotalBs: subtotalUSD * config.exchangeRate,
        paid: false,
        payments: []
      })
    }

    return splits
  }

  const previewSplits = calculateSplitPreview()

  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose} 
      title="Dividir Cuenta" 
      size="xl"
    >
      <div className="space-y-6">
        {/* Configuración básica */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Modo de División
            </label>
            <Select
              options={modeOptions}
              value={splitMode}
              onChange={event => {
                if (isSplitMode(event.target.value)) {
                  setSplitMode(event.target.value)
                }
              }}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Número de Cuentas
            </label>
            <div className="flex items-center space-x-2">
              <Button
                size="sm"
                variant="secondary"
                onClick={() => handleSplitCountChange(splitCount - 1)}
                disabled={splitCount <= 2}
              >
                <MinusIcon className="h-4 w-4" />
              </Button>
              
              <span className="text-xl font-bold text-white w-12 text-center">
                {splitCount}
              </span>
              
              <Button
                size="sm"
                variant="secondary"
                onClick={() => handleSplitCountChange(splitCount + 1)}
                disabled={splitCount >= 6}
              >
                <PlusIcon className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>

        {/* Configuración específica por modo */}
        {splitMode === SPLIT_MODES.BY_ITEM && (
          <Card title="Asignar Artículos">
            <div className="space-y-3">
              {items.map((item) => (
                <div key={item.id} className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
                  <div>
                    <span className="font-medium text-white">
                      {item.quantity}x {item.product?.name || item.productId}
                    </span>
                    <span className="text-sm text-gray-400 ml-2">
                      ${(item.quantity * item.unitPrice).toFixed(2)}
                    </span>
                  </div>
                  
                  <div className="flex space-x-1">
                    {Array.from({ length: splitCount }, (_, i) => {
                      const splitId = `split-${i + 1}`
                      const isAssigned = assignItems[splitId]?.includes(item.id)
                      
                      return (
                        <button
                          key={splitId}
                          onClick={() => handleItemAssignment(item.id, splitId)}
                          aria-label={`Asignar ${item.product?.name || item.productId} a Cuenta ${i + 1}`}
                          aria-pressed={isAssigned}
                          className={`
                            w-8 h-8 rounded border-2 transition-colors
                            ${isAssigned
                              ? 'bg-amalfi-turquoise border-amalfi-deep'
                              : 'bg-gray-600 border-gray-500 hover:border-gray-400'
                            }
                          `}
                        />
                      )
                    })}
                  </div>
                </div>
              ))}
            </div>
          </Card>
        )}

        {splitMode === SPLIT_MODES.BY_PERCENTAGE && (
          <Card title="Porcentajes de División">
            <div className="space-y-4">
              {Array.from({ length: splitCount }, (_, i) => {
                const splitId = `split-${i + 1}`
                const percentage = percentages[splitId] || 0
                
                return (
                  <div key={splitId} className="flex items-center space-x-4">
                    <div className="flex-1">
                      <Input
                        label={splitNames[splitId] || `Cuenta ${i + 1}`}
                        type="number"
                        min="0"
                        max="100"
                        value={percentage}
                        onChange={(e) => handlePercentageChange(splitId, parseFloat(e.target.value) || 0)}
                      />
                    </div>
                    <div className="text-right">
                      <span className="text-amalfi-turquoise font-bold">
                        ${(totalUSD * percentage / 100).toFixed(2)}
                      </span>
                    </div>
                  </div>
                )
              })}
            </div>
          </Card>
        )}

        {splitMode === SPLIT_MODES.BY_AMOUNT && (
          <Card title="Montos de División">
            <div className="space-y-4">
              {Array.from({ length: splitCount }, (_, i) => {
                const splitId = `split-${i + 1}`
                const amount = amounts[splitId] || 0
                
                return (
                  <div key={splitId} className="flex items-center space-x-4">
                    <div className="flex-1">
                      <Input
                        label={splitNames[splitId] || `Cuenta ${i + 1}`}
                        type="number"
                        step="0.01"
                        min="0"
                        max={totalUSD}
                        value={amount}
                        onChange={(e) => handleAmountChange(splitId, parseFloat(e.target.value) || 0)}
                      />
                    </div>
                    <div className="text-right">
                      <span className="text-amalfi-turquoise font-bold">
                        ${amount.toFixed(2)}
                      </span>
                    </div>
                  </div>
                )
              })}
            </div>
          </Card>
        )}

        {/* Nombres de las cuentas */}
        <Card title="Nombres de las Cuentas">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {Array.from({ length: splitCount }, (_, i) => {
              const splitId = `split-${i + 1}`
              
              return (
                <Input
                  key={splitId}
                  label={`Cuenta ${i + 1}`}
                  value={splitNames[splitId] || `Cuenta ${i + 1}`}
                  onChange={(e) => handleNameChange(splitId, e.target.value)}
                />
              )
            })}
          </div>
        </Card>

        {/* Vista previa de la división */}
        <Card title="Vista Previa de la División">
          <div className="space-y-3">
            {previewSplits.map((split) => (
              <div key={split.id} className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
                <div>
                  <span className="font-medium text-white">{split.name}</span>
                  <span className="text-sm text-gray-400 ml-2">
                    {split.items.length} artículos
                  </span>
                </div>
                <div className="text-right">
                  <span className="font-bold text-amalfi-turquoise">
                    ${split.subtotalUSD.toFixed(2)}
                  </span>
                  <span className="text-sm text-gray-400 ml-2">
                    Bs. {split.subtotalBs.toFixed(2)}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Botones de acción */}
        <div className="flex justify-end space-x-3 pt-4 border-t border-gray-700">
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button variant="primary" onClick={handleSubmit}>
            <UsersIcon className="h-5 w-5 mr-2" />
            Crear División
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default SplitConfigModal