export interface CashSession {
  id: string
  userId: string
  userName: string
  openedAt: Date
  closedAt?: Date
  openingBalanceUSD: number
  openingBalanceBs: number
  closingBalanceUSD?: number
  closingBalanceBs?: number
  expectedBalanceUSD?: number
  expectedBalanceBs?: number
  differenceUSD?: number
  differenceBs?: number
  status: 'OPEN' | 'CLOSED'
  movements: CashMovement[]
  reportX?: CashReport
  reportZ?: CashReport
}

export interface CashMovement {
  id: string
  type: 'INGRESO' | 'EGRESO' | 'APERTURA' | 'CIERRE' | 'AJUSTE'
  category:
    | 'VENTA'
    | 'ANULACION'
    | 'AJUSTE_MANUAL'
    | 'GASTO'
    | 'APERTURA_INICIAL'
    | 'CIERRE_FINAL'
  amount: number
  currency: 'USD' | 'Bs'
  method?:
    | 'EFECTIVO USD'
    | 'EFECTIVO Bs'
    | 'PUNTO DE VENTA'
    | 'PAGO MÓVIL'
    | 'ZELLE'
    | 'OTRO'
  description: string
  reference?: string
  timestamp: Date
  userId: string
  userName: string
  sessionId: string
  factId?: string
  tableId?: string
}

export interface CashReport {
  id: string
  sessionId: string
  type: 'X' | 'Z'
  generatedAt: Date
  totalSalesUSD: number
  totalSalesBs: number
  totalSalesByMethod: Record<string, { USD: number; Bs: number }>
  totalIngresosUSD: number
  totalIngresosBs: number
  totalEgresosUSD: number
  totalEgresosBs: number
  openingBalanceUSD: number
  openingBalanceBs: number
  expectedBalanceUSD: number
  expectedBalanceBs: number
  actualBalanceUSD?: number
  actualBalanceBs?: number
  differenceUSD?: number
  differenceBs?: number
  totalInvoices: number
  totalCancellations: number
  printed: boolean
  notes?: string
}

export interface CashCount {
  USD: {
    bills: Record<number, number>
    total: number
  }
  Bs: {
    bills: Record<number, number>
    total: number
  }
  coins: Record<number, number>
}

export const USD_BILLS = [1, 2, 5, 10, 20, 50, 100]
export const Bs_BILLS = [2, 5, 10, 20, 50, 100, 200]
export const COINS = [0.25, 0.5, 1, 2]
