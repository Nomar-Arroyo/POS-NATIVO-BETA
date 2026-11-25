import React from 'react';
import { AccountItem } from '../../types';

interface CurrentOrderProps {
  items: AccountItem[];
  onUpdateItem: (itemId: string, quantity: number) => void;
  onRemoveItem: (itemId: string) => void;
}

const CurrentOrder: React.FC<CurrentOrderProps> = ({ items, onUpdateItem, onRemoveItem }) => (
  <div className="space-y-2">
    {items.map((item) => (
      <div key={item.id} className="flex items-center justify-between bg-gray-700 rounded-lg p-3">
        <span className="text-white">{item.product?.name || item.productId}</span>
        <div className="flex items-center space-x-2">
          <button type="button" onClick={() => onUpdateItem(item.id, item.quantity - 1)} className="px-2">-</button>
          <span>{item.quantity}</span>
          <button type="button" onClick={() => onUpdateItem(item.id, item.quantity + 1)} className="px-2">+</button>
          <button type="button" onClick={() => onRemoveItem(item.id)} className="text-red-400">Eliminar</button>
        </div>
      </div>
    ))}
  </div>
);

export default CurrentOrder;
