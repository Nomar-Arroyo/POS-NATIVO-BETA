import { AccountItem } from './index';

export interface SplitBill {
  id: string;
  tableId: string;
  originalSessionId: string;
  splits: Split[];
  createdAt: Date;
  updatedAt: Date;
  status: 'ACTIVE' | 'COMPLETED' | 'CANCELLED';
  totalUSD: number;
  totalBs: number;
}

export interface Split {
  id: string;
  name: string;
  items: AccountItem[];
  subtotalUSD: number;
  subtotalBs: number;
  paid: boolean;
  paidAt?: Date;
  payments: SplitPayment[];
}

export interface SplitPayment {
  id: string;
  method: string;
  amount: number;
  currency: 'USD' | 'Bs';
  exchangeRate?: number;
  reference?: string;
  timestamp: Date;
}

// Opciones para división
export const SPLIT_MODES = {
  BY_ITEM: 'BY_ITEM',
  BY_PERCENTAGE: 'BY_PERCENTAGE',
  BY_AMOUNT: 'BY_AMOUNT',
  EQUAL: 'EQUAL'
} as const;

export interface SplitOptions {
  mode: keyof typeof SPLIT_MODES;
  splitCount: number;
  assignItems: Record<string, string[]>; // splitId -> itemIds
  percentages?: Record<string, number>; // splitId -> percentage
  amounts?: Record<string, number>; // splitId -> amount
  names?: Record<string, string>; // splitId -> name
}