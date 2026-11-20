import React, { useEffect, useState } from 'react'
import type { CashCount } from '../../types/cash'
import { Bs_BILLS, COINS, USD_BILLS } from '../../types/cash'
import Modal from '../common/Modal'
import Input from '../common/Input'
import Button from '../common/Button'
import { CalculatorIcon } from '@/components/common/Icon'

interface CashCountModalProps {
  isOpen: boolean
  onClose: () => void
  expectedUSD: number
  expectedBs: number
  onCountComplete: (count: CashCount) => void
}

const createEmptyCount = (): CashCount => ({
  USD: { bills: {}, total: 0 },
  Bs: { bills: {}, total: 0 },
  coins: {}
})

const sumDenominations = (counts: Record<number, number>): number =>
  Object.entries(counts).reduce(
    (total, [denomination, count]) => total + Number(denomination) * count,
    0
  )

const CashCountModal: React.FC<CashCountModalProps> = ({
  isOpen,
  onClose,
  expectedUSD,
  expectedBs,
  onCountComplete
}) => {
  const [cashCount, setCashCount] = useState<CashCount>(createEmptyCount)

  useEffect(() => {
    if (isOpen) setCashCount(createEmptyCount())
  }, [isOpen])

  const handleBillCount = (
    denomination: number,
    count: number,
    currency: 'USD' | 'Bs'
  ) => {
    const safeCount = Math.max(0, Math.floor(count))
    setCashCount(previous => {
      if (currency === 'USD') {
        const bills = { ...previous.USD.bills, [denomination]: safeCount }
        return {
          ...previous,
          USD: { bills, total: sumDenominations(bills) + sumDenominations(previous.coins) }
        }
      }

      const bills = { ...previous.Bs.bills, [denomination]: safeCount }
      return {
        ...previous,
        Bs: { bills, total: sumDenominations(bills) }
      }
    })
  }

  const handleCoinCount = (denomination: number, count: number) => {
    const safeCount = Math.max(0, Math.floor(count))
    setCashCount(previous => {
      const coins = { ...previous.coins, [denomination]: safeCount }
      return {
        ...previous,
        coins,
        USD: {
          ...previous.USD,
          total: sumDenominations(previous.USD.bills) + sumDenominations(coins)
        }
      }
    })
  }

  const differenceUSD = cashCount.USD.total - expectedUSD
  const differenceBs = cashCount.Bs.total - expectedBs

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Arqueo de efectivo" size="xl">
      <div className="space-y-6">
        <div className="grid grid-cols-2 gap-4 rounded-lg bg-gray-700 p-4">
          <div>
            <h3 className="mb-2 font-medium text-white">Esperado</h3>
            <p className="text-gray-300">USD: ${expectedUSD.toFixed(2)}</p>
            <p className="text-gray-300">Bs: {expectedBs.toFixed(2)}</p>
          </div>
          <div>
            <h3 className="mb-2 font-medium text-white">Contado</h3>
            <p className="text-gray-300">USD: ${cashCount.USD.total.toFixed(2)}</p>
            <p className="text-gray-300">Bs: {cashCount.Bs.total.toFixed(2)}</p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4 rounded-lg bg-gray-700 p-4">
          <Difference label="Diferencia USD" amount={differenceUSD} symbol="$" />
          <Difference label="Diferencia Bs" amount={differenceBs} symbol="Bs." />
        </div>

        <DenominationGrid
          title="Billetes USD"
          denominations={USD_BILLS}
          counts={cashCount.USD.bills}
          currency="USD"
          onChange={(denomination, count) =>
            handleBillCount(denomination, count, 'USD')
          }
        />
        <DenominationGrid
          title="Billetes Bs"
          denominations={Bs_BILLS}
          counts={cashCount.Bs.bills}
          currency="Bs"
          onChange={(denomination, count) =>
            handleBillCount(denomination, count, 'Bs')
          }
        />
        <DenominationGrid
          title="Monedas USD"
          denominations={COINS}
          counts={cashCount.coins}
          currency="USD"
          onChange={handleCoinCount}
        />

        <div className="flex justify-end space-x-3 border-t border-gray-700 pt-4">
          <Button variant="secondary" onClick={onClose}>Cancelar</Button>
          <Button
            variant="primary"
            onClick={() => onCountComplete(cashCount)}
          >
            <CalculatorIcon className="mr-2 h-5 w-5" />
            Confirmar arqueo
          </Button>
        </div>
      </div>
    </Modal>
  )
}

interface DenominationGridProps {
  title: string
  denominations: number[]
  counts: Record<number, number>
  currency: 'USD' | 'Bs'
  onChange: (denomination: number, count: number) => void
}

const DenominationGrid: React.FC<DenominationGridProps> = ({
  title,
  denominations,
  counts,
  currency,
  onChange
}) => (
  <section>
    <h3 className="mb-3 text-lg font-medium text-white">{title}</h3>
    <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
      {denominations.map(denomination => (
        <div key={denomination} className="space-y-2 rounded-lg bg-gray-700 p-3">
          <span className="text-sm text-gray-300">
            {currency === 'USD' ? '$' : 'Bs. '}{denomination}
          </span>
          <Input
            type="number"
            min="0"
            step="1"
            value={counts[denomination] || 0}
            onChange={event => onChange(
              denomination,
              Number.parseInt(event.target.value, 10) || 0
            )}
            className="text-center"
            aria-label={`Cantidad de billetes de ${denomination} ${currency}`}
          />
          <span className="text-xs text-amalfi-turquoise">
            {currency === 'USD' ? '$' : 'Bs. '}
            {(denomination * (counts[denomination] || 0)).toFixed(2)}
          </span>
        </div>
      ))}
    </div>
  </section>
)

interface DifferenceProps {
  label: string
  amount: number
  symbol: string
}

const Difference: React.FC<DifferenceProps> = ({ label, amount, symbol }) => (
  <div>
    <span className="text-gray-400">{label}:</span>
    <span className={`ml-2 font-bold ${amount >= 0 ? 'text-green-400' : 'text-red-400'}`}>
      {amount >= 0 ? '+' : ''}{symbol} {amount.toFixed(2)}
    </span>
  </div>
)

export default CashCountModal
