import { useCallback } from 'react'
import { useStore } from '../store/store'
import splitBillService from '../services/splitBill/splitBillService'
import type { SplitBill, SplitOptions, SplitPayment } from '../types/splitBill'

export const useSplitBill = () => {
  const { updateTable, addNotification } = useStore()

  const createSplit = useCallback((
    tableId: string,
    options: SplitOptions
  ): { success: boolean; splitBill?: SplitBill; message?: string } => {
    try {
      const splitBill = splitBillService.createSplitBill(tableId, options)
      const table = useStore.getState().tables.find(candidate => candidate.id === tableId)
      if (table?.currentSession?.sessionId === splitBill.originalSessionId) {
        updateTable(tableId, {
          currentSession: {
            ...table.currentSession,
            splitBillId: splitBill.id,
            updatedAt: new Date()
          }
        })
      }

      addNotification({
        type: 'success',
        message: `División creada: ${splitBill.splits.length} cuentas`
      })

      return { success: true, splitBill }
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : 'No se pudo crear la división'
      addNotification({ type: 'error', message })
      return { success: false, message }
    }
  }, [addNotification, updateTable])

  const addPayment = useCallback((
    splitBillId: string,
    splitId: string,
    payment: Omit<SplitPayment, 'id' | 'timestamp'>
  ): { success: boolean; splitBill?: SplitBill; message?: string } => {
    try {
      const splitBill = splitBillService.addPaymentToSplit(
        splitBillId,
        splitId,
        payment
      )

      if (splitBill.status === 'COMPLETED') {
        const table = useStore.getState().tables.find(
          candidate => candidate.id === splitBill.tableId
        )
        if (table?.currentSession?.sessionId === splitBill.originalSessionId) {
          updateTable(splitBill.tableId, {
            status: 'LIBRE',
            currentSession: undefined
          })
        }
      }

      const splitName = splitBill.splits.find(split => split.id === splitId)?.name
      addNotification({
        type: 'success',
        message: `Pago agregado a ${splitName || 'la cuenta'}`
      })

      return { success: true, splitBill }
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : 'No se pudo agregar el pago'
      addNotification({ type: 'error', message })
      return { success: false, message }
    }
  }, [addNotification, updateTable])

  const getSplitByTable = useCallback((tableId: string): SplitBill | undefined => {
    return splitBillService.getSplitBillByTable(tableId)
  }, [])

  const canRelease = useCallback((tableId: string): boolean => {
    return splitBillService.canReleaseTable(tableId)
  }, [])

  const cancelSplit = useCallback((
    splitBillId: string
  ): { success: boolean; message?: string } => {
    try {
      const splitBill = splitBillService.getSplitBill(splitBillId)
      splitBillService.cancelSplitBill(splitBillId)

      if (splitBill) {
        const table = useStore.getState().tables.find(
          candidate => candidate.id === splitBill.tableId
        )
        if (table?.currentSession?.sessionId === splitBill.originalSessionId) {
          updateTable(splitBill.tableId, {
            status: table.currentSession.precuentaGenerated
              ? 'PRECUENTA EMITIDA'
              : 'OCUPADA',
            currentSession: {
              ...table.currentSession,
              splitBillId: undefined,
              updatedAt: new Date()
            }
          })
        }
      }

      addNotification({
        type: 'warning',
        message: 'División cancelada'
      })

      return { success: true }
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : 'No se pudo cancelar la división'
      addNotification({ type: 'error', message })
      return { success: false, message }
    }
  }, [addNotification, updateTable])

  return {
    createSplit,
    addPayment,
    getSplitByTable,
    canRelease,
    cancelSplit
  }
}

export default useSplitBill
