// frontend/src/components/ui/button.tsx - Enhanced with size variants
import React from 'react'

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: React.ReactNode
  onClick?: () => void
  variant?: 'default' | 'outline'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  className?: string
  type?: 'button' | 'submit' | 'reset'
}

export const Button = ({ 
  children, 
  onClick, 
  variant = 'default',
  size = 'md',
  disabled = false,
  className = '',
  type = 'button',
  ...props
}: ButtonProps) => {
  const baseClasses = 'rounded-md font-medium transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center'
  
  const variantClasses = {
    default: 'bg-blue-600 text-white hover:bg-blue-700 disabled:hover:bg-blue-600',
    outline: 'border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:hover:bg-white'
  }

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2',
    lg: 'px-6 py-3 text-lg'
  }
  
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`${baseClasses} ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      {...props}
    >
      {children}
    </button>
  )
}