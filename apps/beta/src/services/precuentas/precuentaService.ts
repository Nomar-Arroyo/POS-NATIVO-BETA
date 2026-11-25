import storageService from '../storage/storageService'
import { Precuenta } from '../../types'
import calculationService from '../calculations/calculationService'
import auditService from '../audit/auditService'

class PrecuentaService {
  generatePrecuenta(tableId: string): Precuenta {
    const table = storageService.getTable(tableId)
    if (!table?.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const session = table.currentSession
    const config = storageService.getConfig()
    const activeItems = session.items.filter(item => !item.cancelled)

    if (activeItems.length === 0) {
      throw new Error('No hay artículos para generar la precuenta')
    }

    const subtotalUSD = calculationService.calculateSubtotal(activeItems)
    const totalUSD = subtotalUSD
    const totalBs = calculationService.convertUSDToBs(
      totalUSD,
      config.exchangeRate
    )
    const precuenta: Precuenta = {
      id: `pre-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      tableId,
      sessionId: session.sessionId,
      items: activeItems,
      subtotalUSD,
      totalUSD,
      totalBs,
      generatedAt: new Date()
    }

    storageService.updateTable(tableId, {
      status: 'PRECUENTA EMITIDA',
      currentSession: {
        ...session,
        precuentaGenerated: true,
        updatedAt: new Date()
      }
    })
    storageService.addPrecuenta(precuenta)

    void auditService.logTableAction('PRECUENTA', tableId, {
      precuentaId: precuenta.id,
      totalUSD: precuenta.totalUSD,
      totalBs: precuenta.totalBs,
      itemsCount: activeItems.length
    })

    return precuenta
  }

  generateTicketHtml(precuenta: Precuenta, width: 58 | 80 = 58): string {
    const config = storageService.getConfig()
    const table = storageService.getTable(precuenta.tableId)
    const itemsHtml = precuenta.items.map(item => {
      const product = storageService.getProduct(item.productId)
      const productName = this.escapeHtml(product?.name || 'Producto')
      const total = item.quantity * item.unitPrice

      return `
        <tr>
          <td class="qty">${item.quantity}x</td>
          <td class="product">${productName}</td>
          <td class="price">$${item.unitPrice.toFixed(2)}</td>
          <td class="total">$${total.toFixed(2)}</td>
        </tr>
      `
    }).join('')

    const ticketWidth = width === 58 ? '58mm' : '80mm'
    const fontSize = width === 58 ? '12px' : '14px'
    const establishmentName = this.escapeHtml(config.establishmentName.toUpperCase())
    const taxId = this.escapeHtml(config.taxId)
    const precuentaId = this.escapeHtml(precuenta.id)
    const tableName = this.escapeHtml(table?.name || precuenta.tableId)
    const generatedAt = this.escapeHtml(
      new Date(precuenta.generatedAt).toLocaleString('es-ES')
    )

    return `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>Precuenta ${precuentaId}</title>
        <style>
          @page {
            margin: 0;
            size: ${ticketWidth} auto;
          }

          body {
            font-family: 'Courier New', monospace;
            font-size: ${fontSize};
            line-height: 1.4;
            margin: 0;
            padding: 10px;
            color: #000;
            background: #fff;
            width: ${ticketWidth};
          }

          .ticket {
            width: 100%;
          }

          .header {
            text-align: center;
            border-bottom: 1px dashed #000;
            padding-bottom: 10px;
            margin-bottom: 10px;
          }

          .establishment-name {
            font-size: ${width === 58 ? '16px' : '18px'};
            font-weight: bold;
            margin: 0 0 5px 0;
          }

          .tax-id {
            font-size: 10px;
            margin: 0 0 10px 0;
          }

          .ticket-info {
            margin-bottom: 10px;
            font-size: 10px;
          }

          .info-line {
            display: flex;
            justify-content: space-between;
            margin-bottom: 3px;
          }

          .items {
            margin-bottom: 10px;
          }

          table {
            width: 100%;
            border-collapse: collapse;
          }

          th {
            text-align: left;
            border-bottom: 1px solid #000;
            padding-bottom: 5px;
            font-size: 10px;
          }

          td {
            padding: 3px 0;
            vertical-align: top;
          }

          .qty {
            width: 15%;
            text-align: left;
          }

          .product {
            width: 45%;
            text-align: left;
          }

          .price {
            width: 20%;
            text-align: right;
          }

          .total {
            width: 20%;
            text-align: right;
          }

          .totals {
            border-top: 1px solid #000;
            padding-top: 10px;
            margin-top: 10px;
          }

          .total-line {
            display: flex;
            justify-content: space-between;
            margin-bottom: 5px;
          }

          .grand-total {
            font-weight: bold;
            font-size: ${width === 58 ? '14px' : '16px'};
            border-top: 1px solid #000;
            padding-top: 5px;
            margin-top: 5px;
          }

          .footer {
            text-align: center;
            margin-top: 15px;
            padding-top: 10px;
            border-top: 1px dashed #000;
            font-size: 10px;
          }

          .footer-message {
            margin-bottom: 5px;
          }

          @media print {
            body {
              margin: 0;
              padding: 5px;
            }
          }
        </style>
      </head>
      <body>
        <div class="ticket">
          <div class="header">
            <div class="establishment-name">${establishmentName}</div>
            <div class="tax-id">RIF: ${taxId}</div>
            <div class="ticket-info">
              <div class="info-line">
                <span>PRECUENTA:</span>
                <span>${precuentaId}</span>
              </div>
              <div class="info-line">
                <span>MESA:</span>
                <span>${tableName}</span>
              </div>
              <div class="info-line">
                <span>FECHA:</span>
                <span>${generatedAt}</span>
              </div>
            </div>
          </div>

          <div class="items">
            <table>
              <thead>
                <tr>
                  <th class="qty">Cant</th>
                  <th class="product">Producto</th>
                  <th class="price">P.U.</th>
                  <th class="total">Total</th>
                </tr>
              </thead>
              <tbody>
                ${itemsHtml}
              </tbody>
            </table>
          </div>

          <div class="totals">
            <div class="total-line">
              <span>Subtotal:</span>
              <span>$${precuenta.subtotalUSD.toFixed(2)}</span>
            </div>
            <div class="total-line grand-total">
              <span>TOTAL:</span>
              <span>$${precuenta.totalUSD.toFixed(2)} / Bs. ${precuenta.totalBs.toFixed(2)}</span>
            </div>
          </div>

          <div class="footer">
            <div class="footer-message">PRECUENTA - DOCUMENTO NO FISCAL</div>
            <div class="footer-message">REVISE SU CUENTA</div>
            <div class="footer-message">¡Gracias por su preferencia!</div>
          </div>
        </div>
      </body>
      </html>
    `
  }

  getPrecuenta(id: string): Precuenta | undefined {
    return storageService.getPrecuentas().find(precuenta => precuenta.id === id)
  }

  getPrecuentasByTable(tableId: string): Precuenta[] {
    return storageService.getPrecuentas().filter(
      precuenta => precuenta.tableId === tableId
    )
  }

  getAllPrecuentas(): Precuenta[] {
    return storageService.getPrecuentas()
  }

  deletePrecuenta(precuentaId: string): boolean {
    const precuentas = storageService.getPrecuentas()
    const updatedPrecuentas = precuentas.filter(
      precuenta => precuenta.id !== precuentaId
    )
    if (updatedPrecuentas.length === precuentas.length) return false

    storageService.setPrecuentas(updatedPrecuentas)
    return true
  }

  markAsPaid(precuentaId: string): void {
    const precuenta = this.getPrecuenta(precuentaId)
    if (!precuenta) throw new Error('Precuenta no encontrada')

    this.deletePrecuenta(precuentaId)

    void auditService.logAction('PRECUENTA_PAGADA', {
      precuentaId,
      tableId: precuenta.tableId,
      totalUSD: precuenta.totalUSD
    }, {
      tableId: precuenta.tableId,
      category: 'TABLE',
      severity: 'INFO'
    })
  }

  private escapeHtml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
  }
}

export default new PrecuentaService()
