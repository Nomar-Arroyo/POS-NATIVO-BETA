export const CONSTANTS = {
  APP_NAME: 'POS Nativo Beta',
  APP_VERSION: '1.0.0-beta',
  ESTABLISHMENT_NAME: 'CAFÉ ANALÍTICA C.A.',
  TAX_ID: 'J-12345678-9',
  
  // Monedas
  CURRENCIES: {
    USD: 'USD',
    Bs: 'Bs'
  },
  
  // Métodos de pago
  PAYMENT_METHODS: {
    EFECTIVO_USD: 'EFECTIVO USD',
    EFECTIVO_BS: 'EFECTIVO Bs',
    PUNTO_DE_VENTA: 'PUNTO DE VENTA',
    PAGO_MOVIL: 'PAGO MÓVIL',
    ZELLE: 'ZELLE'
  },
  
  // Estados de mesas
  TABLE_STATUS: {
    LIBRE: 'LIBRE',
    OCUPADA: 'OCUPADA',
    PRECUENTA_EMITIDA: 'PRECUENTA EMITIDA'
  },
  
  // Estados de comandas
  ORDER_STATUS: {
    PENDIENTE: 'pendiente',
    EN_PREPARACION: 'en preparación',
    LISTO: 'listo',
    ENTREGADO: 'entregado',
    CANCELADO: 'cancelado'
  },
  
  // Estaciones
  STATIONS: {
    COCINA: 'COCINA',
    BARRA: 'BARRA'
  },
  
  // Porcentes fiscales
  FISCAL_RATES: {
    IVA: 0.16,
    IGTF: 0.03
  },
  
  // Tamaños de ticket
  TICKET_WIDTHS: {
    MM_58: 58,
    MM_80: 80
  }
}

export default CONSTANTS