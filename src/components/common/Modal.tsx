import React, { useEffect, useId, useRef } from 'react'
import { useAccessibility, useKeyboardNavigation } from '../../hooks/useAccessibility'
import { XMarkIcon } from '@/components/common/Icon'

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl';
}

const Modal: React.FC<ModalProps> = ({ isOpen, onClose, title, children, size = 'md' }) => {
  const modalRef = useRef<HTMLDivElement>(null)
  const titleId = useId()
  const { trapFocus } = useAccessibility()

  useKeyboardNavigation(isOpen ? onClose : undefined)
  useEffect(() => {
    if (!isOpen) return

    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const releaseFocus = modalRef.current
      ? trapFocus(modalRef.current)
      : undefined
    return () => {
      document.body.style.overflow = previousOverflow
      releaseFocus?.()
    }
  }, [isOpen, trapFocus])

  if (!isOpen) return null;

  const sizeClasses = {
    sm: 'max-w-sm',
    md: 'max-w-md',
    lg: 'max-w-lg',
    xl: 'max-w-xl'
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/50 p-4">
      <div
        ref={modalRef}
        className={`bg-gray-800 rounded-lg shadow-xl w-full ${sizeClasses[size]} max-h-[90vh] overflow-y-auto animate-fade-in`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? titleId : undefined}
        aria-label={title ? undefined : 'Diálogo'}
        tabIndex={-1}
      >
        <div className="flex items-center justify-between p-4 border-b border-gray-700">
          {title && <h3 id={titleId} className="text-lg font-semibold text-white">{title}</h3>}
          <button
            type="button"
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
            aria-label="Cerrar diálogo"
          >
            <XMarkIcon className="h-6 w-6" />
          </button>
        </div>
        <div className="p-4">
          {children}
        </div>
      </div>
    </div>
  )
}

export default Modal;