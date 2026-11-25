import { useCallback, useEffect, useState } from 'react'
import { useStore } from '../store/store'
import {
  fetchBcvExchangeRate,
  isBcvRateRefreshDue
} from '../services/exchangeRate/bcvExchangeRateService'

type RefreshResult =
  | { success: true }
  | { success: false; message: string }

let automaticRefreshDate: string | undefined

export const useBcvExchangeRate = () => {
  const setBcvExchangeRate = useStore(state => state.setBcvExchangeRate)
  const applyBcvExchangeRate = useStore(state => state.applyBcvExchangeRate)
  const addNotification = useStore(state => state.addNotification)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string>()

  const refreshBcvRate = useCallback(async (
    applyRate = false
  ): Promise<RefreshResult> => {
    setIsLoading(true)
    setError(undefined)

    try {
      const result = await fetchBcvExchangeRate()
      setBcvExchangeRate(result.rate, result.rateDate, result.retrievedAt)
      if (applyRate) {
        applyBcvExchangeRate()
      }
      return { success: true }
    } catch (caughtError) {
      const message = caughtError instanceof Error
        ? caughtError.message
        : 'Error desconocido consultando el BCV'
      setError(message)
      return { success: false, message }
    } finally {
      setIsLoading(false)
    }
  }, [applyBcvExchangeRate, setBcvExchangeRate])

  const refreshIfDue = useCallback(async () => {
    const config = useStore.getState().config
    if (!isBcvRateRefreshDue(config.bcvLastCheckedAt)) return
    const today = new Intl.DateTimeFormat('en-US', {
      timeZone: 'America/Caracas',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    }).format(new Date())
    if (automaticRefreshDate === today) return
    automaticRefreshDate = today

    const result = await refreshBcvRate()
    if (!result.success) {
      addNotification({
        type: 'warning',
        message: `No se pudo actualizar la tasa desde el BCV. Se conserva la tasa actual. ${result.message}`
      })
    }
  }, [addNotification, refreshBcvRate])

  useEffect(() => {
    void refreshIfDue()
    const intervalId = setInterval(() => {
      void refreshIfDue()
    }, 60 * 60 * 1000)

    return () => clearInterval(intervalId)
  }, [refreshIfDue])

  return {
    isLoading,
    error,
    refreshBcvRate
  }
}

export default useBcvExchangeRate
