import { useMemo } from 'react'
import { useStore } from '../store/store'
import { useCalculation } from './useCalculation'

export const useExchangeRate = () => {
  const { config } = useStore()
  const { convertUSDToBs, convertBsToUSD, roundMoney } = useCalculation()

  const exchangeRate = config.exchangeRate

  const convert = useMemo(() => ({
    usdToBs: (amount: number) => convertUSDToBs(amount, exchangeRate),
    bsToUsd: (amount: number) => convertBsToUSD(amount, exchangeRate),
    formatUSD: (amount: number) => 
      new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
      }).format(amount),
    formatBs: (amount: number) => 
      new Intl.NumberFormat('es-VE', {
        style: 'currency',
        currency: 'VES'
      }).format(amount),
    formatDual: (amountUSD: number) => {
      const bs = convertUSDToBs(amountUSD, exchangeRate)
      return `${new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amountUSD)} 
              / ${new Intl.NumberFormat('es-VE', { style: 'currency', currency: 'VES' }).format(bs)}`
    }
  }), [exchangeRate, convertUSDToBs, convertBsToUSD])

  return {
    exchangeRate,
    ...convert,
    roundMoney
  }
}

export default useExchangeRate