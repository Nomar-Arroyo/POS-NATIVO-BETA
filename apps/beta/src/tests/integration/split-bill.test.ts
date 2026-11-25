import { beforeEach, describe, expect, it } from 'vitest'
import { SPLIT_MODES } from '../../types/splitBill'
import splitBillService from '../../services/splitBill/splitBillService'
import storageService from '../../services/storage/storageService'
import tableService from '../../services/tables/tableService'
import { setupIntegrationData } from './testData'

describe('split bill workflow', () => {
  beforeEach(() => {
    setupIntegrationData()
  })

  it('releases the table after all equal shares are paid', () => {
    tableService.openTable('table-1', 'user-1')
    tableService.addItemToTable('table-1', 'prod-1', 4)

    const splitBill = splitBillService.createSplitBill('table-1', {
      mode: SPLIT_MODES.EQUAL,
      splitCount: 2,
      assignItems: {},
      names: {
        'split-1': 'Cuenta uno',
        'split-2': 'Cuenta dos'
      }
    })

    expect(splitBill.splits.map(split => split.subtotalUSD)).toEqual([5, 5])
    expect(storageService.getTable('table-1')?.currentSession?.splitBillId)
      .toBe(splitBill.id)

    for (const split of splitBill.splits) {
      splitBillService.addPaymentToSplit(splitBill.id, split.id, {
        method: 'EFECTIVO USD',
        amount: 5,
        currency: 'USD'
      })
    }

    expect(splitBillService.getSplitBill(splitBill.id)?.status).toBe('COMPLETED')
    expect(splitBillService.canReleaseTable('table-1')).toBe(true)
    expect(storageService.getTable('table-1')).toMatchObject({
      status: 'LIBRE',
      currentSession: undefined
    })
  })
})
