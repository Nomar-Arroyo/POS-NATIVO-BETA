import React from 'react'
import { useStore } from '../../store/store'
import ConfirmDialog from '../../components/common/ConfirmDialog'
import Button from '../../components/common/Button'
import Card from '../../components/common/Card'

const DemoReset: React.FC = () => {
  const { resetDemo } = useStore()
  const [showConfirm, setShowConfirm] = React.useState(false)

  return (
    <>
      <Card title="Reiniciar Datos de Demostración">
        <div className="space-y-4">
          <div>
            <h3 className="font-medium text-red-400 mb-2">Zona Peligrosa</h3>
            <p className="text-sm text-gray-400">
              Esta acción restaurará todos los datos de demostración a su estado original.
              Se perderán todas las ventas, comandas, facturas y movimientos registrados.
            </p>
          </div>
          
          <Button 
            variant="danger" 
            onClick={() => setShowConfirm(true)}
          >
            Reiniciar Datos de Demostración
          </Button>
        </div>
      </Card>

      <ConfirmDialog
        isOpen={showConfirm}
        onClose={() => setShowConfirm(false)}
        onConfirm={resetDemo}
        title="Confirmar Reinicio"
        message="¿Está seguro de reiniciar todos los datos de demostración? Esta acción no se puede deshacer."
        confirmText="Sí, Reiniciar"
        cancelText="Cancel"
        variant="danger"
      />
    </>
  )
}

export default DemoReset