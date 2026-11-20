import { useCallback } from 'react'
import printingService from '../services/printing/printingService'
import orderPrintingService from '../services/printing/orderPrintingService'
import precuentaService from '../services/precuentas/precuentaService'
import { Order, Precuenta } from '../types'

export const usePrinting = () => {
  const printHtml = useCallback(async (
    htmlContent: string, 
    title: string = 'Documento',
    width: 58 | 80 = 58
  ) => {
    try {
      return await printingService.printElement(htmlContent, title, width)
    } catch (error) {
      console.error('Error in printHtml:', error)
      return false
    }
  }, [])

  const printPrecuenta = useCallback(async (
    precuenta: Precuenta,
    width: 58 | 80 = 58
  ) => {
    try {
      // Generar HTML de la precuenta
      const ticketHtml = precuentaService.generateTicketHtml(precuenta, width)
      return await printHtml(ticketHtml, `Precuenta ${precuenta.id}`, width)
    } catch (error) {
      console.error('Error printing precuenta:', error)
      return false
    }
  }, [printHtml])

  const printOrder = useCallback(async (
    order: Order,
    width: 58 | 80 = 58
  ) => {
    try {
      return await orderPrintingService.printOrder(order, width)
    } catch (error) {
      console.error('Error printing order:', error)
      return false
    }
  }, [printHtml])

  return {
    printHtml,
    printPrecuenta,
    printOrder
  }
}

export default usePrinting