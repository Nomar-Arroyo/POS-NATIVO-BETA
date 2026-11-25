import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  fetchBcvExchangeRate,
  isBcvRateEffective,
  isBcvRateRefreshDue,
  parseBcvRateHtml
} from './bcvExchangeRateService'

const tauriApi = vi.hoisted(() => ({
  invoke: vi.fn(),
  isTauri: vi.fn(() => false)
}))

vi.mock('@tauri-apps/api/core', () => tauriApi)

const validBcvPage = `
  <div id="dolar">
    <span>USD</span>
    <strong class="strong-tb">918,76620000</strong>
  </div>
  <div class="date">
    Fecha Valor: <span content="2026-11-20T00:00:00-04:00">Viernes, 20 Noviembre 2026</span>
  </div>
`

describe('bcvExchangeRateService', () => {
  beforeEach(() => {
    tauriApi.isTauri.mockReturnValue(false)
    tauriApi.invoke.mockReset()
    vi.stubGlobal('fetch', vi.fn())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('parses the official USD rate and effective date', () => {
    expect(parseBcvRateHtml(validBcvPage, new Date('2026-11-20T15:00:00.000Z')))
      .toEqual({
        rate: 918.7662,
        rateDate: '2026-11-20',
        retrievedAt: '2026-11-20T15:00:00.000Z'
      })
  })

  it('parses rates with a thousands separator and decimal comma', () => {
    const page = validBcvPage.replace('918,76620000', '1.234,5678')
    expect(parseBcvRateHtml(page).rate).toBe(1234.5678)
  })

  it('rejects a BCV page whose rate or effective date cannot be verified', () => {
    expect(() => parseBcvRateHtml('<html>BCV</html>')).toThrow(
      'La página del BCV no contiene la tasa del dólar'
    )
    expect(() => parseBcvRateHtml(validBcvPage.replace('918,76620000', 'N/D')))
      .toThrow('El BCV devolvió una tasa USD inválida')
    expect(() => parseBcvRateHtml(
      validBcvPage.replace('2026-11-20T00:00:00-04:00', 'fecha desconocida')
    )).toThrow('No se pudo identificar la fecha de vigencia publicada por el BCV')
  })

  it('checks automatically once per BCV local calendar day', () => {
    expect(isBcvRateRefreshDue(
    '2026-11-20T15:00:00.000Z',
    new Date('2026-11-20T23:00:00.000Z')
    )).toBe(false)
    expect(isBcvRateRefreshDue(
    '2026-11-20T03:59:00.000Z',
    new Date('2026-11-20T04:05:00.000Z')
    )).toBe(true)
    expect(isBcvRateRefreshDue('not-a-date')).toBe(true)
  })

  it('does not treat a future-effective BCV rate as active', () => {
    const now = new Date('2026-11-20T17:00:00-04:00')

    expect(isBcvRateEffective('2026-11-19', now)).toBe(true)
    expect(isBcvRateEffective('2026-11-20', now)).toBe(true)
    expect(isBcvRateEffective('2026-11-24', now)).toBe(false)
    expect(isBcvRateEffective('2026-02-30', now)).toBe(false)
  })

  it('fetches and parses the BCV page through the development proxy', async () => {
    vi.mocked(fetch).mockResolvedValue(
      new Response(validBcvPage, { status: 200 })
    )

    await expect(fetchBcvExchangeRate()).resolves.toMatchObject({
      rate: 918.7662,
      rateDate: '2026-11-20'
    })
    expect(fetch).toHaveBeenCalledWith(
      '/api/bcv-rate',
      expect.objectContaining({ headers: { Accept: 'text/html' } })
    )
  })

  it('reports an HTTP error returned by the BCV proxy', async () => {
    vi.mocked(fetch).mockResolvedValue(
      new Response('', { status: 503 })
    )

    await expect(fetchBcvExchangeRate()).rejects.toThrow(
      'No se pudo consultar el BCV (HTTP 503)'
    )
  })

  it('uses the native Tauri command instead of browser fetch', async () => {
    vi.stubGlobal('window', {})
    tauriApi.isTauri.mockReturnValue(true)
    tauriApi.invoke.mockResolvedValue(validBcvPage)

    await expect(fetchBcvExchangeRate()).resolves.toMatchObject({
      rate: 918.7662,
      rateDate: '2026-11-20'
    })
    expect(tauriApi.invoke).toHaveBeenCalledWith(
      'fetch_bcv_exchange_rate_page'
    )
    expect(fetch).not.toHaveBeenCalled()
  })

  it('shares an in-flight BCV request between simultaneous callers', async () => {
    let resolveResponse: (response: Response) => void = () => undefined
    vi.mocked(fetch).mockReturnValue(new Promise(resolve => {
      resolveResponse = resolve
    }))

    const firstRequest = fetchBcvExchangeRate()
    const secondRequest = fetchBcvExchangeRate()
    expect(secondRequest).toBe(firstRequest)

    resolveResponse(new Response(validBcvPage, { status: 200 }))
    await expect(firstRequest).resolves.toMatchObject({ rate: 918.7662 })
    expect(fetch).toHaveBeenCalledTimes(1)
  })
})
