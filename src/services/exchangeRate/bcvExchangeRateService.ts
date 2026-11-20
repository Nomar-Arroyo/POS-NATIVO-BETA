import { invoke, isTauri } from '@tauri-apps/api/core'

export interface BcvExchangeRate {
  rate: number
  rateDate: string
  retrievedAt: string
}

const BCV_RATE_ENDPOINT = '/api/bcv-rate'
let inFlightRequest: Promise<BcvExchangeRate> | undefined

function caracasDate(date: Date): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Caracas',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(date)
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find(value => value.type === type)?.value ?? ''

  return `${part('year')}-${part('month')}-${part('day')}`
}

export function isBcvRateEffective(
  rateDate: string,
  now = new Date()
): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(rateDate)) return false
  const parsedDate = new Date(`${rateDate}T00:00:00.000Z`)
  if (
    Number.isNaN(parsedDate.getTime()) ||
    parsedDate.toISOString().slice(0, 10) !== rateDate
  ) {
    return false
  }

  return rateDate <= caracasDate(now)
}

export function isBcvRateRefreshDue(
  lastCheckedAt?: string,
  now = new Date()
): boolean {
  if (!lastCheckedAt) return true

  const lastChecked = new Date(lastCheckedAt)
  return Number.isNaN(lastChecked.getTime()) ||
    caracasDate(lastChecked) !== caracasDate(now)
}

function parseRate(value: string): number {
  const normalized = value
    .replace(/<[^>]*>/g, '')
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/\s/g, '')
    .trim()

  const lastComma = normalized.lastIndexOf(',')
  const lastDot = normalized.lastIndexOf('.')
  const decimalComma = lastComma > lastDot
  const digits = decimalComma
    ? normalized.replace(/\./g, '').replace(',', '.')
    : normalized.replace(/,/g, '')
  const rate = Number(digits)

  if (!Number.isFinite(rate) || rate <= 0) {
    throw new Error('El BCV devolvió una tasa USD inválida')
  }

  return rate
}

function parseRateDate(value: string): string {
  const isoDate = value.match(/^(\d{4}-\d{2}-\d{2})/)
  if (isoDate && !Number.isNaN(Date.parse(value))) {
    return isoDate[1]
  }

  const dayFirstDate = value.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/)
  if (dayFirstDate) {
    const [, day, month, year] = dayFirstDate
    const date = new Date(Number(year), Number(month) - 1, Number(day))
    if (
      date.getFullYear() === Number(year) &&
      date.getMonth() === Number(month) - 1 &&
      date.getDate() === Number(day)
    ) {
      return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`
    }
  }

  throw new Error('No se pudo identificar la fecha de vigencia publicada por el BCV')
}

export function parseBcvRateHtml(
  html: string,
  retrievedAt = new Date()
): BcvExchangeRate {
  const usdMatch = html.match(
    /<div\b(?=[^>]*\bid=["']dolar["'])[^>]*>[\s\S]*?<strong\b[^>]*>([\s\S]*?)<\/strong>/i
  )
  if (!usdMatch) {
    throw new Error('La página del BCV no contiene la tasa del dólar')
  }

  const dateMatch = html.match(
    /Fecha\s*Valor:\s*<span\b[^>]*\bcontent=["']([^"']+)["']/i
  )
  if (!dateMatch) {
    throw new Error('La página del BCV no contiene la fecha de vigencia')
  }

  if (Number.isNaN(retrievedAt.getTime())) {
    throw new Error('La fecha de consulta de la tasa no es válida')
  }

  return {
    rate: parseRate(usdMatch[1]),
    rateDate: parseRateDate(dateMatch[1]),
    retrievedAt: retrievedAt.toISOString()
  }
}

async function requestBcvPage(): Promise<string> {
  if (typeof window !== 'undefined' && isTauri()) {
    return invoke<string>('fetch_bcv_exchange_rate_page')
  }

  const response = await fetch(BCV_RATE_ENDPOINT, {
    headers: { Accept: 'text/html' },
    signal: AbortSignal.timeout(15000)
  })

  if (!response.ok) {
    throw new Error(`No se pudo consultar el BCV (HTTP ${response.status})`)
  }

  return response.text()
}

export function fetchBcvExchangeRate(): Promise<BcvExchangeRate> {
  if (!inFlightRequest) {
    inFlightRequest = requestBcvPage()
      .then(html => parseBcvRateHtml(html))
      .finally(() => {
        inFlightRequest = undefined
      })
  }

  return inFlightRequest
}
