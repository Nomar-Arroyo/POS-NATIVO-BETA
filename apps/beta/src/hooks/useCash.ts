import { useCallback } from 'react'
import { useStore } from '../store/store'
import cashService from '../services/cash/cashService'
import type {
  CashMovement,
  CashReport,
  CashSession
} from '../types/cash'

const errorMessage = (error: unknown, fallback: string): string =>
  error instanceof Error ? error.message : fallback

export const useCash = () => {
  const {
    cashSessions,
    cashMovements,
    setCashSessions,
    setCashMovements,
    addNotification
  } = useStore()

  const syncCashState = useCallback(() => {
    setCashSessions(cashService.getSessions())
    setCashMovements(cashService.getMovements())
  }, [setCashMovements, setCashSessions])

  const openCash = useCallback((
    userId: string,
    userName: string,
    openingBalanceUSD: number,
    openingBalanceBs: number
  ): { success: boolean; session?: CashSession; message?: string } => {
    try {
      const session = cashService.openCashSession(
        userId,
        userName,
        openingBalanceUSD,
        openingBalanceBs
      )
      syncCashState()
      addNotification({
        type: 'success',
        message: `Caja abierta por ${userName}`
      })
      return { success: true, session }
    } catch (error) {
      const message = errorMessage(error, 'No se pudo abrir la caja')
      addNotification({ type: 'error', message })
      return { success: false, message }
    }
  }, [addNotification, syncCashState])

  const closeCash = useCallback((
    sessionId: string,
    actualBalanceUSD: number,
    actualBalanceBs: number,
    notes?: string
  ): { success: boolean; report?: CashReport; message?: string } => {
    try {
      const report = cashService.closeCashSession(
        sessionId,
        actualBalanceUSD,
        actualBalanceBs,
        notes
      )
      syncCashState()
      addNotification({
        type: 'success',
        message: 'Caja cerrada correctamente'
      })
      return { success: true, report }
    } catch (error) {
      const message = errorMessage(error, 'No se pudo cerrar la caja')
      addNotification({ type: 'error', message })
      return { success: false, message }
    }
  }, [addNotification, syncCashState])

  const addMovement = useCallback((
    sessionId: string,
    movement: Omit<CashMovement, 'id' | 'timestamp' | 'sessionId'>
  ): { success: boolean; movement?: CashMovement; message?: string } => {
    try {
      const newMovement = cashService.addMovement(sessionId, movement)
      syncCashState()
      return { success: true, movement: newMovement }
    } catch (error) {
      const message = errorMessage(error, 'No se pudo registrar el movimiento')
      addNotification({ type: 'error', message })
      return { success: false, message }
    }
  }, [addNotification, syncCashState])

  const generateReport = useCallback((
    sessionId: string,
    type: 'X' | 'Z',
    actualBalanceUSD?: number,
    actualBalanceBs?: number,
    notes?: string
  ): { success: boolean; report?: CashReport; message?: string } => {
    try {
      const session = cashService.getSession(sessionId)
      if (!session) throw new Error('Sesión de caja no encontrada')

      const report = cashService.generateReport(
        session,
        type,
        actualBalanceUSD,
        actualBalanceBs,
        undefined,
        undefined,
        notes
      )
      syncCashState()
      return { success: true, report }
    } catch (error) {
      const message = errorMessage(error, 'No se pudo generar el reporte')
      addNotification({ type: 'error', message })
      return { success: false, message }
    }
  }, [addNotification, syncCashState])

  const getActiveSession = useCallback(
    () => cashSessions.find(session => session.status === 'OPEN'),
    [cashSessions]
  )

  const getExpectedBalance = useCallback((sessionId: string) => {
    const session = cashService.getSession(sessionId)
    return session ? cashService.calculateExpectedBalance(session) : undefined
  }, [])

  const getCashCount = useCallback((sessionId: string) => {
    const session = cashService.getSession(sessionId)
    return session ? cashService.generateCashCount(session) : null
  }, [])

  const getCashStats = useCallback(() => cashService.getCashStats(), [])

  return {
    cashSessions,
    cashMovements,
    openCash,
    closeCash,
    addMovement,
    generateReport,
    getActiveSession,
    getExpectedBalance,
    getCashCount,
    getCashStats
  }
}

export default useCash
