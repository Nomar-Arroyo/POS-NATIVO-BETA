import React from 'react'
import { useStore } from '../../store/store'
import { 
  XMarkIcon, 
  CheckCircleIcon, 
  ExclamationTriangleIcon, 
  XCircleIcon, 
  InformationCircleIcon,
  BellIcon
} from '@/components/common/Icon'

const NotificationContainer: React.FC = () => {
  const { notifications, removeNotification } = useStore()

  const getIcon = (type: string) => {
    switch (type) {
      case 'success': return CheckCircleIcon
      case 'error': return XCircleIcon
      case 'warning': return ExclamationTriangleIcon
      case 'info': return InformationCircleIcon
      default: return BellIcon
    }
  }

  const getBgColor = (type: string) => {
    switch (type) {
      case 'success': return 'bg-green-600 border-green-400'
      case 'error': return 'bg-red-600 border-red-400'
      case 'warning': return 'bg-yellow-600 border-yellow-400'
      case 'info': return 'bg-amalfi-deep border-amalfi-turquoise'
      default: return 'bg-gray-600 border-gray-400'
    }
  }

  if (notifications.length === 0) return null

  return (
    <div className="fixed top-4 right-4 z-50 space-y-2">
      {notifications.map((notification) => {
        const Icon = getIcon(notification.type)
        return (
          <div
            key={notification.id}
            className={`
              ${getBgColor(notification.type)} 
              text-white px-4 py-3 rounded-lg shadow-xl 
              flex items-center space-x-3 min-w-80 
              animate-slide-in-right border-l-4
            `}
            role={notification.type === 'error' ? 'alert' : 'status'}
            aria-live={notification.type === 'error' ? 'assertive' : 'polite'}
          >
            <Icon className="h-5 w-5 flex-shrink-0" />
            <span className="flex-1 text-sm font-medium">
              {notification.message}
            </span>
            <button
              type="button"
              onClick={() => removeNotification(notification.id)}
              className="text-white hover:text-gray-200 flex-shrink-0"
              aria-label="Cerrar notificación"
            >
              <XMarkIcon className="h-4 w-4" />
            </button>
          </div>
        )
      })}
    </div>
  )
}

export default NotificationContainer