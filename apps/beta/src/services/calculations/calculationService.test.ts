import { describe, expect, it } from 'vitest'
import type { AccountItem, Pago } from '../../types'
import calculationService from './calculationService'

const item = (quantity: number, unitPrice: number): AccountItem => ({
  id: 'item-1',
  productId: 'product-1',
  quantity,
  unitPrice,
  sent: false,
  cancelled: false
})

const payment = (
  id: string,
  amount: number,
  currency: Pago['currency']
): Pago => ({
  id,
  method: currency === 'USD' ? 'EFECTIVO USD' : 'EFECTIVO Bs',
  amount,
  currency
})

describe('calculationService', () => {
  it('rounds line totals when calculating a subtotal', () => {
    expect(calculationService.calculateSubtotal([
      item(3, 0.1),
      item(2, 0.2)
    ])).toBe(0.7)
  })

  it('calculates invoice taxes and total from configured rates', () => {
    expect(calculationService.calculateTotalFactura(10, 0.16, 0.03)).toEqual({
      subtotal: 10,
      iva: 1.6,
      igtf: 0.3,
      total: 11.9
    })
  })

  it('validates a payment split across USD and Bs and clears its balance', () => {
    const payments = [
      payment('usd-1', 5, 'USD'),
      payment('bs-1', 150, 'Bs')
    ]

    expect(calculationService.validatePaymentComplete(10, payments, 30)).toEqual({
      isValid: true,
      remainingUSD: 0,
      remainingBs: 0,
      totalPaidUSD: 5,
      totalPaidBs: 150
    })
    expect(calculationService.calculateRemaining(10, payments, 30)).toEqual({
      remainingUSD: 0,
      remainingBs: 0
    })
  })

  it('reports the unpaid balance in both currencies for a partial mixed payment', () => {
    const payments = [
      payment('usd-1', 5, 'USD'),
      payment('bs-1', 30, 'Bs')
    ]

    expect(calculationService.calculateRemaining(10, payments, 30)).toEqual({
      remainingUSD: 4,
      remainingBs: 120
    })
  })

  it('rejects invalid exchange rates rather than returning invalid conversions', () => {
    expect(() => calculationService.convertBsToUSD(10, 0)).toThrow(
      'La tasa de cambio debe ser mayor que cero'
    )
  })
})
