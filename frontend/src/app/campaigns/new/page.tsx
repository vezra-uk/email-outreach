// frontend/src/app/campaigns/new/page.tsx
'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../../../components/ui/card'
import { Button } from '../../../components/ui/button'
import MessagePreview from '../../../components/MessagePreview'
import { withAuth } from '../../../contexts/AuthContext'
import { apiClient } from '../../../lib/api'

interface Lead {
  id: number
  email: string
  first_name: string
  company: string
  status: string
}

interface LeadGroup {
  id: number
  name: string
  description?: string
  color: string
  lead_count: number
}

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

function NewCampaign() {
  const [formData, setFormData] = useState({
    name: '',
    ai_prompt: 'Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead\'s name and company naturally. Create a witty, unique subject line that grabs attention without being spammy.',
    sending_profile_id: null as number | null,
    lead_ids: [] as number[]
  })
  const [leads, setLeads] = useState<Lead[]>([])
  const [groups, setGroups] = useState<LeadGroup[]>([])
  const [profiles, setProfiles] = useState<SendingProfile[]>([])
  const [loading, setLoading] = useState(false)
  const [showPreview, setShowPreview] = useState(false)
  const [selectionMode, setSelectionMode] = useState<'individual' | 'groups'>('individual')

useEffect(() => {
  fetchLeads()
  fetchGroups()
  fetchProfiles()
}, [])

const fetchLeads = async () => {
  try {
    const response = await apiClient.get('/api/leads/')
    const data = await response.json()
    setLeads(data)
  } catch (error) {
    console.error('Failed to fetch leads:', error)
  }
}

const fetchGroups = async () => {
  try {
    const response = await apiClient.get('/api/groups/')
    if (response.ok) {
      const data = await response.json()
      setGroups(Array.isArray(data) ? data : [])
    } else {
      setGroups([])
    }
  } catch (error) {
    console.error('Failed to fetch groups:', error)
    setGroups([])
  }
}

const fetchProfiles = async () => {
  try {
    const response = await apiClient.get('/api/sending-profiles/')
    if (response.ok) {
      const data = await response.json()
      const profilesArray = Array.isArray(data) ? data : []
      setProfiles(profilesArray)
      // Set default profile as selected if available
      const defaultProfile = profilesArray.find((p: SendingProfile) => p.is_default)
      if (defaultProfile) {
        setFormData(prev => ({ ...prev, sending_profile_id: defaultProfile.id }))
      }
    } else {
      setProfiles([])
    }
  } catch (error) {
    console.error('Failed to fetch sending profiles:', error)
    setProfiles([])
  }
}

const loadGroupLeads = async (groupId: number) => {
  try {
    const response = await apiClient.get(`/api/groups/${groupId}/leads/`)
    const data = await response.json()
    const groupLeadIds = data.map((lead: Lead) => lead.id)
    
    setFormData(prev => ({
      ...prev,
      lead_ids: Array.from(new Set([...prev.lead_ids, ...groupLeadIds]))
    }))
  } catch (error) {
    console.error('Failed to fetch group leads:', error)
  }
}

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.name || formData.lead_ids.length === 0) {
      alert('Please fill in campaign name and select at least one lead')
      return
    }

    setLoading(true)
    try {
      const response = await apiClient.post('/api/campaigns', formData)

      if (response.ok) {
        alert('Campaign created successfully!')
        window.location.href = '/'
      } else {
        const error = await response.json()
        alert(`Error: ${error.detail}`)
      }
    } catch (error) {
      alert('Failed to create campaign')
      console.error(error)
    } finally {
      setLoading(false)
    }
  }

  const toggleLead = (leadId: number) => {
    setFormData(prev => ({
      ...prev,
      lead_ids: prev.lead_ids.includes(leadId)
        ? prev.lead_ids.filter(id => id !== leadId)
        : [...prev.lead_ids, leadId]
    }))
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-4xl mx-auto">
        <header className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Create New Campaign</h1>
          <p className="text-gray-600 mt-2">Set up your cold email campaign</p>
        </header>

        <form onSubmit={handleSubmit} className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Campaign Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Campaign Name
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="e.g., Q1 Outreach Campaign"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Sending Profile
                </label>
                <select
                  value={formData.sending_profile_id || ''}
                  onChange={(e) => setFormData(prev => ({ 
                    ...prev, 
                    sending_profile_id: e.target.value ? parseInt(e.target.value) : null 
                  }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">No sending profile</option>
                  {profiles.map((profile) => (
                    <option key={profile.id} value={profile.id}>
                      {profile.name} ({profile.sender_name})
                      {profile.is_default ? ' - Default' : ''}
                    </option>
                  ))}
                </select>
                <p className="text-sm text-gray-500 mt-1">
                  Select a sending profile to replace placeholders like [Your Name] with your actual details
                </p>
              </div>


              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  AI Email Generation Instructions
                </label>
                <textarea
                  value={formData.ai_prompt}
                  onChange={(e) => setFormData(prev => ({ ...prev, ai_prompt: e.target.value }))}
                  rows={4}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p className="text-sm text-gray-500 mt-1">
                  Tell the AI how to write the entire email and subject line. The AI will generate unique, personalized content for each lead.
                </p>
              </div>

              <Button 
                type="button"
                variant="outline"
                onClick={() => setShowPreview(true)}
                disabled={!formData.ai_prompt.trim() || formData.lead_ids.length === 0}
                className="w-full"
              >
                Preview AI-Generated Message
              </Button>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="flex justify-between items-center">
                <CardTitle>Select Recipients ({formData.lead_ids.length} leads selected)</CardTitle>
                <div className="flex gap-2">
                  <Button 
                    type="button"
                    variant={selectionMode === 'individual' ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setSelectionMode('individual')}
                  >
                    Individual Leads
                  </Button>
                  <Button 
                    type="button"
                    variant={selectionMode === 'groups' ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setSelectionMode('groups')}
                  >
                    Groups
                  </Button>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              {selectionMode === 'individual' ? (
                <div className="space-y-2 max-h-64 overflow-y-auto">
                  {leads.map(lead => (
                    <div key={lead.id} className="flex items-center p-3 border rounded-lg">
                      <input
                        type="checkbox"
                        checked={formData.lead_ids.includes(lead.id)}
                        onChange={() => toggleLead(lead.id)}
                        className="mr-3"
                      />
                      <div className="flex-1">
                        <div className="font-medium">{lead.first_name} - {lead.email}</div>
                        <div className="text-sm text-gray-600">{lead.company}</div>
                      </div>
                    </div>
                  ))}
                  {leads.length === 0 && (
                    <p className="text-gray-500 text-center py-4">
                      No leads available. <a href="/leads" className="text-blue-600">Import some leads first</a>
                    </p>
                  )}
                </div>
              ) : (
                <div className="space-y-3">
                  {groups.map(group => (
                    <div key={group.id} className="flex items-center justify-between p-3 border rounded-lg">
                      <div className="flex items-center gap-3">
                        <div 
                          className="w-4 h-4 rounded-full"
                          style={{ backgroundColor: group.color }}
                        />
                        <div>
                          <div className="font-medium">{group.name}</div>
                          <div className="text-sm text-gray-600">
                            {group.lead_count} lead{group.lead_count !== 1 ? 's' : ''}
                            {group.description && ` • ${group.description}`}
                          </div>
                        </div>
                      </div>
                      <Button 
                        type="button"
                        size="sm"
                        onClick={() => loadGroupLeads(group.id)}
                      >
                        Add Group
                      </Button>
                    </div>
                  ))}
                  {groups.length === 0 && (
                    <div className="text-center py-4">
                      <p className="text-gray-500 mb-2">No groups available.</p>
                      <a href="/groups" className="text-blue-600">Create some groups first</a>
                    </div>
                  )}
                  {formData.lead_ids.length > 0 && (
                    <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                      <div className="text-sm font-medium text-blue-900">
                        Selected: {formData.lead_ids.length} lead{formData.lead_ids.length !== 1 ? 's' : ''} from groups
                      </div>
                      <Button 
                        type="button"
                        size="sm"
                        variant="outline"
                        onClick={() => setFormData(prev => ({ ...prev, lead_ids: [] }))}
                        className="mt-2"
                      >
                        Clear Selection
                      </Button>
                    </div>
                  )}
                </div>
              )}
            </CardContent>
          </Card>

          <div className="flex gap-4">
            <Button type="submit" disabled={loading}>
              {loading ? 'Creating...' : 'Create Campaign'}
            </Button>
            <Button 
              type="button" 
              variant="outline"
              onClick={() => window.location.href = '/'}
            >
              Cancel
            </Button>
          </div>
        </form>

        {showPreview && (
          <MessagePreview
            template={""}
            aiPrompt={formData.ai_prompt}
            leads={leads.filter(lead => formData.lead_ids.includes(lead.id))}
            onClose={() => setShowPreview(false)}
          />
        )}
      </div>
    </div>
  )
}

export default withAuth(NewCampaign)
