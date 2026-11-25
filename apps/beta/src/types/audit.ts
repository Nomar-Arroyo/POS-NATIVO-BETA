export interface AuditLog {
  id: string;
  timestamp: Date;
  user: string;
  action: string;
  details: any;
  tableId?: string;
  orderId?: string;
  productId?: string;
  precuentaId?: string;
  factId?: string;
  category: 'PRODUCT' | 'TABLE' | 'ORDER' | 'PAYMENT' | 'CASH' | 'SYSTEM' | 'USER';
  severity: 'INFO' | 'WARNING' | 'ERROR';
}

export interface Cancellation {
  id: string;
  timestamp: Date;
  user: string;
  reason: string;
  customReason?: string;
  type: 'PRODUCT' | 'ORDER' | 'ITEM';
  itemId: string;
  productName: string;
  quantity: number;
  amount: number;
  tableId?: string;
  orderId?: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  approvedBy?: string;
  approvedAt?: Date;
}

// Motivos de anulación predefinidos
export const CANCELLATION_REASONS = {
  PRODUCT_ERROR: 'Error de pedido',
  CLIENT_CHANGE: 'Cliente cambió de opinión',
  PRODUCT_GOTED: 'Producto agotado',
  PREPARATION_ERROR: 'Error de preparación',
  QUALITY_ISSUE: 'Problema de calidad',
  DUPLICATE: 'Artículo duplicado',
  PRICE_ERROR: 'Error de precio',
  OTHER: 'Otro motivo'
} as const;

export const AUDIT_CATEGORIES = {
  PRODUCT: 'PRODUCT',
  TABLE: 'TABLE',
  ORDER: 'ORDER',
  PAYMENT: 'PAYMENT',
  CASH: 'CASH',
  SYSTEM: 'SYSTEM',
  USER: 'USER'
} as const;

export const AUDIT_SEVERITY = {
  INFO: 'INFO',
  WARNING: 'WARNING',
  ERROR: 'ERROR'
} as const;