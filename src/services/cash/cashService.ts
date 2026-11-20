import storageService from '../storage/storageService'
import auditService from '../audit/auditService'
import type { Factura } from '../../types'
import {
  Bs_BILLS,
  COINS,
  USD_BILLS,
  type CashCount,
  type CashMovement,
  type CashReport,
  type CashSession
} from '../../types/cash'

class CashService {
  getSessions(): CashSession[] {
    return storageService.getCashSessions()
  }

  getMovements(): CashMovement[] {
    return storageService.getCashMovements()
  }

  getSession(id: string): CashSession | undefined {
    return this.getSessions().find(session => session.id === id)
  }

  getActiveSession(): CashSession | undefined {
    return this.getSessions().find(session => session.status === 'OPEN')
  }

  openCashSession(
    userId: string,
    userName: string,
    openingBalanceUSD: number,
    openingBalanceBs: number
  ): CashSession {
    if (this.getActiveSession()) {
      throw new Error('Ya hay una sesión de caja abierta')
    }
    if (!userId.trim() || !userName.trim()) {
      throw new Error('Debe indicar el usuario responsable de la caja')
    }
    if (
      !Number.isFinite(openingBalanceUSD) ||
      !Number.isFinite(openingBalanceBs) ||
      openingBalanceUSD < 0 ||
      openingBalanceBs < 0
    ) {
      throw new Error('Los saldos iniciales deben ser valores válidos y no negativos')
    }

    const now = new Date()
    const sessionId = `cash-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    const session: CashSession = {
      id: sessionId,
      userId,
      userName,
      openedAt: now,
      openingBalanceUSD: this.roundMoney(openingBalanceUSD),
      openingBalanceBs: this.roundMoney(openingBalanceBs),
      status: 'OPEN',
      movements: []
    }
    const openingMovements: CashMovement[] = [
      this.createMovement(session, {
        type: 'APERTURA',
        category: 'APERTURA_INICIAL',
        amount: session.openingBalanceUSD,
        currency: 'USD',
        method: 'EFECTIVO USD',
        description: 'Saldo inicial de apertura - USD'
      }),
      this.createMovement(session, {
        type: 'APERTURA',
        category: 'APERTURA_INICIAL',
        amount: session.openingBalanceBs,
        currency: 'Bs',
        method: 'EFECTIVO Bs',
        description: 'Saldo inicial de apertura - Bs'
      })
    ]

    session.movements.push(...openingMovements)
    storageService.addCashSession(session)
    openingMovements.forEach(movement => storageService.addCashMovement(movement))
    void auditService.logCashAction('APERTURA', {
      sessionId,
      openingBalanceUSD: session.openingBalanceUSD,
      openingBalanceBs: session.openingBalanceBs,
      user: userName
    }).catch((error: unknown) => {
      console.error('Error registrando apertura de caja:', error)
    })

    return session
  }

  closeCashSession(
    sessionId: string,
    actualBalanceUSD: number,
    actualBalanceBs: number,
    notes?: string
  ): CashReport {
    const session = this.getSession(sessionId)
    if (!session) {
      throw new Error(`Sesión de caja no encontrada: ${sessionId}`)
    }
    if (session.status !== 'OPEN') {
      throw new Error('La sesión de caja ya está cerrada')
    }
    if (
      !Number.isFinite(actualBalanceUSD) ||
      !Number.isFinite(actualBalanceBs) ||
      actualBalanceUSD < 0 ||
      actualBalanceBs < 0
    ) {
      throw new Error('Los saldos reales deben ser valores válidos y no negativos')
    }

    const expected = this.calculateExpectedBalance(session)
    const differenceUSD = this.roundMoney(actualBalanceUSD - expected.expectedBalanceUSD)
    const differenceBs = this.roundMoney(actualBalanceBs - expected.expectedBalanceBs)
    session.closedAt = new Date()
    session.status = 'CLOSED'
    session.closingBalanceUSD = this.roundMoney(actualBalanceUSD)
    session.closingBalanceBs = this.roundMoney(actualBalanceBs)
    session.expectedBalanceUSD = expected.expectedBalanceUSD
    session.expectedBalanceBs = expected.expectedBalanceBs
    session.differenceUSD = differenceUSD
    session.differenceBs = differenceBs

    const report = this.generateReport(
      session,
      'Z',
      session.closingBalanceUSD,
      session.closingBalanceBs,
      differenceUSD,
      differenceBs,
      notes
    )
    session.reportZ = report

    const closingMovements: CashMovement[] = [
      this.createMovement(session, {
        type: 'CIERRE',
        category: 'CIERRE_FINAL',
        amount: session.closingBalanceUSD,
        currency: 'USD',
        method: 'EFECTIVO USD',
        description: `Cierre de caja - Balance USD: ${session.closingBalanceUSD.toFixed(2)}`
      }),
      this.createMovement(session, {
        type: 'CIERRE',
        category: 'CIERRE_FINAL',
        amount: session.closingBalanceBs,
        currency: 'Bs',
        method: 'EFECTIVO Bs',
        description: `Cierre de caja - Balance Bs: ${session.closingBalanceBs.toFixed(2)}`
      })
    ]
    session.movements.push(...closingMovements)
    storageService.updateCashSession(sessionId, session)
    closingMovements.forEach(movement => storageService.addCashMovement(movement))
    void auditService.logCashAction('CIERRE', {
      sessionId,
      actualBalanceUSD: session.closingBalanceUSD,
      actualBalanceBs: session.closingBalanceBs,
      differenceUSD,
      differenceBs,
      notes
    }).catch((error: unknown) => {
      console.error('Error registrando cierre de caja:', error)
    })

    return report
  }

  calculateExpectedBalance(session: CashSession): {
    expectedBalanceUSD: number
    expectedBalanceBs: number
  } {
    let expectedUSD = session.openingBalanceUSD
    let expectedBs = session.openingBalanceBs

    for (const movement of session.movements) {
      if (movement.type !== 'INGRESO' && movement.type !== 'EGRESO') continue
      const direction = movement.type === 'INGRESO' ? 1 : -1
      if (movement.currency === 'USD') {
        expectedUSD += movement.amount * direction
      } else {
        expectedBs += movement.amount * direction
      }
    }

    return {
      expectedBalanceUSD: this.roundMoney(expectedUSD),
      expectedBalanceBs: this.roundMoney(expectedBs)
    }
  }

  generateReport(
    session: CashSession,
    type: 'X' | 'Z',
    actualBalanceUSD?: number,
    actualBalanceBs?: number,
    differenceUSD?: number,
    differenceBs?: number,
    notes?: string
  ): CashReport {
    const expected = this.calculateExpectedBalance(session)
    const facturas = storageService.getFacturas().filter(factura =>
      this.isFacturaInSession(factura, session)
    )
    const totalSalesByMethod: CashReport['totalSalesByMethod'] = {}

    let totalSalesUSD = 0
    for (const factura of facturas) {
      totalSalesUSD += factura.total
      for (const payment of factura.payments) {
        const methodAmounts = totalSalesByMethod[payment.method] || {
          USD: 0,
          Bs: 0
        }
        methodAmounts[payment.currency] += payment.amount
        totalSalesByMethod[payment.method] = methodAmounts
      }
    }

    let totalIngresosUSD = 0
    let totalIngresosBs = 0
    let totalEgresosUSD = 0
    let totalEgresosBs = 0
    for (const movement of session.movements) {
      if (
        movement.category === 'APERTURA_INICIAL' ||
        movement.category === 'CIERRE_FINAL'
      ) {
        continue
      }
      if (movement.type === 'INGRESO') {
        if (movement.currency === 'USD') totalIngresosUSD += movement.amount
        else totalIngresosBs += movement.amount
      } else if (movement.type === 'EGRESO') {
        if (movement.currency === 'USD') totalEgresosUSD += movement.amount
        else totalEgresosBs += movement.amount
      }
    }

    const sessionEnd = session.closedAt?.getTime() ?? Date.now()
    const totalCancellations = auditService.getAuditLogs().filter(log => {
      const timestamp = new Date(log.timestamp).getTime()
      return timestamp >= session.openedAt.getTime() &&
        timestamp <= sessionEnd &&
        log.action.includes('ANULACION')
    }).length
    const exchangeRate = storageService.getConfig().exchangeRate
    const report: CashReport = {
      id: `report-${type}-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      sessionId: session.id,
      type,
      generatedAt: new Date(),
      totalSalesUSD: this.roundMoney(totalSalesUSD),
      totalSalesBs: this.roundMoney(totalSalesUSD * exchangeRate),
      totalSalesByMethod,
      totalIngresosUSD: this.roundMoney(totalIngresosUSD),
      totalIngresosBs: this.roundMoney(totalIngresosBs),
      totalEgresosUSD: this.roundMoney(totalEgresosUSD),
      totalEgresosBs: this.roundMoney(totalEgresosBs),
      openingBalanceUSD: session.openingBalanceUSD,
      openingBalanceBs: session.openingBalanceBs,
      expectedBalanceUSD: session.expectedBalanceUSD ?? expected.expectedBalanceUSD,
      expectedBalanceBs: session.expectedBalanceBs ?? expected.expectedBalanceBs,
      actualBalanceUSD,
      actualBalanceBs,
      differenceUSD,
      differenceBs,
      totalInvoices: facturas.length,
      totalCancellations,
      printed: false,
      notes
    }

