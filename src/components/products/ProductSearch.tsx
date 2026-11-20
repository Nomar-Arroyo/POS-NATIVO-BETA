import React, { useState, useEffect, useRef } from 'react'
import { useProducts } from '../../hooks/useProducts'
import { Product } from '../../types'
import Input from '../common/Input'
import Badge from '../common/Badge'

interface ProductSearchProps {
  onProductSelect: (product: Product) => void
  placeholder?: string
  className?: string
}

const ProductSearch: React.FC<ProductSearchProps> = ({ 
  onProductSelect, 
  placeholder = "Buscar producto...",
  className = '' 
}) => {
  const { searchProducts } = useProducts()
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Product[]>([])
  const [isOpen, setIsOpen] = useState(false)
  const searchRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (query.trim().length >= 2) {
      const products = searchProducts(query)
      setResults(products)
      setIsOpen(true)
    } else {
      setResults([])
      setIsOpen(false)
    }
  }, [query, searchProducts])

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const handleSelect = (product: Product) => {
    onProductSelect(product)
    setQuery('')
    setResults([])
    setIsOpen(false)
  }

  return (
    <div ref={searchRef} className={`relative ${className}`}>
      <Input
        placeholder={placeholder}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onFocus={() => query.length >= 2 && setIsOpen(true)}
      />

      {isOpen && results.length > 0 && (
        <div className="absolute z-50 mt-1 w-full bg-gray-800 border border-gray-700 rounded-lg shadow-xl max-h-60 overflow-y-auto">
          {results.map((product) => (
            <button
              key={product.id}
              onClick={() => handleSelect(product)}
              className="w-full flex items-center justify-between p-3 hover:bg-gray-700 transition-colors text-left"
            >
              <div className="flex-1">
                <div className="font-medium text-white">{product.name}</div>
                <div className="text-xs text-gray-400">{product.description}</div>
              </div>
              <div className="flex items-center space-x-2">
                <Badge 
                  variant={product.station === 'COCINA' ? 'info' : 'warning'}
                  size="sm"
                >
                  {product.station}
                </Badge>
                <span className="font-bold text-amalfi-turquoise">
                  ${product.price.toFixed(2)}
                </span>
              </div>
            </button>
          ))}
        </div>
      )}

      {isOpen && results.length === 0 && query.length >= 2 && (
        <div className="absolute z-50 mt-1 w-full bg-gray-800 border border-gray-700 rounded-lg shadow-xl p-4 text-center">
          <p className="text-gray-400">No se encontraron productos</p>
        </div>
      )}
    </div>
  )
}

export default ProductSearch
