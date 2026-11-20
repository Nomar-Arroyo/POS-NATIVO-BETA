import { AccountItem, Pago } from '../types'
import calculationService from '../services/calculations/calculationService'

export const useCalculation = () => {
  return {
    calculateSubtotal: (items: AccountItem[]) =>
      calculationService.calculateSubtotal(items),
    calculateTotal: (items: AccountItem[]) =>
      calculationService.calculateTotal(items),
    calculateExchange: (amountUSD: number, exchangeRate: number) =>
      calculationService.convertUSDToBs(amountUSD, exchangeRate),
    calculateChange: (total: number, paid: number) =>
      calculationService.calculateChange(total, paid),
    calculateIVA: (subtotal: number, rate: number) =>
      calculationService.calculateIVA(subtotal, rate),
    calculateIGTF: (subtotal: number, rate: number) =>
      calculationService.calculateIGTF(subtotal, rate),
    calculateTotalPaid: (pagos: Pago[], currency: 'USD' | 'Bs') =>
      calculationService.calculateTotalPaid(pagos, currency),
    roundMoney: (amount: number) => calculationService.roundMoney(amount),
    convertUSDToBs: (amountUSD: number, exchangeRate: number) =>
      calculationService.convertUSDToBs(amountUSD, exchangeRate),
    convertBsToUSD: (amountBs: number, exchangeRate: number) =>
      calculationService.convertBsToUSD(amountBs, exchangeRate),
    validatePaymentComplete: (
      totalUSD: number,
      pagos: Pago[],
      exchangeRate: number
    ) => calculationService.validatePaymentComplete(totalUSD, pagos, exchangeRate),
    formatCurrency: (amount: number, currency: 'USD' | 'Bs') =>
      calculationService.formatCurrency(amount, currency)
  }
}

export default useCalculation