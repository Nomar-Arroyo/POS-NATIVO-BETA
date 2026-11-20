import { Order } from '../../types'
import printingService from './printingService'
import orderService from '../orders/orderService'

class OrderPrintingService {
  async printOrder(order: Order, width: 58 | 80 = 58): Promise<boolean> {
    try {
      // Generar HTML del ticket
      const ticketHtml = this.generateOrderTicketHtml(order, width)
      
      // Usar el servicio de impresión
      return await printingService.printThermalTicket(width, ticketHtml)
    } catch (error) {
      console.error('Error printing order:', error)
      return false
    }
  }

  private generateOrderTicketHtml(order: Order, width: 58 | 80): string {
    const styles = width === 58 ? `
      width: 58mm;
      font-size: 11px;
      line-height: 1.3;
    ` : `
      width: 80mm;
      font-size: 12px;
      line-height: 1.3;
    `

    const itemsHtml = order.items.map(item => `
      <div class="flex justify-between">
        <span>${item.quantity}x ${item.productName}</span>
        <span>$${item.total.toFixed(2)}</span>
      </div>
    `).join('')

    return `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Comanda ${order.orderNumber}</title>
        <style>
          body {
            margin: 0;
            padding: 10px;
            font-family: monospace;
            ${styles}
          }
          @media print {
            body { 
              width: ${width}mm;
              print-color-adjust: exact;
            }
          }
        </style>
      </head>
      <body>
        <div class="text-center border-b pb-2 mb-2">
          <h2 class="text-sm font-bold">CAFÉ ANALÍTICA C.A.</h2>
          <p class="text-xs">COMANDA ${order.station}</p>
        </div>

        <div class="mb-2 text-xs">
          <div class="flex justify-between">
            <span>Comanda:</span>
            <span class="font-bold">${order.orderNumber}</span>
          </div>
          <div class="flex justify-between">
            <span>Mesa:</span>
            <span>${order.tableId}</span>
          </div>
          <div class="flex justify-between">
            <span>Fecha:</span>
            <span>${new Date(order.createdAt).toLocaleString()}</span>
          </div>
        </div>

        <div class="border-t border-b py-2 mb-2">
          ${itemsHtml}
        </div>

        <div class="text-center text-xs">
          <p>Estado: ${order.status}</p>
          <p class="mt-1">¡Gracias por su preferencia!</p>
        </div>
      </body>
      </html>
    `
  }

  async printPendingOrders(station: 'COCINA' | 'BARRA'): Promise<boolean> {
    // Esta función imprimiría todas las órdenes pendientes de una estación
    // Por ahora solo imprimimos la primera orden pendiente
    const pendingOrders = orderService.getPendingOrders(station)
    if (pendingOrders.length > 0) {
      return await this.printOrder(pendingOrders[0])
    }
    return false
  }
}

export default new OrderPrintingService()