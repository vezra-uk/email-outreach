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
    is_default: false
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
      is_default: profile.is_default
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
      is_default: false
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