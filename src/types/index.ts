// Tipos base
export interface User {
  id: string;
  name: string;
  role: 'admin' | 'cashier' | 'chef' | 'waiter';
  active: boolean;
}

export interface Config {
  establishmentName: string;
  taxId: string;
  currency: 'USD' | 'Bs';
  exchangeRate: number;
  exchangeRateSource?: 'BCV' | 'MANUAL';
  exchangeRateUpdatedAt?: string;
  bcvRate?: number;
  bcvRateDate?: string;
  bcvLastCheckedAt?: string;
  ivaRate: number; // 0.16
  igtfRate: number; // 0.03
  fiscalSimulation: boolean;
  printWidth: 58 | 80;
}

export interface Product {
  id: string;
  name: string;
  description: string;
  category: string;
  price: number; // en USD
  station: 'COCINA' | 'BARRA';
  available: boolean;
  active: boolean;
  image?: string;
  stock?: number;
}

export interface Category {
  id: string;
  name: string;
  order: number;
}

// Tipos de mesas
export interface Table {
  id: string;
  name: string;
  capacity: number;
  status: 'LIBRE' | 'OCUPADA' | 'PRECUENTA EMITIDA';
  currentSession?: TableSession;
  position: { x: number; y: number };
}

export interface TableSession {
  sessionId: string;
  tableId: string;
  items: AccountItem[];
  precuentaGenerated: boolean;
  totalUSD: number;
  totalBs: number;
  createdAt: Date;
  updatedAt: Date;
  splitBillId?: string;
}

export interface AccountItem {
  id: string;
  productId: string;
  product?: Product;
  quantity: number;
  unitPrice: number;
  notes?: string;
  sent: boolean;
  cancelled: boolean;
}

export { ORDER_STATUS, STATIONS } from './orders';
export type { Order, OrderItem } from './orders';

// Tipos de precuenta
export interface Precuenta {
  id: string;
  tableId: string;
  sessionId: string;
  items: AccountItem[];
  subtotalUSD: number;
  totalUSD: number;
  totalBs: number;
  generatedAt: Date;
}

// Tipos de pago
export interface Pago {
  id: string;
  method: 'EFECTIVO USD' | 'EFECTIVO Bs' | 'PUNTO DE VENTA' | 'PAGO MÓVIL' | 'ZELLE';
  amount: number;
  currency: 'USD' | 'Bs';
  reference?: string;
}

// Tipos de facturas
export interface Factura {
  id: string;
  number: string;
  controlNumber: string;
  tableId?: string;
  orderId?: string;
  items: AccountItem[];
  subtotal: number;
  baseImponible?: number;
  iva: number;
  igtf?: number;
  total: number;
  payments: Pago[];
  customerRif?: string;
  customerName?: string;
  createdAt: Date;
  simulated: boolean;
}

export { AUDIT_CATEGORIES, AUDIT_SEVERITY, CANCELLATION_REASONS } from './audit';
export type { AuditLog, Cancellation } from './audit';

export type {
  CashCount,
  CashMovement,
  CashReport,
  CashSession
} from './cash'
export { Bs_BILLS, COINS, USD_BILLS } from './cash'