export interface Order {
  id: string;
  tableId: string;
  items: OrderItem[];
  station: 'COCINA' | 'BARRA';
  status: 'pendiente' | 'en preparación' | 'listo' | 'entregado' | 'cancelado';
  createdAt: Date;
  sentAt?: Date;
  readyAt?: Date;
  deliveredAt?: Date;
  userId: string;
  notes?: string;
  orderNumber: string;
}

export interface OrderItem {
  productId: string;
  productName: string;
  quantity: number;
  unitPrice: number;
  notes?: string;
  total: number;
}

// Estados de órdenes
export const ORDER_STATUS = {
  PENDIENTE: 'pendiente',
  EN_PREPARACION: 'en preparación',
  LISTO: 'listo',
  ENTREGADO: 'entregado',
  CANCELADO: 'cancelado'
} as const;

export const STATIONS = {
  COCINA: 'COCINA',
  BARRA: 'BARRA'
} as const;