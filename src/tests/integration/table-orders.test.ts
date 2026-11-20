import { beforeEach, describe, expect, it } from 'vitest'
import orderService from '../../services/orders/orderService'
import { ORDER_STATUS } from '../../types/orders'
import storageService from '../../services/storage/storageService'
import tableService from '../../services/tables/tableService'
import { setupIntegrationData } from './testData'

describe('table and order workflow', () => {
  beforeEach(() => {
    setupIntegrationData()
  })

  it('routes items by station and closes the table after order processing', () => {
    tableService.openTable('table-1', 'user-1')
    tableService.addItemToTable('table-1', 'prod-1', 2)
    tableService.addItemToTable('table-1', 'prod-6', 1)

    const orders = orderService.sendOrderFromTable('table-1', 'user-1')

    expect(orders.map(order => order.station)).toEqual(['COCINA', 'BARRA'])
    expect(storageService.getTable('table-1')?.currentSession?.items)
      .toEqual(expect.arrayContaining([
        expect.objectContaining({ productId: 'prod-1', sent: true }),
        expect.objectContaining({ productId: 'prod-6', sent: true })
      ]))

    orders.forEach(order => {
      orderService.updateOrderStatus(order.id, ORDER_STATUS.EN_PREPARACION)
      orderService.updateOrderStatus(order.id, ORDER_STATUS.LISTO)
      orderService.updateOrderStatus(order.id, ORDER_STATUS.ENTREGADO)
    })

    expect(storageService.getOrders().every(
      order => order.status === ORDER_STATUS.ENTREGADO && Boolean(order.deliveredAt)
    )).toBe(true)

    tableService.closeTable('table-1')
    expect(storageService.getTable('table-1')).toMatchObject({
      status: 'LIBRE',
      currentSession: undefined
    })
  })
})
