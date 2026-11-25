import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { Factura, Order, Pago, Table } from '../../types'

const mockStorage = vi.hoisted(() => ({
  tables: [] as Array<Pick<Table, 'id' | 'status' | 'currentSession'>>,
  orders: [] as Array<Pick<Order, 'id' | 'tableId'>>,
  facturas: [] as Array<Pick<Factura, 'id' | 'number' | 'total' | 'payments'>>,
  pagos: [] as Array<Pick<Pago, 'id'>>,
  exchangeRate: 30
}))

vi.mock('../storage/storageService', () => ({
  default: {
    getTables: () => mockStorage.tables,
    getOrders: () => mockStorage.orders,
    getFacturas: () => mockStorage.facturas,
    getPagos: () => mockStorage.pagos,
    getConfig: () => ({ exchangeRate: mockStorage.exchangeRate })
  }
}))

import verificationService from './verificationService'

const order = (tableId: string): Order => ({
  id: `order-${tableId}`,
  tableId,
  items: [],
  station: 'BARRA',
  status: 'pendiente',
  createdAt: new Date(),
  userId: 'user-1',
  orderNumber: `ORD-${tableId}`
})

const invoice = (payments: Pago[], total: number): Factura => ({
  id: 'invoice-1',
  number: 'FAC-1',
  controlNumber: 'CTRL-1',
  items: [],
  subtotal: total,
  iva: 0,
  total,
  payments,
  createdAt: new Date(),
  simulated: true
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

describe('verificationService', () => {
  beforeEach(() => {
    mockStorage.tables = [{
      id: 'table-1',
      status: 'LIBRE',
      currentSession: undefined
    }]
    mockStorage.orders = []
    mockStorage.facturas = []
    mockStorage.pagos = []
    mockStorage.exchangeRate = 30
  })

  it('does not report direct-sale orders as references to missing tables', () => {
    mockStorage.orders = [order('direct-sale')]

    expect(verificationService.verifyDataIntegrity()).toMatchObject({
      isValid: true,
      errors: [],
      warnings: []
    })
  })

  it('reports orders that refer to a missing dining table', () => {
    mockStorage.orders = [order('table-missing')]

    expect(verificationService.verifyDataIntegrity().errors).toContain(
      'Orden order-table-missing refers a mesa inexistente: table-missing'
    )
  })

  it('converts mixed-currency invoice payments before checking their total', () => {
    mockStorage.facturas = [invoice([
      payment('usd-1', 1, 'USD'),
      payment('bs-1', 30, 'Bs')
    ], 2)]

    expect(verificationService.verifyDataIntegrity().errors).toEqual([])
  })

  it('reports an invoice whose recorded payments do not cover its total', () => {
    mockStorage.facturas = [invoice([payment('usd-1', 1, 'USD')], 2)]

    expect(verificationService.verifyDataIntegrity().errors).toContain(
      'Factura FAC-1: pagos no coinciden con total'
    )
  })
})
