// frontend/src/components/Header.tsx
'use client'
import { usePathname } from 'next/navigation'
import { Mail, BarChart3, Users, Plus, Zap, Folder, UserCircle, LogOut, ChevronDown, Eye } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'
import { useState, useEffect, useRef } from 'react'

export default function Header() {
  const pathname = usePathname()
  const { user, logout } = useAuth()
  const [isDropdownOpen, setIsDropdownOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])
  
  // Primary navigation items (always visible)
  const primaryNavigation = [
    { name: 'Dashboard', href: '/', icon: BarChart3 },
    { name: 'Campaigns', href: '/campaigns', icon: Mail },
  ]

  // Secondary navigation items (in dropdown)
  const secondaryNavigation = [
    { name: 'Leads', href: '/leads', icon: Users },
    { name: 'Email Opens', href: '/opens', icon: Eye },
    { name: 'Groups', href: '/groups', icon: Folder },
    { name: 'Profiles', href: '/profiles', icon: UserCircle },
  ]

  const allNavigation = [...primaryNavigation, ...secondaryNavigation]

  const isActive = (href: string) => {
    if (href === '/') return pathname === '/'
    return pathname.startsWith(href)
  }

  return (
    <header className="bg-white shadow-sm border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          {/* Logo/Brand */}
          <div className="flex items-center">
            <div className="flex-shrink-0 flex items-center">
              <Mail className="h-8 w-8 text-blue-600" />
              <span className="ml-2 text-xl font-bold text-gray-900">
                Email Automation
              </span>
            </div>
          </div>

          {/* Navigation */}
          <nav className="hidden lg:flex items-center space-x-4">
            {/* Primary navigation items */}
            {primaryNavigation.map((item) => {
              const Icon = item.icon
              return (
                <a
                  key={item.name}
                  href={item.href}
                  className={`inline-flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                    isActive(item.href)
                      ? 'text-blue-600 bg-blue-50'
                      : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                  }`}
                >
                  <Icon className="w-4 h-4 mr-1.5" />
                  {item.name}
                </a>
              )
            })}
            
            {/* Dropdown menu */}
            <div className="relative" ref={dropdownRef}>
              <button
                onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                className={`inline-flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  secondaryNavigation.some(item => isActive(item.href))
                    ? 'text-blue-600 bg-blue-50'
                    : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                }`}
              >
                More
                <ChevronDown className={`w-4 h-4 ml-1 transition-transform ${isDropdownOpen ? 'rotate-180' : ''}`} />
              </button>
              
              {isDropdownOpen && (
                <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg ring-1 ring-black ring-opacity-5 z-50">
                  <div className="py-1">
                    {secondaryNavigation.map((item) => {
                      const Icon = item.icon
                      return (
                        <a
                          key={item.name}
                          href={item.href}
                          className={`flex items-center px-4 py-2 text-sm transition-colors ${
                            isActive(item.href)
                              ? 'text-blue-600 bg-blue-50'
                              : 'text-gray-700 hover:text-gray-900 hover:bg-gray-50'
                          }`}
                          onClick={() => setIsDropdownOpen(false)}
                        >
                          <Icon className="w-4 h-4 mr-3" />
                          {item.name}
                        </a>
                      )
                    })}
                  </div>
                </div>
              )}
            </div>
          </nav>

          {/* Quick Actions */}
          <div className="flex items-center space-x-2">
            {user && (
              <>
                <a
                  href="/campaigns/new"
                  className="hidden sm:inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 transition-colors"
                >
                  <Plus className="w-4 h-4 mr-1.5" />
                  <span className="hidden md:inline">New Campaign</span>
                  <span className="md:hidden">New</span>
                </a>
                <div className="flex items-center space-x-2">
                  <span className="hidden sm:block text-sm text-gray-700 max-w-32 truncate">
                    {user.full_name || user.username}
                  </span>
                  <button
                    onClick={logout}
                    className="inline-flex items-center px-2 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 transition-colors"
                  >
                    <LogOut className="w-4 h-4" />
                    <span className="hidden sm:inline ml-1.5">Logout</span>
                  </button>
                </div>
              </>
            )}
          </div>

          {/* Mobile menu button */}
          <div className="lg:hidden">
            <button
              type="button"
              className="inline-flex items-center justify-center p-2 rounded-md text-gray-600 hover:text-gray-900 hover:bg-gray-50"
              onClick={() => {
                const mobileMenu = document.getElementById('mobile-menu')
                mobileMenu?.classList.toggle('hidden')
              }}
            >
              <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
          </div>
        </div>

        {/* Mobile Navigation */}
        <div className="lg:hidden hidden" id="mobile-menu">
          <div className="px-2 pt-2 pb-3 space-y-1 border-t border-gray-200">
            {allNavigation.map((item) => {
              const Icon = item.icon
              return (
                <a
                  key={item.name}
                  href={item.href}
                  className={`flex items-center px-3 py-2 rounded-md text-base font-medium ${
                    isActive(item.href)
                      ? 'text-blue-600 bg-blue-50'
                      : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                  }`}
                >
                  <Icon className="w-5 h-5 mr-3" />
                  {item.name}
                </a>
              )
            })}
            <a
              href="/campaigns/new"
              className="flex items-center px-3 py-2 rounded-md text-base font-medium text-blue-600 hover:bg-blue-50"
            >
              <Plus className="w-5 h-5 mr-3" />
              New Campaign
            </a>
          </div>
        </div>
      </div>
    </header>
  )
}