// frontend/src/components/ui/button.tsx
import React from 'react'

interface ButtonProps {
  children: React.ReactNode
  onClick?: () => void
  variant?: 'default' | 'outline'
  disabled?: boolean
  className?: string
}

export const Button = ({ 
  children, 
  onClick, 
  variant = 'default', 
  disabled = false,
  className = ''
}: ButtonProps) => {
  const baseClasses = 'px-4 py-2 rounded-md font-medium transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed'
  
  const variantClasses = {
    default: 'bg-blue-600 text-white hover:bg-blue-700 disabled:hover:bg-blue-600',
    outline: 'border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:hover:bg-white'
  }
  
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`${baseClasses} ${variantClasses[variant]} ${className}`}
    >
      {children}
    </button>
  )
}
