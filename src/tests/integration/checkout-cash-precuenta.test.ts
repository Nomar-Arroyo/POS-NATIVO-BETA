import { beforeEach, describe, expect, it } from 'vitest'
import cashService from '../../services/cash/cashService'
import posService from '../../services/pos/posService'
import precuentaService from '../../services/precuentas/precuentaService'
import storageService from '../../services/storage/storageService'
import tableService from '../../services/tables/tableService'
import { setupIntegrationData } from './testData'

describe('checkout, cash, and precuenta workflows', () => {
  beforeEach(() => {
    setupIntegrationData()
  })

  it('creates a direct-sale invoice with mixed-currency payments', () => {
    const sale = posService.createDirectSale([
      { productId: 'prod-1', quantity: 2 }
    ], '1')

    expect(sale.totalUSD).toBe(5.95)
    expect(sale.totalBs).toBe(119)
    expect(storageService.getProduct('prod-1')?.stock).toBe(98)

    expect(() => posService.processDirectSalePayment(
      sale.saleId,
      [{ id: 'short', method: 'EFECTIVO USD', amount: 5, currency: 'USD' }]
    )).toThrow('El pago no cubre el total de la venta')
    expect(storageService.getFacturas()).toHaveLength(0)

    const invoice = posService.processDirectSalePayment(sale.saleId, [
      { id: 'usd', method: 'EFECTIVO USD', amount: 3, currency: 'USD' },
      { id: 'bs', method: 'EFECTIVO Bs', amount: 59, currency: 'Bs' }
    ], 'J-12345678-9', 'Cliente de prueba')

    expect(invoice).toMatchObject({
      orderId: sale.saleId,
      total: 5.95,
      customerName: 'Cliente de prueba',
      simulated: true
    })
    expect(storageService.getFacturas()).toHaveLength(1)
  })

  it('reports the expected balances when closing a cash session', () => {
    const session = cashService.openCashSession(
      '1',
      'Administrador de prueba',
      100,
      200
    )

    cashService.addMovement(session.id, {
      type: 'INGRESO',
      category: 'AJUSTE_MANUAL',
      amount: 20,
      currency: 'USD',
      description: 'Ingreso de prueba',
      userId: '1',
      userName: 'Administrador de prueba'
    })
    cashService.addMovement(session.id, {
      type: 'EGRESO',
      category: 'GASTO',
      amount: 50,
      currency: 'Bs',
      description: 'Gasto de prueba',
      userId: '1',
      userName: 'Administrador de prueba'
    })

    const report = cashService.closeCashSession(session.id, 120, 150)

    expect(report).toMatchObject({
      type: 'Z',
      expectedBalanceUSD: 120,
      expectedBalanceBs: 150,
      differenceUSD: 0,
      differenceBs: 0
    })
    expect(cashService.getSession(session.id)?.status).toBe('CLOSED')
  })

  it('generates a precuenta with the current rate and escapes product HTML', () => {
    tableService.openTable('table-1', '1')
    storageService.updateProduct('prod-1', {
      name: '<script>nombre inseguro</script>'
    })
    tableService.addItemToTable('table-1', 'prod-1', 2)

    const precuenta = precuentaService.generatePrecuenta('table-1')
    const ticket = precuentaService.generateTicketHtml(precuenta)

    expect(precuenta).toMatchObject({
      tableId: 'table-1',
      subtotalUSD: 5,
      totalBs: 100
    })
    expect(storageService.getTable('table-1')?.status).toBe('PRECUENTA EMITIDA')
    expect(ticket).toContain('&lt;script&gt;nombre inseguro&lt;/script&gt;')
    expect(ticket).not.toContain('<script>nombre inseguro</script>')
  })
})
