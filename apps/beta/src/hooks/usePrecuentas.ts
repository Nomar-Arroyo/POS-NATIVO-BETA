import { useCallback } from 'react'
import { useStore } from '../store/store'
import precuentaService from '../services/precuentas/precuentaService'
import { Precuenta } from '../types'

export const usePrecuentas = () => {
  const { 
    precuentas, 
    setPrecuentas, 
    generatePrecuenta: createPrecuenta,
    addNotification 
  } = useStore()

  const generatePrecuenta = useCallback((tableId: string) => {
    const result = createPrecuenta(tableId)
    if (result.success) {
      addNotification({
        type: 'success',
        message: `Precuenta generada: ${result.precuenta.id} - Mesa ${tableId}`
      })
    } else {
      addNotification({
        type: 'error',
        message: result.message
      })
    }
    return result
  }, [createPrecuenta, addNotification])

  const getTicketHtml = useCallback((precuenta: Precuenta, width: 58 | 80 = 58) => {
    return precuentaService.generateTicketHtml(precuenta, width)
  }, [])

  const getPrecuentasByTable = useCallback((tableId: string) => {
    return precuentaService.getPrecuentasByTable(tableId)
  }, [])

  const deletePrecuenta = useCallback((precuentaId: string) => {
    precuentaService.deletePrecuenta(precuentaId)
    setPrecuentas(precuentas.filter(p => p.id !== precuentaId))
  }, [precuentas, setPrecuentas])

  const markAsPaid = useCallback((precuentaId: string) => {
    precuentaService.markAsPaid(precuentaId)
    setPrecuentas(precuentas.filter(p => p.id !== precuentaId))
    
    addNotification({
      type: 'success',
      message: 'Precuenta pagada y eliminada del historial'
    })
  }, [precuentas, setPrecuentas, addNotification])

  return {
    precuentas,
    generatePrecuenta,
    getTicketHtml,
    getPrecuentasByTable,
    deletePrecuenta,
    markAsPaid
  }
}

export default usePrecuentas