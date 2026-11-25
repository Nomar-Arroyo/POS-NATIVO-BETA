import React, { useEffect, useState } from 'react'
import { useStore } from '../../store/store'
import ExchangeRateModal from '../modals/ExchangeRateModal'
import EstablishmentModal from '../modals/EstablishmentModal'
import UserModal from '../modals/UserModal'
import {
  CalendarClockIcon,
  CurrencyDollarIcon,
  BuildingOfficeIcon
} from '@/components/common/Icon'
import Icon from '../common/Icon'
import { useTheme } from '../../hooks/useTheme'

interface HeaderProps {
  onOpenMenu: () => void
  isMenuOpen: boolean
}

const Header: React.FC<HeaderProps> = ({ onOpenMenu, isMenuOpen }) => {
  const { config, currentUser, users } = useStore()
  const { theme, toggleTheme } = useTheme()
  const [currentTime, setCurrentTime] = useState(new Date())
  const [showExchangeRate, setShowExchangeRate] = useState(false)
  const [showEstablishment, setShowEstablishment] = useState(false)
  const [showUserModal, setShowUserModal] = useState(false)

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  const formatCurrency = (amount: number, currency: 'USD' | 'Bs') =>
    new Intl.NumberFormat('es-VE', {
      style: 'currency',
      currency: currency === 'USD' ? 'USD' : 'VES'
    }).format(amount)

  const formatDate = (date: Date) =>
    date.toLocaleDateString('es-ES', {
      weekday: 'short',
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })

  const formatTime = (date: Date) =>
    date.toLocaleTimeString('es-ES', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })

  return (
    <header className="border-b border-gray-700 bg-gray-800 px-3 py-2 sm:px-4 lg:px-6 lg:py-3">
      <div className="flex min-w-0 items-center justify-between gap-2">
        <div className="flex min-w-0 flex-1 items-center gap-1 sm:gap-3">
          <button
            type="button"
            onClick={onOpenMenu}
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg text-gray-300 transition-colors hover:bg-gray-700 hover:text-white lg:hidden"
            aria-label="Abrir navegación"
            aria-controls="primary-navigation"
            aria-expanded={isMenuOpen}
          >
            <Icon name="menu" size={22} />
          </button>
          <button
            type="button"
            onClick={() => setShowEstablishment(true)}
            className="flex min-w-0 items-center gap-2 rounded-lg px-1 py-1 text-left transition-colors hover:bg-gray-700 sm:px-3 sm:py-2"
          >
            <BuildingOfficeIcon className="h-5 w-5 shrink-0 text-amalfi-turquoise" />
            <div className="min-w-0">
              <h1 className="max-w-[38vw] truncate text-sm font-semibold text-white sm:max-w-[42vw] sm:text-base lg:max-w-80 lg:text-lg">
                {config.establishmentName || 'Café Amalfi'}
              </h1>
              <p className="hidden truncate text-xs text-gray-400 sm:block">
                RIF: {config.taxId}
              </p>
            </div>
          </button>
          <div className="hidden shrink-0 items-center gap-2 text-gray-300 xl:flex">
            <CalendarClockIcon className="h-5 w-5" />
            <div className="text-sm">
              <div>{formatDate(currentTime)}</div>
              <div className="text-xs text-gray-400">{formatTime(currentTime)}</div>
            </div>
          </div>
        </div>

        <button
          type="button"
          onClick={() => setShowExchangeRate(true)}
          className="flex shrink-0 items-center gap-2 rounded-lg bg-gray-700 px-2 py-2 transition-colors hover:bg-gray-600 sm:px-3 lg:px-4"
          aria-label={`Tasa de cambio: 1 USD = ${formatCurrency(config.exchangeRate, 'Bs')}`}
        >
          <CurrencyDollarIcon className="h-5 w-5 shrink-0 text-amalfi-turquoise" />
          <div className="hidden text-left md:block">
            <div className="text-sm font-medium text-white">Tasa de Cambio</div>
            <div className="text-xs text-gray-300">
              1 USD = {formatCurrency(config.exchangeRate, 'Bs')}
            </div>
          </div>
        </button>

        <div className="flex shrink-0 items-center gap-1 sm:gap-2">
          <button
            type="button"
            onClick={toggleTheme}
            className="rounded-lg px-2 py-2 text-xs text-gray-300 transition-colors hover:bg-gray-700 hover:text-white sm:px-3 sm:text-sm"
            aria-label={`Activar tema ${theme === 'dark' ? 'claro' : 'oscuro'}`}
            title={`Activar tema ${theme === 'dark' ? 'claro' : 'oscuro'}`}
          >
            <span className="hidden sm:inline">
              {theme === 'dark' ? 'Modo claro' : 'Modo oscuro'}
            </span>
            <span className="sm:hidden">
              {theme === 'dark' ? 'Claro' : 'Oscuro'}
            </span>
          </button>
          <button
            type="button"
            onClick={() => setShowUserModal(true)}
            className="flex items-center gap-2 rounded-lg px-1 py-1 transition-colors hover:bg-gray-700 sm:px-2"
            aria-label={`Usuario: ${currentUser?.name || 'Usuario'}`}
          >
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-amalfi-turquoise">
              <span className="font-semibold text-white">
                {currentUser?.name.charAt(0) || 'U'}
              </span>
            </div>
            <div className="hidden text-left md:block">
              <div className="text-sm font-medium text-white">
                {currentUser?.name || 'Usuario'}
              </div>
              <div className="text-xs capitalize text-gray-400">
                {currentUser?.role || 'Rol'}
              </div>
            </div>
            <Icon
              name="chevron-right"
              size={16}
              className="hidden rotate-90 text-gray-400 sm:block"
            />
          </button>
        </div>
      </div>

      <ExchangeRateModal
        isOpen={showExchangeRate}
        onClose={() => setShowExchangeRate(false)}
      />
      <EstablishmentModal
        isOpen={showEstablishment}
        onClose={() => setShowEstablishment(false)}
      />
      <UserModal
        isOpen={showUserModal}
        onClose={() => setShowUserModal(false)}
        users={users}
      />
    </header>
  )
}

export default Header
