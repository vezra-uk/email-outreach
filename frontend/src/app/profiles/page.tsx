'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/card'
import { Button } from '../../components/ui/button'
import { Plus, Edit, Trash2, Star } from 'lucide-react'
import { withAuth } from '../../contexts/AuthContext'
import { apiClient } from '../../utils/api'

interface SendingProfile {
  id: number
  name: string
  sender_name: string
  sender_title?: string
  sender_company?: string
  sender_email: string
  sender_phone?: string
  sender_website?: string
  signature?: string
  is_default: boolean
  // Scheduling fields
  schedule_enabled: boolean
  schedule_days: string
  schedule_time_from: string
  schedule_time_to: string
  schedule_timezone: string
}

function SendingProfiles() {
  const [profiles, setProfiles] = useState<SendingProfile[]>([])
  const [loading, setLoading] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [editingProfile, setEditingProfile] = useState<SendingProfile | null>(null)
  const [formData, setFormData] = useState({
    name: '',
    sender_name: '',
    sender_title: '',
    sender_company: '',
    sender_email: '',
    sender_phone: '',
    sender_website: '',
    signature: '',
    is_default: false,
    // Scheduling fields
    schedule_enabled: true,
    schedule_days: '1,2,3,4,5', // Mon-Fri by default
    schedule_time_from: '09:00',
    schedule_time_to: '17:00',
    schedule_timezone: 'UTC'
  })

  useEffect(() => {
    fetchProfiles()
  }, [])

  const fetchProfiles = async () => {
    try {
      const data = await apiClient.getJson<SendingProfile[]>('/api/sending-profiles/')
      setProfiles(data)
    } catch (error) {
      console.error('Failed to fetch sending profiles:', error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      if (editingProfile) {
        await apiClient.putJson(`/api/sending-profiles/${editingProfile.id}/`, formData)
      } else {
        await apiClient.postJson('/api/sending-profiles/', formData)
      }
      
      await fetchProfiles()
      setShowForm(false)
      setEditingProfile(null)
      resetForm()
    } catch (error) {
      alert('Failed to save sending profile')
      console.error(error)
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this sending profile?')) {
      return
    }

    try {
      await apiClient.delete(`/api/sending-profiles/${id}/`)
      await fetchProfiles()
    } catch (error) {
      alert('Failed to delete sending profile')
      console.error(error)
    }
  }

  const handleEdit = (profile: SendingProfile) => {
    setEditingProfile(profile)
    setFormData({
      name: profile.name,
      sender_name: profile.sender_name,
      sender_title: profile.sender_title || '',
      sender_company: profile.sender_company || '',
      sender_email: profile.sender_email,
      sender_phone: profile.sender_phone || '',
      sender_website: profile.sender_website || '',
      signature: profile.signature || '',
      is_default: profile.is_default,
      // Scheduling fields
      schedule_enabled: profile.schedule_enabled,
      schedule_days: profile.schedule_days,
      schedule_time_from: profile.schedule_time_from,
      schedule_time_to: profile.schedule_time_to,
      schedule_timezone: profile.schedule_timezone
    })
    setShowForm(true)
  }

  const resetForm = () => {
    setFormData({
      name: '',
      sender_name: '',
      sender_title: '',
      sender_company: '',
      sender_email: '',
      sender_phone: '',
      sender_website: '',
      signature: '',
      is_default: false,
      // Scheduling fields
      schedule_enabled: true,
      schedule_days: '1,2,3,4,5', // Mon-Fri by default
      schedule_time_from: '09:00',
      schedule_time_to: '17:00',
      schedule_timezone: 'UTC'
    })
  }

  const handleCancel = () => {
    setShowForm(false)
    setEditingProfile(null)
    resetForm()
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-4xl mx-auto">
        <header className="mb-8">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Sending Profiles</h1>
              <p className="text-gray-600 mt-2">Manage your email sender profiles</p>
            </div>
            <Button onClick={() => setShowForm(true)}>
              <Plus className="w-4 h-4 mr-2" />
              New Profile
            </Button>
          </div>
        </header>

        {showForm && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle>
                {editingProfile ? 'Edit Sending Profile' : 'Create New Sending Profile'}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Profile Name *
                    </label>
                    <input
                      type="text"
                      required
                      value={formData.name}
                      onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="e.g., Personal Profile"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Sender Name *
                    </label>
                    <input
                      type="text"
                      required
                      value={formData.sender_name}
                      onChange={(e) => setFormData(prev => ({ ...prev, sender_name: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="John Doe"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Email Address *
                    </label>
                    <input
                      type="email"
                      required
                      value={formData.sender_email}
                      onChange={(e) => setFormData(prev => ({ ...prev, sender_email: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="john@example.com"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Title
                    </label>
                    <input
                      type="text"
                      value={formData.sender_title}
                      onChange={(e) => setFormData(prev => ({ ...prev, sender_title: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Sales Manager"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Company
                    </label>
                    <input
                      type="text"
                      value={formData.sender_company}
                      onChange={(e) => setFormData(prev => ({ ...prev, sender_company: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Acme Corp"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Phone
                    </label>
                    <input
                      type="tel"
                      value={formData.sender_phone}
                      onChange={(e) => setFormData(prev => ({ ...prev, sender_phone: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="+1 (555) 123-4567"
                    />
                  </div>

                  <div className="md:col-span-2">
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Website
                    </label>
                    <input
                      type="url"
                      value={formData.sender_website}
                      onChange={(e) => setFormData(prev => ({ ...prev, sender_website: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="https://example.com"
                    />
                  </div>

                  <div className="md:col-span-2">
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Email Signature
                    </label>
                    <textarea
                      rows={4}
                      value={formData.signature}
                      onChange={(e) => setFormData(prev => ({ ...prev, signature: e.target.value }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Best regards,&#10;John Doe&#10;Sales Manager at Acme Corp&#10;john@example.com | +1 (555) 123-4567"
                    />
                  </div>

                  {/* Email Schedule Section */}
                  <div className="md:col-span-2 border-t pt-6 mt-6">
                    <h3 className="text-lg font-medium text-gray-900 mb-4">Email Schedule</h3>
                    
                    <div className="flex items-center mb-4">
                      <input
                        type="checkbox"
                        id="schedule_enabled"
                        checked={formData.schedule_enabled}
                        onChange={(e) => setFormData(prev => ({ ...prev, schedule_enabled: e.target.checked }))}
                        className="mr-2"
                      />
                      <label htmlFor="schedule_enabled" className="text-sm font-medium text-gray-700">
                        Enable email scheduling
                      </label>
                    </div>
                    
                    {formData.schedule_enabled && (
                      <div className="space-y-4 ml-6">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">
                            Days of the week
                          </label>
                          <div className="flex flex-wrap gap-2">
                            {[
                              { value: '1', label: 'Mon' },
                              { value: '2', label: 'Tue' },
                              { value: '3', label: 'Wed' },
                              { value: '4', label: 'Thu' },
                              { value: '5', label: 'Fri' },
                              { value: '6', label: 'Sat' },
                              { value: '7', label: 'Sun' }
                            ].map((day) => {
                              const selectedDays = formData.schedule_days.split(',')
                              const isSelected = selectedDays.includes(day.value)
                              
                              return (
                                <button
                                  key={day.value}
                                  type="button"
                                  className={`px-3 py-1 text-sm rounded-md border ${
                                    isSelected 
                                      ? 'bg-blue-500 text-white border-blue-500' 
                                      : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
                                  }`}
                                  onClick={() => {
                                    const currentDays = formData.schedule_days.split(',').filter(d => d)
                                    if (isSelected) {
                                      const newDays = currentDays.filter(d => d !== day.value)
                                      setFormData(prev => ({ ...prev, schedule_days: newDays.join(',') }))
                                    } else {
                                      setFormData(prev => ({ ...prev, schedule_days: [...currentDays, day.value].sort().join(',') }))
                                    }
                                  }}
                                >
                                  {day.label}
                                </button>
                              )
                            })}
                          </div>
                        </div>
                        
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                          <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                              From time
                            </label>
                            <input
                              type="time"
                              value={formData.schedule_time_from}
                              onChange={(e) => setFormData(prev => ({ ...prev, schedule_time_from: e.target.value }))}
                              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                          </div>
                          
                          <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                              To time
                            </label>
                            <input
                              type="time"
                              value={formData.schedule_time_to}
                              onChange={(e) => setFormData(prev => ({ ...prev, schedule_time_to: e.target.value }))}
                              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                          </div>
                          
                          <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                              Timezone
                            </label>
                            <select
                              value={formData.schedule_timezone}
                              onChange={(e) => setFormData(prev => ({ ...prev, schedule_timezone: e.target.value }))}
                              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                            >
                              <option value="UTC">UTC</option>
                              <option value="America/New_York">Eastern Time</option>
                              <option value="America/Chicago">Central Time</option>
                              <option value="America/Denver">Mountain Time</option>
                              <option value="America/Los_Angeles">Pacific Time</option>
                              <option value="Europe/London">London</option>
                              <option value="Europe/Paris">Paris</option>
                              <option value="Europe/Berlin">Berlin</option>
                              <option value="Asia/Tokyo">Tokyo</option>
                              <option value="Asia/Shanghai">Shanghai</option>
                              <option value="Asia/Dubai">Dubai</option>
                              <option value="Australia/Sydney">Sydney</option>
                            </select>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>

                  <div className="md:col-span-2">
                    <div className="flex items-center">
                      <input
                        type="checkbox"
                        id="is_default"
                        checked={formData.is_default}
                        onChange={(e) => setFormData(prev => ({ ...prev, is_default: e.target.checked }))}
                        className="mr-2"
                      />
                      <label htmlFor="is_default" className="text-sm font-medium text-gray-700">
                        Set as default profile
                      </label>
                    </div>
                    <p className="text-sm text-gray-500 mt-1">
                      The default profile will be automatically selected when creating new campaigns
                    </p>
                  </div>
                </div>

                <div className="flex gap-4 pt-4">
                  <Button type="submit" disabled={loading}>
                    {loading ? 'Saving...' : (editingProfile ? 'Update Profile' : 'Create Profile')}
                  </Button>
                  <Button type="button" variant="outline" onClick={handleCancel}>
                    Cancel
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        <div className="grid gap-4">
          {profiles.map((profile) => (
            <Card key={profile.id}>
              <CardContent className="p-6">
                <div className="flex justify-between items-start">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-2">
                      <h3 className="text-lg font-semibold text-gray-900">
                        {profile.name}
                      </h3>
                      {profile.is_default && (
                        <span className="inline-flex items-center text-sm text-yellow-700 bg-yellow-100 rounded-full px-2 py-1">
                          <Star className="w-3 h-3 mr-1" />
                          Default
                        </span>
                      )}
                    </div>
                    
                    <div className="space-y-1 text-sm text-gray-600">
                      <div>
                        <strong>Name:</strong> {profile.sender_name}
                        {profile.sender_title && <span> - {profile.sender_title}</span>}
                      </div>
                      <div><strong>Email:</strong> {profile.sender_email}</div>
                      {profile.sender_company && (
                        <div><strong>Company:</strong> {profile.sender_company}</div>
                      )}
                      {profile.sender_phone && (
                        <div><strong>Phone:</strong> {profile.sender_phone}</div>
                      )}
                      {profile.sender_website && (
                        <div><strong>Website:</strong> {profile.sender_website}</div>
                      )}
                      {profile.signature && (
                        <div className="mt-3">
                          <strong>Signature:</strong>
                          <pre className="text-xs text-gray-500 mt-1 whitespace-pre-wrap">
                            {profile.signature}
                          </pre>
                        </div>
                      )}
                      
                      {/* Schedule Information */}
                      <div className="mt-3 pt-3 border-t border-gray-200">
                        <strong>Email Schedule:</strong>
                        {profile.schedule_enabled ? (
                          <div className="text-xs text-gray-500 mt-1">
                            <div>
                              Days: {profile.schedule_days.split(',').map(d => {
                                const dayNames = { '1': 'Mon', '2': 'Tue', '3': 'Wed', '4': 'Thu', '5': 'Fri', '6': 'Sat', '7': 'Sun' }
                                return dayNames[d as keyof typeof dayNames] || d
                              }).join(', ')}
                            </div>
                            <div>Time: {profile.schedule_time_from} - {profile.schedule_time_to}</div>
                            <div>Timezone: {profile.schedule_timezone}</div>
                          </div>
                        ) : (
                          <span className="text-xs text-gray-500 ml-1">Disabled</span>
                        )}
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex gap-2 ml-4">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleEdit(profile)}
                    >
                      <Edit className="w-4 h-4" />
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleDelete(profile.id)}
                      className="text-red-600 hover:text-red-700 hover:bg-red-50"
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
          
          {profiles.length === 0 && !showForm && (
            <Card>
              <CardContent className="text-center py-12">
                <div className="text-gray-500 mb-4">
                  No sending profiles found
                </div>
                <Button onClick={() => setShowForm(true)}>
                  <Plus className="w-4 h-4 mr-2" />
                  Create Your First Profile
                </Button>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  )
}

export default withAuth(SendingProfiles)