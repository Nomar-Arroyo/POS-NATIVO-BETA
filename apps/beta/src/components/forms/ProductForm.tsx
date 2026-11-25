import React, { useState, useEffect } from 'react'
import { useStore } from '../../store/store'
import Input from '../common/Input'
import Select from '../common/Select'
import Button from '../common/Button'
import { Product } from '../../types'

type ProductFormData = Omit<Product, 'id' | 'stock'> & { stock: number }

interface ProductFormProps {
  product?: Product | null
  onSubmit: (product: Omit<Product, 'id'>) => void
  onClose: () => void
}

const ProductForm: React.FC<ProductFormProps> = ({ 
  product, 
  onSubmit, 
  onClose 
}) => {
  const { categories } = useStore()
  const [formData, setFormData] = useState<ProductFormData>({
    name: '',
    description: '',
    category: '',
    price: 0,
    station: 'BARRA',
    available: true,
    active: true,
    stock: 0
  })
  const [errors, setErrors] = useState<Record<string, string>>({})

  useEffect(() => {
    if (product) {
      setFormData({
        name: product.name,
        description: product.description,
        category: product.category,
        price: product.price,
        station: product.station,
        available: product.available,
        active: product.active,
        stock: product.stock || 0
      })
    } else {
      // Reset para nuevo producto
      setFormData({
        name: '',
        description: '',
        category: categories.length > 0 ? categories[0].name : '',
        price: 0,
        station: 'BARRA',
        available: true,
        active: true,
        stock: 0
      })
    }
  }, [product, categories])

  const categoryOptions = categories.map(cat => ({
    value: cat.name,
    label: cat.name
  }))

  const stationOptions = [
    { value: 'COCINA', label: 'Cocina' },
    { value: 'BARRA', label: 'Barra' }
  ]

  const validate = () => {
    const newErrors: Record<string, string> = {}
    
    if (!formData.name.trim()) {
      newErrors.name = 'El nombre es obligatorio'
    } else if (formData.name.trim().length < 2) {
      newErrors.name = 'El nombre debe tener al menos 2 caracteres'
    }
    
    if (!formData.description.trim()) {
      newErrors.description = 'La descripción es obligatoria'
    } else if (formData.description.trim().length < 5) {
      newErrors.description = 'La descripción debe tener al menos 5 caracteres'
    }
    
    if (formData.price <= 0) {
      newErrors.price = 'El precio debe ser mayor a 0'
    }
    
    if (!formData.category) {
      newErrors.category = 'La categoría es obligatoria'
    }
    
    if (!formData.station) {
      newErrors.station = 'La estación es obligatoria'
    }
    
    if (formData.stock < 0) {
      newErrors.stock = 'El stock no puede ser negativo'
    }
    
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validate()) {
      // Si stock es 0, marcar como no disponible
      const submitData = {
        ...formData,
        available: formData.stock > 0 && formData.available
      }
      onSubmit(submitData)
    }
  }

  const handleStockChange = (value: number) => {
    setFormData(prev => ({
      ...prev,
      stock: value,
      available: value > 0 && prev.active
    }))
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input
          label="Nombre del Producto *"
          value={formData.name}
          onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
          error={errors.name}
          placeholder="Ej: Café Americano"
        />

        <Select
          label="Categoría *"
          options={categoryOptions}
          value={formData.category}
          onChange={(e) => setFormData(prev => ({ ...prev, category: e.target.value }))}
          error={errors.category}
        />
      </div>

      <Input
        label="Descripción *"
        value={formData.description}
        onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
        error={errors.description}
        placeholder="Descripción detallada del producto"
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Input
          label="Precio (USD) *"
          type="number"
          step="0.01"
          min="0"
          value={formData.price}
          onChange={(e) => setFormData(prev => ({ ...prev, price: parseFloat(e.target.value) || 0 }))}
          error={errors.price}
        />

        <Select
          label="Estación *"
          options={stationOptions}
          value={formData.station}
          onChange={(e) => setFormData(prev => ({ ...prev, station: e.target.value as 'COCINA' | 'BARRA' }))}
          error={errors.station}
        />

        <Input
          label="Stock Inicial"
          type="number"
          min="0"
          value={formData.stock}
          onChange={(e) => handleStockChange(parseInt(e.target.value) || 0)}
          error={errors.stock}
          helperText="0 = Agotado"
        />
      </div>

      <div className="flex space-x-6">
        <label className="flex items-center">
          <input
            type="checkbox"
            checked={formData.active}
            onChange={(e) => setFormData(prev => ({ 
              ...prev, 
              active: e.target.checked,
              available: e.target.checked && formData.stock > 0
            }))}
            className="rounded bg-gray-700 border-gray-600 text-amalfi-turquoise focus:ring-amalfi-turquoise"
          />
          <span className="ml-2 text-sm text-gray-300">Producto Activo</span>
        </label>

        <label className="flex items-center">
          <input
            type="checkbox"
            checked={formData.available}
            onChange={(e) => setFormData(prev => ({ 
              ...prev, 
              available: e.target.checked && formData.active && formData.stock > 0
            }))}
            disabled={formData.stock === 0}
            className="rounded bg-gray-700 border-gray-600 text-amalfi-turquoise focus:ring-amalfi-turquoise disabled:opacity-50"
          />
          <span className="ml-2 text-sm text-gray-300">
            Disponible {formData.stock === 0 && '(Stock agotado)'}
          </span>
        </label>
      </div>

      {formData.stock === 0 && (
        <div className="p-3 bg-yellow-900 bg-opacity-20 rounded-lg border border-yellow-700">
          <p className="text-sm text-yellow-300">
            <strong>Nota:</strong> Con stock 0, el producto no estará disponible 
            para venta hasta que se actualice el stock.
          </p>
        </div>
      )}

      <div className="flex justify-end space-x-3 pt-4 border-t border-gray-700">
        <Button type="button" variant="secondary" onClick={onClose}>
          Cancelar
        </Button>
        <Button type="submit" variant="primary">
          {product ? 'Actualizar Producto' : 'Guardar Producto'}
        </Button>
      </div>
    </form>
  )
}

export default ProductForm