    if (type === 'X') session.reportX = report
    else session.reportZ = report
    storageService.updateCashSession(session.id, session)
    return report
  }

  addMovement(
    sessionId: string,
    movement: Omit<CashMovement, 'id' | 'timestamp' | 'sessionId'>
  ): CashMovement {
    const session = this.getSession(sessionId)
    if (!session) {
      throw new Error(`Sesión de caja no encontrada: ${sessionId}`)
    }
    if (session.status !== 'OPEN') {
      throw new Error('No se pueden agregar movimientos a una caja cerrada')
    }
    if (movement.type !== 'INGRESO' && movement.type !== 'EGRESO') {
      throw new Error('El movimiento manual debe ser un ingreso o egreso')
    }
    if (!Number.isFinite(movement.amount) || movement.amount <= 0) {
      throw new Error('El monto del movimiento debe ser mayor a 0')
    }
    if (!movement.description.trim()) {
      throw new Error('La descripción del movimiento es obligatoria')
    }

    const newMovement = this.createMovement(session, {
      ...movement,
      amount: this.roundMoney(movement.amount)
    })
    session.movements.push(newMovement)
    storageService.updateCashSession(sessionId, session)
    storageService.addCashMovement(newMovement)
    void auditService.logCashAction('MOVIMIENTO', {
      movementId: newMovement.id,
      type: newMovement.type,
      amount: newMovement.amount,
      currency: newMovement.currency,
      description: newMovement.description
    }).catch((error: unknown) => {
      console.error('Error registrando movimiento de caja:', error)
    })

    return newMovement
  }

  registerSale(factura: Factura): CashMovement[] {
    const session = this.getActiveSession()
    if (!session) return []

    const cashPayments = factura.payments.filter(payment =>
      payment.method === 'EFECTIVO USD' || payment.method === 'EFECTIVO Bs'
    )
    const movements = cashPayments.map(payment =>
      this.createMovement(session, {
        type: 'INGRESO',
        category: 'VENTA',
        amount: this.roundMoney(payment.amount),
        currency: payment.currency,
        method: payment.method,
        description: `Venta - Factura ${factura.number}`,
        reference: factura.number,
        factId: factura.id,
        tableId: factura.tableId
      })
    )

    if (movements.length > 0) {
      session.movements.push(...movements)
      storageService.updateCashSession(session.id, session)
      movements.forEach(movement => storageService.addCashMovement(movement))
    }
    return movements
  }

  generateCashCount(session: CashSession): CashCount {
    const expected = this.calculateExpectedBalance(session)
    const usdBills = this.distributeAmount(expected.expectedBalanceUSD, USD_BILLS)
    const bsBills = this.distributeAmount(expected.expectedBalanceBs, Bs_BILLS)
    const usdBillsTotal = Object.entries(usdBills).reduce(
      (sum, [denomination, count]) => sum + Number(denomination) * count,
      0
    )
    const coins = this.distributeAmount(
      Math.max(0, expected.expectedBalanceUSD - usdBillsTotal),
      COINS
    )
    return {
      USD: { bills: usdBills, total: expected.expectedBalanceUSD },
      Bs: { bills: bsBills, total: expected.expectedBalanceBs },
      coins
    }
  }

  getCashStats(): {
    activeSessions: number
    totalSessionsToday: number
    totalSalesToday: number
    averageTicket: number
  } {
    const today = new Date().toDateString()
    const sessions = this.getSessions()
    const todaySessions = sessions.filter(
      session => new Date(session.openedAt).toDateString() === today
    )
    const facturas = storageService.getFacturas().filter(
      factura => new Date(factura.createdAt).toDateString() === today
    )
    const totalSalesToday = facturas.reduce((sum, factura) => sum + factura.total, 0)

    return {
      activeSessions: sessions.filter(session => session.status === 'OPEN').length,
      totalSessionsToday: todaySessions.length,
      totalSalesToday: this.roundMoney(totalSalesToday),
      averageTicket: facturas.length
        ? this.roundMoney(totalSalesToday / facturas.length)
        : 0
    }
  }

  private createMovement(
    session: CashSession,
    movement: Omit<CashMovement, 'id' | 'timestamp' | 'userId' | 'userName' | 'sessionId'>
  ): CashMovement {
    return {
      ...movement,
      id: `mov-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      timestamp: new Date(),
      userId: session.userId,
      userName: session.userName,
      sessionId: session.id
    }
  }

  private isFacturaInSession(factura: Factura, session: CashSession): boolean {
    const invoiceTime = new Date(factura.createdAt).getTime()
    const sessionStart = new Date(session.openedAt).getTime()
    const sessionEnd = session.closedAt
      ? new Date(session.closedAt).getTime()
      : Date.now()
    return invoiceTime >= sessionStart && invoiceTime <= sessionEnd
  }

  private distributeAmount(amount: number, denominations: number[]): Record<number, number> {
    const bills: Record<number, number> = {}
    let remaining = Math.max(0, amount)
    for (const denomination of [...denominations].sort((a, b) => b - a)) {
      const count = Math.floor(remaining / denomination)
      if (count > 0) {
        bills[denomination] = count
        remaining = this.roundMoney(remaining - count * denomination)
      }
    }
    return bills
  }

  private roundMoney(value: number): number {
    return Math.round(value * 100) / 100
  }
}

export default new CashService()
