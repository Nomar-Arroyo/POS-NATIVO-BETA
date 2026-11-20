import { useCallback } from 'react'
import { useStore } from '../store/store'
import cancellationService from '../services/cancellations/cancellationService'

export const useCancellations = () => {
  const { addNotification } = useStore()

  const createCancellation = useCallback(async (
    type: 'PRODUCT' | 'ORDER' | 'ITEM',
    itemId: string,
    reason: string,
    customReason?: string,
    tableId?: string,
    orderId?: string
  ) => {
    try {
      const cancellation = await cancellationService.createCancellationRequest(
        type, itemId, reason, customReason, tableId, orderId
      )

      addNotification({
        type: 'warning',
        message: `Solicitud de anulación creada: ${cancellation.productName}`
      })

      return { success: true, cancellation }
    } catch (error) {
      return { success: false, message: (error as Error).message }
    }
  }, [addNotification])

  const approveCancellation = useCallback(async (
    cancellationId: string,
    approvedBy: string
  ) => {
    try {
      const cancellation = await cancellationService.approveCancellation(
        cancellationId, approvedBy
      )

      addNotification({
        type: 'success',
        message: `Anulación aprobada: ${cancellation.productName}`
      })

      return { success: true, cancellation }
    } catch (error) {
      return { success: false, message: (error as Error).message }
    }
  }, [addNotification])

  const rejectCancellation = useCallback(async (
    cancellationId: string,
    rejectedBy: string,
    reason: string
  ) => {
    try {
      const cancellation = await cancellationService.rejectCancellation(
        cancellationId, rejectedBy, reason
      )

      addNotification({
        type: 'info',
        message: `Anulación rechazada: ${cancellation.productName}`
      })

      return { success: true, cancellation }
    } catch (error) {
      return { success: false, message: (error as Error).message }
    }
  }, [addNotification])

  const getCancellationsByTable = useCallback((tableId: string) => {
    return cancellationService.getCancellationsByTable(tableId)
  }, [])

  const getCancellationsByDateRange = useCallback((startDate: Date, endDate: Date) => {
    return cancellationService.getCancellationsByDateRange(startDate, endDate)
  }, [])

  return {
    createCancellation,
    approveCancellation,
    rejectCancellation,
    getCancellationsByTable,
    getCancellationsByDateRange,
    getAvailableReasons: cancellationService.getAvailableReasons.bind(cancellationService)
  }
}

export default useCancellations