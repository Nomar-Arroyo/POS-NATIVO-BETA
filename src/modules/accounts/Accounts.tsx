import React, { useState } from 'react'
import { useStore } from '../../store/store'
import { useTableSession } from '../../hooks/useTableSession'
import Button from '../../components/common/Button'
import Card from '../../components/common/Card'
import { AccountItem } from '../../types'

const Accounts: React.FC = () => {
  const { selectedTable } = useStore()
  const { currentSession } = useTableSession()
  const [splits, setSplits] = useState<{ items: AccountItem[]; name: string }[]>([])

  if (!selectedTable || !currentSession) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-gray-400">Selecciona una mesa para gestionar la cuenta</p>
      </div>
    )
  }

  const handleSplit = () => {
    // Lógica para dividir la cuenta
    const itemsPerSplit = Math.ceil(currentSession.items.length / 2)
    const split1 = {
      items: currentSession.items.slice(0, itemsPerSplit),
      name: 'Cuenta 1'
    }
    const split2 = {
      items: currentSession.items.slice(itemsPerSplit),
      name: 'Cuenta 2'
    }
    setSplits([split1, split2])
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">División de Cuenta</h2>
        <Button variant="primary" onClick={handleSplit}>
          Dividir Cuenta
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {splits.map((split, index) => (
          <Card key={index} title={split.name}>
            <div className="space-y-2">
              {split.items.map((item) => (
                <div key={item.id} className="flex justify-between">
                  <span>{item.quantity}x</span>
                  <span>${item.unitPrice.toFixed(2)}</span>
                  <span>${(item.quantity * item.unitPrice).toFixed(2)}</span>
                </div>
              ))}
            </div>
          </Card>
        ))}
      </div>
    </div>
  )
}

export default Accounts