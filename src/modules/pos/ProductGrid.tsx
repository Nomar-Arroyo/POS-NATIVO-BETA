import React from 'react';
import { Product } from '../../types';

interface ProductGridProps {
  products: Product[];
  onAddItem: (product: Product, quantity?: number) => void;
}

const ProductGrid: React.FC<ProductGridProps> = ({ products, onAddItem }) => (
  <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
    {products.map((product) => (
      <button
        key={product.id}
        type="button"
        onClick={() => onAddItem(product)}
        className="bg-gray-700 rounded-lg p-4 text-left hover:bg-gray-600 transition-colors"
      >
        <h3 className="font-medium text-white">{product.name}</h3>
        <p className="text-amalfi-turquoise font-bold">${product.price.toFixed(2)}</p>
      </button>
    ))}
  </div>
);

export default ProductGrid;
