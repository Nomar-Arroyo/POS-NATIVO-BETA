import React from 'react'
import { User } from '../../types'
import Modal from '../common/Modal'

interface UserModalProps {
  isOpen: boolean
  onClose: () => void
  users: User[]
}

const UserModal: React.FC<UserModalProps> = ({ 
  isOpen, 
  onClose, 
  users 
}) => {
  const activeUsers = users.filter(u => u.active)

  const handleSelectUser = (user: User) => {
    // Cambiar usuario actual
    //Esta funcionalidad se implementará en el store
    onClose()
  }

  return (
    <Modal 
      isOpen={isOpen} 
      onClose={onClose} 
      title="Cambiar Usuario" 
      size="sm"
    >
      <div className="space-y-2">
        {activeUsers.map((user) => (
          <button
            key={user.id}
            onClick={() => handleSelectUser(user)}
            className="w-full flex items-center space-x-3 p-3 hover:bg-gray-700 rounded-lg transition-colors text-left"
          >
            <div className="w-8 h-8 bg-amalfi-turquoise rounded-full flex items-center justify-center">
              <span className="text-white text-sm font-semibold">
                {user.name.charAt(0)}
              </span>
            </div>
            <div>
              <div className="font-medium text-white">{user.name}</div>
              <div className="text-xs text-gray-400 capitalize">{user.role}</div>
            </div>
          </button>
        ))}
      </div>
    </Modal>
  )
}

export default UserModal