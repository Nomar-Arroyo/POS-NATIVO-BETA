import React from 'react';
import { useStore } from '../../store/store';
import Icon, { type IconName } from '../common/Icon'
import OptimizedImage from '../common/OptimizedImage'
import AmalfiMark from '../../assets/images/cafe-amalfi-app-mark.svg'

const menuItems: Array<{ id: string; name: string; icon: IconName }> = [
  { id: 'dashboard', name: 'Dashboard', icon: 'dashboard' },
  { id: 'salon', name: 'Mesas y Salón', icon: 'tables' },
  { id: 'pos', name: 'POS / Venta', icon: 'pos' },
  { id: 'orders', name: 'Comandas', icon: 'orders' },
  { id: 'inventory', name: 'Inventario', icon: 'inventory' },
  { id: 'cash', name: 'Caja', icon: 'cash' },
  { id: 'reports', name: 'Reportes', icon: 'reports' },
  { id: 'audit', name: 'Auditoría', icon: 'audit' },
  { id: 'settings', name: 'Configuración', icon: 'settings' }
];

interface SidebarProps {
  isOpen: boolean
  onClose: () => void
}

const Sidebar: React.FC<SidebarProps> = ({ isOpen, onClose }) => {
  const { activeModule, setActiveModule } = useStore();

  return (
    <>
      <button
        type="button"
        aria-label="Cerrar navegación"
        aria-hidden={!isOpen}
        tabIndex={isOpen ? 0 : -1}
        onClick={onClose}
        className={`fixed inset-0 z-40 bg-black/50 transition-opacity lg:hidden ${
          isOpen ? 'opacity-100' : 'pointer-events-none opacity-0'
        }`}
      />
      <aside
        id="primary-navigation"
        aria-label="Navegación principal"
        className={`fixed inset-y-0 left-0 z-50 flex w-64 shrink-0 flex-col overflow-y-auto border-r border-gray-700 bg-gray-800 transition-all duration-200 lg:static lg:translate-x-0 ${
          isOpen ? 'visible translate-x-0' : 'invisible -translate-x-full lg:visible'
        }`}
      >
      <div className="flex items-center gap-3 border-b border-gray-700 p-4">
        <OptimizedImage
          src={AmalfiMark}
          alt="Café Amalfi"
          width={40}
          height={40}
          lazy={false}
          className="h-10 w-10 shrink-0"
        />
        <div>
          <h2 className="text-xl font-bold text-amalfi-turquoise">POS NATIVO</h2>
        <p className="text-sm text-gray-400">Sistema de Punto de Ventas</p>
        </div>
      </div>
      
      <nav className="space-y-2 p-4">
        {menuItems.map((item) => {
          const isActive = activeModule === item.id;
          
          return (
            <button
              type="button"
              key={item.id}
              onClick={() => {
                setActiveModule(item.id)
                onClose()
              }}
              aria-current={isActive ? 'page' : undefined}
              className={`
                w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-left transition-colors
                ${isActive 
                  ? 'bg-amalfi-deep text-white hover:brightness-95'
                  : 'text-gray-300 hover:bg-gray-700 hover:text-amalfi-turquoise'
                }
              `}
            >
              <Icon name={item.icon} size={20} />
              <span>{item.name}</span>
            </button>
          );
        })}
      </nav>
      </aside>
    </>
  );
};

export default Sidebar;