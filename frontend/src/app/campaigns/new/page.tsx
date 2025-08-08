// frontend/src/app/campaigns/new/page.tsx
'use client'
import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../../../components/ui/card'
import { Button } from '../../../components/ui/button'

interface Lead {
  id: number
  email: string
  first_name: string
  company: string
  status: string
}

export default function NewCampaign() {
  const [formData, setFormData] = useState({
    name: '',
    subject: '',
    template: '',
    ai_prompt: 'Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead\'s name and company naturally.',
    lead_ids: [] as number[]
  })
  const [leads, setLeads] = useState<Lead[]>([])
  const [loading, setLoading] = useState(false)

  useState(() => {
    fetchLeads()
  }, [])

  const fetchLeads = async () => {
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/leads`)
      const data = await response.json()
      setLeads(data)
    } catch (error) {
      console.error('Failed to fetch leads:', error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.name || !formData.subject || !formData.template || formData.lead_ids.length === 0) {
      alert('Please fill in all fields and select at least one lead')
      return
    }

    setLoading(true)
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/campaigns`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(formData)
      })

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
                  Email Subject
                </label>
                <input
                  type="text"
                  value={formData.subject}
                  onChange={(e) => setFormData(prev => ({ ...prev, subject: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Quick question about {company}"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Email Template
                </label>
                <textarea
                  value={formData.template}
                  onChange={(e) => setFormData(prev => ({ ...prev, template: e.target.value }))}
                  rows={6}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Hi {first_name}, I noticed {company} might benefit from..."
                />
                <p className="text-sm text-gray-500 mt-1">
                  Use {'{first_name}'} and {'{company}'} for personalization
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  AI Personalization Prompt
                </label>
                <textarea
                  value={formData.ai_prompt}
                  onChange={(e) => setFormData(prev => ({ ...prev, ai_prompt: e.target.value }))}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p className="text-sm text-gray-500 mt-1">
                  This tells the AI how to personalize your template for each lead
                </p>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Select Leads ({formData.lead_ids.length} selected)</CardTitle>
            </CardHeader>
            <CardContent>
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
              </div>
              {leads.length === 0 && (
                <p className="text-gray-500 text-center py-4">
                  No leads available. <a href="/leads" className="text-blue-600">Import some leads first</a>
                </p>
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
      </div>
    </div>
  )
}