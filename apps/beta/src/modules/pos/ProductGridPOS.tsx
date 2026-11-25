import React from 'react'
import { Product } from '../../types'
import Badge from '../../components/common/Badge'
import { ExclamationTriangleIcon } from '@/components/common/Icon'

interface ProductGridPOSProps {
  products: Product[]
  onAddProduct: (product: Product) => void
  searchTerm?: string
  selectedCategory?: string
}

const ProductGridPOS: React.FC<ProductGridPOSProps> = ({
  products,
  onAddProduct,
  searchTerm,
  selectedCategory
}) => {
  if (products.length === 0) {
    return (
      <div className="text-center py-8">
        <ExclamationTriangleIcon className="h-12 w-12 text-gray-500 mx-auto mb-2" />
        <p className="text-gray-400">
          {searchTerm || (selectedCategory && selectedCategory !== 'Todas')
            ? 'No se encontraron productos con los filtros aplicados'
            : 'No hay productos disponibles'
          }
        </p>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
      {products.map(product => (
        <button
          key={product.id}
          type="button"
          onClick={() => onAddProduct(product)}
          disabled={!product.available || !product.active}
          className={`
            p-3 rounded-lg border-2 transition-all duration-200 text-left
            hover:transform hover:scale-105
            ${product.available && product.active
              ? 'bg-gray-800 border-gray-700 hover:border-amalfi-turquoise hover:bg-gray-750'
              : 'bg-gray-900 border-gray-800 opacity-50 cursor-not-allowed'
            }
          `}
        >
          <div className="flex flex-col items-center text-center">
            <h4 className="font-medium text-white text-sm mb-1 line-clamp-2">
              {product.name}
            </h4>

            <div className="text-amalfi-turquoise font-bold text-lg mb-2">
              ${product.price.toFixed(2)}
            </div>

            <div className="flex items-center space-x-1 mb-1">
              <Badge variant="default" size="sm">
                {product.category}
              </Badge>
              <Badge
                variant={product.station === 'COCINA' ? 'info' : 'warning'}
                size="sm"
              >
                {product.station}
              </Badge>
            </div>

            {product.stock !== undefined && (
              <div className={`text-xs ${
                product.stock === 0
                  ? 'text-red-400'
                  : product.stock < 10
                    ? 'text-yellow-400'
                    : 'text-green-400'
              }`}>
                Stock: {product.stock}
              </div>
            )}
          </div>
        </button>
      ))}
    </div>
  )
}

export default ProductGridPOS
