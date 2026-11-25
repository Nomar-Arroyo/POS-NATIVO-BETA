import React, { useState } from 'react'
import { useProducts } from '../../hooks/useProducts'
import ProductModal from '../../components/modals/ProductModal'
import Table from '../../components/common/Table'
import Card from '../../components/common/Card'
import Button from '../../components/common/Button'
import Input from '../../components/common/Input'
import Select from '../../components/common/Select'
import Badge from '../../components/common/Badge'
import { Product } from '../../types'

const Products: React.FC = () => {
  const { 
    products, 
    categories,
    addProduct, 
    updateProduct, 
    searchProducts,
    getActiveProducts,
    getStats
  } = useProducts()
  
  const [showModal, setShowModal] = useState(false)
  const [editingProduct, setEditingProduct] = useState<Product | null>(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('Todas')
  const [showInactive, setShowInactive] = useState(false)

  // Filtrar productos
  const filteredProducts = React.useMemo(() => {
    let result = showInactive ? products : getActiveProducts()

    if (searchTerm) {
      result = searchProducts(searchTerm)
    }

    if (selectedCategory !== 'Todas') {
      result = result.filter(p => p.category === selectedCategory)
    }

    return result
  }, [products, showInactive, searchTerm, selectedCategory, searchProducts, getActiveProducts])

  const categoryOptions = [
    { value: 'Todas', label: 'Todas las Categorías' },
    ...categories.map(cat => ({ value: cat.name, label: cat.name }))
  ]

  const handleAddProduct = (productData: Omit<Product, 'id'>) => {
    const result = addProduct(productData)
    if (result.success) {
      setShowModal(false)
    } else {
      alert(result.message)
    }
  }

  const handleUpdateProduct = (productData: Omit<Product, 'id'>) => {
    if (editingProduct) {
      const result = updateProduct(editingProduct.id, productData)
      if (result.success) {
        setEditingProduct(null)
        setShowModal(false)
      } else {
        alert(result.message)
      }
    }
  }

  const handleEdit = (product: Product) => {
    setEditingProduct(product)
    setShowModal(true)
  }

  const stats = getStats()

  const columns = [
    {
      key: 'name' as keyof Product,
      header: 'Producto',
      render: (name: string, product: Product) => (
        <div>
          <div className="font-medium text-white">{name}</div>
          <div className="text-xs text-gray-400">{product.description}</div>
        </div>
      )
    },
    {
      key: 'category' as keyof Product,
      header: 'Categoría'
    },
    {
      key: 'price' as keyof Product,
      header: 'Precio',
      render: (price: number) => `$${price.toFixed(2)}`
    },
    {
      key: 'station' as keyof Product,
      header: 'Estación',
      render: (station: string) => (
        <Badge 
          variant={station === 'COCINA' ? 'info' : 'warning'}
          size="sm"
        >
          {station}
        </Badge>
      )
    },
    {
      key: 'stock' as keyof Product,
      header: 'Stock',
      render: (stock: number | undefined, product: Product) => {
        if (stock === undefined) return 'N/A'
        
        if (stock === 0) {
          return <Badge variant="error" size="sm">Agotado</Badge>
        } else if (stock < 10) {
          return <Badge variant="warning" size="sm">{stock}</Badge>
        } else {
          return <Badge variant="success" size="sm">{stock}</Badge>
        }
      }
    },
    {
      key: 'active' as keyof Product,
      header: 'Estado',
      render: (active: boolean, product: Product) => (
        <div className="flex space-x-1">
          <Badge 
            variant={active ? 'success' : 'error'} 
            size="sm"
          >
            {active ? 'Activo' : 'Inactivo'}
          </Badge>
          <Badge 
            variant={product.available ? 'info' : 'warning'} 
            size="sm"
          >
            {product.available ? 'Disp.' : 'No Disp.'}
          </Badge>
        </div>
      )
    }
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Catálogo de Productos</h2>
          <p className="text-gray-400">Gestiona los productos del establecimiento</p>
        </div>
        <Button variant="primary" onClick={() => setShowModal(true)}>
          + Nuevo Producto
        </Button>
      </div>

      {/* Estadísticas rápidas */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-amalfi-turquoise">{stats.totalProducts}</div>
            <div className="text-xs text-gray-400">Total Productos</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-green-400">{stats.activeProducts}</div>
            <div className="text-xs text-gray-400">Activos</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-red-400">{stats.outOfStock}</div>
            <div className="text-xs text-gray-400">Agotados</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-amalfi-turquoise">{stats.categories}</div>
            <div className="text-xs text-gray-400">Categorías</div>
          </div>
        </Card>
      </div>

      {/* Filtros */}
      <Card title="Filtros y Búsqueda">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Input
            placeholder="Buscar productos..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="md:col-span-2"
          />
          
          <Select
            options={categoryOptions}
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
          />

          <label className="flex items-center">
            <input
              type="checkbox"
              checked={showInactive}
              onChange={(e) => setShowInactive(e.target.checked)}
              className="rounded bg-gray-700 border-gray-600 text-amalfi-turquoise"
            />
            <span className="ml-2 text-sm text-gray-300">Mostrar inactivos</span>
          </label>
        </div>
      </Card>

      {/* Lista de productos */}
      <Card title="Lista de Productos">
        <Table
          data={filteredProducts}
          columns={columns}
          onRowClick={handleEdit}
          emptyMessage="No hay productos que coincidan con los filtros"
        />
      </Card>

      {/* Distribución por estación */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card title="Por Estación">
          <div className="space-y-3">
            {Object.entries(stats.productsByStation).map(([station, count]) => (
              <div key={station} className="flex items-center justify-between">
                <span className="text-gray-300">{station}</span>
                <div className="flex items-center space-x-2">
                  <div className="w-32 bg-gray-700 rounded-full h-2">
                    <div 
                      className={`h-2 rounded-full ${
                        station === 'COCINA' ? 'bg-blue-500' : 'bg-orange-500'
                      }`}
                      style={{ width: `${(count / stats.activeProducts) * 100}%` }}
                    ></div>
                  </div>
                  <span className="text-sm font-medium text-white w-8">{count}</span>
                </div>
              </div>
            ))}
          </div>
        </Card>

        <Card title="Por Categoría">
          <div className="space-y-2 max-h-48 overflow-y-auto">
            {Object.entries(stats.productsByCategory)
              .sort(([,a], [,b]) => b - a)
              .map(([category, count]) => (
                <div key={category} className="flex items-center justify-between">
                  <span className="text-gray-300 text-sm">{category}</span>
                  <Badge variant="info" size="sm">
                    {count}
                  </Badge>
                </div>
              ))}
          </div>
        </Card>
      </div>

      {/* Modal de producto */}
      <ProductModal
        isOpen={showModal}
        onClose={() => {
          setShowModal(false)
          setEditingProduct(null)
        }}
        product={editingProduct}
        onSubmit={editingProduct ? handleUpdateProduct : handleAddProduct}
      />
    </div>
  )
}

export default Products