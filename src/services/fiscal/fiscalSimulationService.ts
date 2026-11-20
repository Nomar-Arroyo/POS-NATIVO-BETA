import storageService from '../storage/storageService'
import { Factura, Pago, Config, AccountItem } from '../../types'
import calculationService from '../calculations/calculationService'
import auditService from '../audit/auditService'

class FiscalSimulationService {
  // Simular transmisión fiscal SENIAT
  async simulateFiscalTransmission(): Promise<void> {
    // Simular delay de procesamiento
    const delays = [1500, 1800, 2000, 2200] // Variabilidad realista
    const delay = delays[Math.floor(Math.random() * delays.length)]
    
    await new Promise(resolve => setTimeout(resolve, delay))
  }

  // Generar número de control fiscal
  generateControlNumber(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    let result = ''
    
    // Formato: AAAA-MM-DD-XXXXXXXX (8 caracteres alfanuméricos)
    const date = new Date()
    const year = date.getFullYear().toString()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    
    for (let i = 0; i < 8; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length))
    }
    
    return `${year}-${month}-${day}-${result}`
  }

  // Generar número de factura correlativo
  generateFacturaNumber(): string {
    const facturas = storageService.getFacturas()
    const correlativo = (facturas.length + 1).toString().padStart(6, '0')
    const date = new Date()
    const year = date.getFullYear().toString().substr(-2)
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    
    return `F${year}${month}-${correlativo}`
  }

  // Calcular impuestos según tipo de producto
  calculateTaxes(
    items: AccountItem[],
    config: Config
  ): {
    subtotal: number;
    baseImponible: number;
    iva: number;
    igtf: number;
    total: number;
    exenciones: number;
  } {
    const subtotal = calculationService.calculateSubtotal(items)
    
    // Por ahora todos los productos están gravados con IVA
    // En una aplicación real, habría productos exentos
    const baseImponible = subtotal
    const iva = calculationService.calculateIVA(baseImponible, config.ivaRate)
    
    // IGTF solo aplica a pagos en divisas (según especificación)
    const igtf = calculationService.calculateIGTF(baseImponible, config.igtfRate)
    
    const total = Math.round((baseImponible + iva + igtf) * 100) / 100
    
    return {
      subtotal,
      baseImponible,
      iva,
      igtf,
      total,
      exenciones: 0 // Sin exenciones en esta versión
    }
  }

  // Crear simulación de factura fiscal
  async createFiscalSimulation(
    items: AccountItem[],
    pagos: Pago[],
    customerRif: string | undefined,
    customerName: string | undefined,
    tableId?: string
  ): Promise<Factura> {
    const config = storageService.getConfig()
    
    // Simular procesamiento fiscal
    await this.simulateFiscalTransmission()
    
    // Calcular impuestos
    const taxCalc = this.calculateTaxes(items, config)
    
    // Generar números fiscales
    const factNumber = this.generateFacturaNumber()
    const controlNumber = this.generateControlNumber()
    
    const factura: Factura = {
      id: `fact-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      number: factNumber,
      controlNumber,
      tableId,
      items: items.map(item => ({ ...item })),
      subtotal: taxCalc.subtotal,
      baseImponible: taxCalc.baseImponible,
      iva: taxCalc.iva,
      igtf: taxCalc.igtf,
      total: taxCalc.total,
      payments: pagos,
      customerRif,
      customerName,
      createdAt: new Date(),
      simulated: true
    }

    // Guardar en storage
    storageService.addFactura(factura)

    // Auditoría
    void auditService.logAction('FACTURA_SIMULADA', {
      factNumber,
      controlNumber,
      total: taxCalc.total,
      iva: taxCalc.iva,
      igtf: taxCalc.igtf,
      customerRif,
      customerName
    }, {
      tableId,
      factId: factura.id,
      category: 'PAYMENT'
    }).catch((error: unknown) => {
      console.error('Error registrando auditoría de factura simulada:', error)
    })

    return factura
  }

  // Validar RIF/Cédula
  validateRIF(rif: string): boolean {
    if (!rif) return false
    
    // Validación básica para RIF venezolano
    const rifPattern = /^[J,G,E]-\d{8}-\d$/
    return rifPattern.test(rif)
  }

  // Validar cédula
  validateCedula(cedula: string): boolean {
    if (!cedula) return false
    
    // Validación básica para cédula venezolana
    const cedulaPattern = /^[V,E]-\d{8}$/
    return cedulaPattern.test(cedula)
  }

  // Formatear datos fiscales para visualización
  formatFiscalData(factura: Factura): {
    numeroFactura: string;
    numeroControl: string;
    fecha: string;
    cliente: string;
    rifCliente: string;
    subtotal: string;
    baseImponible: string;
    iva: string;
    igtf: string;
    total: string;
  } {
    return {
      numeroFactura: factura.number,
      numeroControl: factura.controlNumber,
      fecha: new Date(factura.createdAt).toLocaleString('es-ES'),
      cliente: factura.customerName || 'CONSUMIDOR FINAL',
      rifCliente: factura.customerRif || 'N/A',
      subtotal: calculationService.formatCurrency(factura.subtotal, 'USD'),
      baseImponible: calculationService.formatCurrency(
        factura.baseImponible ?? factura.subtotal,
        'USD'
      ),
      iva: calculationService.formatCurrency(factura.iva, 'USD'),
      igtf: calculationService.formatCurrency(factura.igtf || 0, 'USD'),
      total: calculationService.formatCurrency(factura.total, 'USD')
    }
  }
}

export default new FiscalSimulationService()