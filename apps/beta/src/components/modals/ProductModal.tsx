import React from 'react'
import ProductForm from '../forms/ProductForm'
import Modal from '../common/Modal'
import { Product } from '../../types'

interface ProductModalProps {
  isOpen: boolean
  onClose: () => void
  product?: Product | null
  onSubmit: (product: Omit<Product, 'id'>) => void
}

const ProductModal: React.FC<ProductModalProps> = ({
  isOpen,
  onClose,
  product,
  onSubmit
}) => {
  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose} 
      title={product ? 'Editar Producto' : 'Nuevo Producto'}
      size="lg"
    >
      <ProductForm
        product={product}
        onSubmit={onSubmit}
        onClose={onClose}
      />
    </Modal>
  )
}

export default ProductModal