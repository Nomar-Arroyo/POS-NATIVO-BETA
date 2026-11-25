import React from 'react'
import ConfigForm from '../../components/forms/ConfigForm'
import Card from '../../components/common/Card'

const CatalogConfig: React.FC = () => {
  return (
    <Card title="Configuración del Catálogo">
      <ConfigForm />
    </Card>
  )
}

export default CatalogConfig