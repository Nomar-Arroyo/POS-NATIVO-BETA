import React from 'react'
import { useStore } from '../../store/store'
import Table from '../../components/common/Table'
import Card from '../../components/common/Card'
import Button from '../../components/common/Button'
import { Product } from '../../types'

const Inventory: React.FC = () => {
  const { products } = useStore()

  const columns = [
    {
      key: 'name' as keyof Product,
      header: 'Producto'
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
      key: 'stock' as keyof Product,
      header: 'Stock',
      render: (stock?: number) => stock !== undefined ? stock : 'N/A'
    },
    {
      key: 'available' as keyof Product,
      header: 'Disponible',
      render: (available: boolean) => (
        <span className={available ? 'text-green-400' : 'text-red-400'}>
          {available ? 'Sí' : 'No'}
        </span>
      )
    }
  ]

  const handleAdjustStock = (product: Product) => {
    // Lógica para ajustar stock
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Inventario</h2>
        <Button variant="primary">
          Ajustar Stock
        </Button>
      </div>

      <Card title="Estado del Inventario">
        <Table
          data={products}
          columns={columns}
          onRowClick={handleAdjustStock}
          emptyMessage="No hay productos en inventario"
        />
      </Card>
    </div>
  )
}

export default Inventory