import { useCallback } from 'react'
import { useStore } from '../store/store'
import fiscalSimulationService from '../services/fiscal/fiscalSimulationService'
import cashService from '../services/cash/cashService'
import { Pago, AccountItem } from '../types'

export const useCheckout = () => {
  const {
    addFactura,
    setCashSessions,
    setCashMovements,
    addNotification 
  } = useStore()

  const processPayment = useCallback(async (
    items: AccountItem[],
    pagos: Pago[],
    customerRif: string | undefined,
    customerName: string | undefined,
    tableId?: string,
    userId: string = '1',
    options: { releaseTable?: boolean } = {}
  ): Promise<{ success: boolean; factId?: string; message: string }> => {
    try {
      // Crear simulación fiscal
      const factura = await fiscalSimulationService.createFiscalSimulation(
        items, pagos, customerRif, customerName, tableId
      )

      // Actualizar store
      addFactura(factura)

      // Si es una mesa, liberarla
      if (options.releaseTable !== false && tableId && tableId !== 'direct-sale') {
        const { tables, updateTable } = useStore.getState()
        const table = tables.find(t => t.id === tableId)
        
        if (table) {
          updateTable(tableId, {
            status: 'LIBRE',
            currentSession: undefined
          })
        }
      }

      const hasCashPayment = pagos.some(
        pago => pago.method === 'EFECTIVO USD' || pago.method === 'EFECTIVO Bs'
      )
      if (cashService.getActiveSession()) {
        cashService.registerSale(factura)
        setCashSessions(cashService.getSessions())
        setCashMovements(cashService.getMovements())
      } else if (hasCashPayment) {
        addNotification({
          type: 'warning',
          message: 'No hay caja abierta; el pago en efectivo no se registró en un turno'
        })
      }

      addNotification({
        type: 'success',
        message: `Factura ${factura.number} generada correctamente`
      })

      return { 
        success: true, 
        factId: factura.id,
        message: `Factura ${factura.number} generada correctamente`
      }
    } catch (error) {
      const message = (error as Error).message
      addNotification({
        type: 'error',
        message: `Error procesando pago: ${message}`
      })
      
      return { 
        success: false, 
        message: `Error procesando pago: ${message}`
      }
    }
  }, [addFactura, setCashSessions, setCashMovements, addNotification])

  const calculatePaymentSummary = useCallback((
    pagos: Pago[],
    totalUSD: number,
    exchangeRate: number
  ) => {
    const paidUSD = pagos
      .filter(p => p.currency === 'USD')
      .reduce((sum, p) => sum + p.amount, 0)
    
    const paidBs = pagos
      .filter(p => p.currency === 'Bs')
      .reduce((sum, p) => sum + p.amount, 0)
    
    const paidBsInUSD = paidBs / exchangeRate
    const totalPaidUSD = paidUSD + paidBsInUSD
    const remainingUSD = totalUSD - totalPaidUSD

    return {
      paidUSD,
      paidBs,
      totalPaidUSD,
      remainingUSD,
      isComplete: Math.abs(remainingUSD) < 0.01
    }
  }, [])

  return {
    processPayment,
    calculatePaymentSummary
  }
}

export default useCheckout