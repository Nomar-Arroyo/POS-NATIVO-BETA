import { useCallback, useEffect, useRef } from 'react'
import { useStore } from '../store/store'

type NotificationType = 'success' | 'error' | 'warning' | 'info'

export const useNotification = () => {
  const addNotification = useStore(state => state.addNotification)
  const notificationQueue = useRef(new Map<string, number>())

  useEffect(() => () => {
    notificationQueue.current.forEach(timer => window.clearTimeout(timer))
    notificationQueue.current.clear()
  }, [])

  const addNotificationWithQueue = useCallback((
    type: NotificationType,
    message: string,
    duration = 5000
  ) => {
    const key = `${type}-${message}`
    if (notificationQueue.current.has(key)) return

    addNotification({ type, message })
    const timer = window.setTimeout(() => {
      notificationQueue.current.delete(key)
    }, Math.max(0, duration))
    notificationQueue.current.set(key, timer)
  }, [addNotification])

  const notifySuccess = useCallback(
    (message: string) => addNotificationWithQueue('success', message),
    [addNotificationWithQueue]
  )
  const notifyError = useCallback(
    (message: string) => addNotificationWithQueue('error', message),
    [addNotificationWithQueue]
  )
  const notifyWarning = useCallback(
    (message: string) => addNotificationWithQueue('warning', message),
    [addNotificationWithQueue]
  )
  const notifyInfo = useCallback(
    (message: string) => addNotificationWithQueue('info', message),
    [addNotificationWithQueue]
  )
  const notifySale = useCallback(
    (factNumber: string, total: number) =>
      notifySuccess(`Factura ${factNumber} generada - $${total.toFixed(2)}`),
    [notifySuccess]
  )
  const notifyPayment = useCallback(
    (method: string, amount: number) =>
      notifyInfo(`Pago ${method} registrado - $${amount.toFixed(2)}`),
    [notifyInfo]
  )
  const notifyErrorOperation = useCallback(
    (operation: string, error: string) => notifyError(`Error en ${operation}: ${error}`),
    [notifyError]
  )

  return {
    addNotificationWithQueue,
    notifySuccess,
    notifyError,
    notifyWarning,
    notifyInfo,
    notifySale,
    notifyPayment,
    notifyErrorOperation
  }
}

export default useNotification
