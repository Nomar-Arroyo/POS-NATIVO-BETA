import { beforeEach, describe, expect, it } from 'vitest'
import type { Config, Table } from '../types'
import { useStore } from './store'
import storageService from '../services/storage/storageService'

const config: Config = {
  establishmentName: 'Café Amalfi Test',
  taxId: 'J-TEST-12345678-9',
  currency: 'USD',
  exchangeRate: 20,
  exchangeRateSource: 'BCV',
  ivaRate: 0.16,
  igtfRate: 0.03,
  fiscalSimulation: true,
  printWidth: 58
}

const table: Table = {
  id: 'table-rate-test',
  name: 'Mesa de prueba',
  capacity: 2,
  status: 'OCUPADA',
  position: { x: 0, y: 0 },
  currentSession: {
    sessionId: 'session-rate-test',
    tableId: 'table-rate-test',
    items: [{
      id: 'item-rate-test',
      productId: 'product-rate-test',
      quantity: 2,
      unitPrice: 5,
      sent: false,
      cancelled: false
    }],
    precuentaGenerated: false,
    totalUSD: 10,
    totalBs: 200,
    createdAt: new Date('2026-11-20T12:00:00.000Z'),
    updatedAt: new Date('2026-11-20T12:00:00.000Z')
  }
}

describe('exchange rate store actions', () => {
  beforeEach(() => {
    storageService.setConfig(config)
    storageService.setTables([table])
    useStore.setState({ config, tables: [table] })
  })

  it('keeps an admin manual override while caching the latest BCV rate', () => {
    const actions = useStore.getState()
    actions.updateExchangeRate(25)
    actions.setBcvExchangeRate(
      918.7662,
      '2026-11-20',
      '2026-11-20T15:00:00.000Z'
    )

    expect(useStore.getState().config).toMatchObject({
      exchangeRate: 25,
      exchangeRateSource: 'MANUAL',
      bcvRate: 918.7662,
      bcvRateDate: '2026-11-20'
    })
    expect(useStore.getState().tables[0].currentSession?.totalBs).toBe(250)

    useStore.getState().applyBcvExchangeRate()

    expect(useStore.getState().config).toMatchObject({
      exchangeRate: 918.7662,
      exchangeRateSource: 'BCV'
    })
    expect(useStore.getState().tables[0].currentSession?.totalBs).toBe(9187.66)
    expect(storageService.getConfig().exchangeRate).toBe(918.7662)
  })

  it('applies a newly fetched BCV rate automatically when no manual override exists', () => {
    useStore.getState().setBcvExchangeRate(
      918.7662,
      '2026-11-20',
      '2026-11-20T15:00:00.000Z'
    )

    expect(useStore.getState().config.exchangeRate).toBe(918.7662)
    expect(useStore.getState().config.exchangeRateSource).toBe('BCV')
    expect(useStore.getState().tables[0].currentSession?.totalBs).toBe(9187.66)
  })

  it('stores but does not apply a rate before its effective date', () => {
    const actions = useStore.getState()
    actions.setBcvExchangeRate(
      35,
      '2999-12-31',
      '2026-11-20T15:00:00.000Z'
    )

    expect(useStore.getState().config).toMatchObject({
      exchangeRate: 20,
      exchangeRateSource: 'BCV',
      bcvRate: 35,
      bcvRateDate: '2999-12-31'
    })
    expect(() => useStore.getState().applyBcvExchangeRate()).toThrow(
      'La tasa BCV todavía no está vigente'
    )
    expect(useStore.getState().tables[0].currentSession?.totalBs).toBe(200)
  })
})
