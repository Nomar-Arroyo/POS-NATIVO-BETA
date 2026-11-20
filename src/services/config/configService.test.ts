import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { Config } from '../../types'

const mockStorage = vi.hoisted(() => ({
  config: {
    establishmentName: 'Café Amalfi',
    taxId: 'J-12345678-9',
    currency: 'USD' as 'USD' | 'Bs',
    exchangeRate: 918.7662,
    exchangeRateSource: 'BCV' as Config['exchangeRateSource'],
    ivaRate: 0.16,
    igtfRate: 0.03,
    fiscalSimulation: true,
    printWidth: 58 as 58 | 80
  } as Config,
  setConfig: vi.fn()
}))

vi.mock('../storage/storageService', () => ({
  default: {
    getConfig: () => mockStorage.config,
    setConfig: (config: Config) => {
      mockStorage.config = config
      mockStorage.setConfig(config)
    }
  }
}))

import configService from './configService'

describe('configService', () => {
  beforeEach(() => {
    mockStorage.config = {
      establishmentName: 'Café Amalfi',
      taxId: 'J-12345678-9',
      currency: 'USD',
      exchangeRate: 918.7662,
      exchangeRateSource: 'BCV',
      ivaRate: 0.16,
      igtfRate: 0.03,
      fiscalSimulation: true,
      printWidth: 58
    }
    mockStorage.setConfig.mockClear()
  })

  it('accepts a realistic BCV rate and rejects non-finite rates', () => {
    expect(configService.validateConfig(mockStorage.config).isValid).toBe(true)
    expect(configService.validateConfig({
      ...mockStorage.config,
      exchangeRate: Number.NaN
    }).errors).toContain('La tasa de cambio debe ser mayor a 0')
  })

  it('does not persist an imported configuration with an invalid rate', () => {
    const result = configService.importConfig(JSON.stringify({
      ...mockStorage.config,
      exchangeRate: 0
    }))

    expect(result.success).toBe(false)
    expect(mockStorage.setConfig).not.toHaveBeenCalled()
  })
})
