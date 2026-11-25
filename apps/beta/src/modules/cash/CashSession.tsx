import React, { useState } from 'react'
import Modal from '../../components/common/Modal'
import Input from '../../components/common/Input'
import Button from '../../components/common/Button'

interface CashSessionProps {
  isOpen: boolean
  onClose: () => void
  onOpen: (openingBalanceUSD: number, openingBalanceBs: number) => void
}

const CashSession: React.FC<CashSessionProps> = ({ 
  isOpen, 
  onClose, 
  onOpen 
}) => {
  const [openingBalanceUSD, setOpeningBalanceUSD] = useState(0)
  const [openingBalanceBs, setOpeningBalanceBs] = useState(0)

  const handleSubmit = () => {
    onOpen(openingBalanceUSD, openingBalanceBs)
    onClose()
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Abrir Caja" size="md">
      <div className="space-y-4">
        <Input
          label="Saldo Inicial USD"
          type="number"
          step="0.01"
          min="0"
          value={openingBalanceUSD}
          onChange={(e) => setOpeningBalanceUSD(parseFloat(e.target.value) || 0)}
        />

        <Input
          label="Saldo Inicial Bs"
          type="number"
          step="0.01"
          min="0"
          value={openingBalanceBs}
          onChange={(e) => setOpeningBalanceBs(parseFloat(e.target.value) || 0)}
        />

        <div className="flex justify-end space-x-3">
          <Button variant="secondary" onClick={onClose}>
            Cancelar
          </Button>
          <Button variant="primary" onClick={handleSubmit}>
            Abrir Caja
          </Button>
        </div>
      </div>
    </Modal>
  )
}

export default CashSession