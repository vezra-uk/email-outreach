// frontend/src/app/campaigns/page.tsx
'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/card'
import { Button } from '../../components/ui/button'
import { Plus, Eye, Mail, Users, Activity, Clock, BarChart3, MousePointer } from 'lucide-react'
import ClickAnalytics from '../../components/ClickAnalytics'
import { withAuth } from '../../contexts/AuthContext'
import { apiClient } from '../../utils/api'

interface Campaign {
  id: number
  name: string
  subject: string
  status: string
  total_leads: number
  emails_sent: number
  emails_opened: number
  emails_clicked: number
  completion_rate: number
  open_rate: number
  click_rate: number
  last_sent_at: string | null
  created_at: string
}

interface CampaignDetail {
  id: number
  name: string
  subject: string
  template: string
  ai_prompt: string
  status: string
  total_leads: number
  emails_sent: number
  emails_opened: number
  emails_clicked: number
  completion_rate: number
  open_rate: number
  click_rate: number
  last_sent_at: string | null
  created_at: string
  leads: Array<{
    id: number
    email: string
    first_name: string
    last_name: string
    company: string
    title: string
    status: string
    sent_at: string | null
    opens: number
    clicks: number
  }>
}

function CampaignsPage() {
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [archivedCampaigns, setArchivedCampaigns] = useState<Campaign[]>([])
  const [selectedCampaign, setSelectedCampaign] = useState<CampaignDetail | null>(null)
  const [showDetail, setShowDetail] = useState(false)
  const [showArchived, setShowArchived] = useState(false)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    fetchCampaigns()
  }, [])

  const fetchCampaigns = async () => {
    try {
      const data = await apiClient.getJson<Campaign[]>('/api/campaigns/progress')
      setCampaigns(data)
    } catch (error) {
      console.error('Failed to fetch campaigns:', error)
    }
  }

  const fetchArchivedCampaigns = async () => {
    try {
      const data = await apiClient.getJson<Campaign[]>('/api/campaigns/archived')
      setArchivedCampaigns(data)
    } catch (error) {
      console.error('Failed to fetch archived campaigns:', error)
    }
  }

  const fetchCampaignDetail = async (campaignId: number) => {
    setLoading(true)
    try {
      const data = await apiClient.getJson<CampaignDetail>(`/api/campaigns/${campaignId}/detail`)
      setSelectedCampaign(data)
      setShowDetail(true)
    } catch (error) {
      console.error('Failed to fetch campaign detail:', error)
    } finally {
      setLoading(false)
    }
  }

  const completeCampaign = async (campaignId: number) => {
    try {
      const response = await apiClient.put(`/api/campaigns/${campaignId}/complete`)
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      alert('Campaign marked as complete!')
      fetchCampaigns() // Refresh the active list
      if (showArchived) {
        fetchArchivedCampaigns() // Refresh archived list if viewing
      }
    } catch (error) {
      console.error('Failed to complete campaign:', error)
      alert(`Failed to complete campaign: ${error.message}`)
    }
  }

  const archiveCampaign = async (campaignId: number) => {
    if (confirm('Are you sure you want to archive this campaign? It will be removed from the main dashboard.')) {
      try {
        const response = await apiClient.put(`/api/campaigns/${campaignId}/archive`)
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        alert('Campaign archived!')
        fetchCampaigns() // Refresh the active list
        if (showArchived) {
          fetchArchivedCampaigns() // Refresh archived list if viewing
        }
      } catch (error) {
        console.error('Failed to archive campaign:', error)
        alert(`Failed to archive campaign: ${error.message}`)
      }
    }
  }

  const reactivateCampaign = async (campaignId: number) => {
    try {
      const response = await apiClient.put(`/api/campaigns/${campaignId}/reactivate`)
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      alert('Campaign reactivated!')
      fetchCampaigns() // Refresh the active list
      fetchArchivedCampaigns() // Refresh archived list
    } catch (error) {
      console.error('Failed to reactivate campaign:', error)
      alert(`Failed to reactivate campaign: ${error.message}`)
    }
  }

  const ProgressBar = ({ current, total, className = '' }: { current: number; total: number; className?: string }) => (
    <div className={`w-full bg-gray-200 rounded-full h-2 overflow-hidden ${className}`}>
      <div
        className="bg-blue-600 h-2 rounded-full transition-all duration-500"
        style={{ width: total > 0 ? `${(current / total) * 100}%` : '0%' }}
      />
    </div>
  )

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'bg-green-100 text-green-800'
      case 'paused': return 'bg-yellow-100 text-yellow-800'
      case 'completed': return 'bg-blue-100 text-blue-800'
      case 'archived': return 'bg-gray-100 text-gray-600'
      case 'draft': return 'bg-gray-100 text-gray-600'
      default: return 'bg-gray-100 text-gray-600'
    }
  }

  const getLeadStatusColor = (status: string) => {
    switch (status) {
      case 'sent': return 'bg-green-100 text-green-800'
      case 'pending': return 'bg-yellow-100 text-yellow-800'
      case 'failed': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-600'
    }
  }

  if (showDetail && selectedCampaign) {
    return (
      <div className="min-h-screen bg-gray-50 p-6">
        <div className="max-w-7xl mx-auto">
          <div className="mb-6 flex items-center justify-between">
            <div>
              <Button 
                variant="outline" 
                onClick={() => setShowDetail(false)}
                className="mb-4"
              >
                ← Back to Campaigns
              </Button>
              <h1 className="text-3xl font-bold text-gray-900">{selectedCampaign.name}</h1>
              <p className="text-gray-600">{selectedCampaign.subject}</p>
            </div>
            <span className={`px-3 py-1 text-sm font-medium rounded-full ${getStatusColor(selectedCampaign.status)}`}>
              {selectedCampaign.status}
            </span>
          </div>

          {/* Campaign Stats */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-gray-500 flex items-center">
                  <Users className="w-4 h-4 mr-2" />
                  Total Leads
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{selectedCampaign.total_leads}</div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-gray-500 flex items-center">
                  <Mail className="w-4 h-4 mr-2" />
                  Emails Sent
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {selectedCampaign.emails_sent}/{selectedCampaign.total_leads}
                </div>
                <ProgressBar 
                  current={selectedCampaign.emails_sent} 
                  total={selectedCampaign.total_leads}
                  className="mt-2"
                />
                <div className="text-sm text-gray-500 mt-1">
                  {selectedCampaign.completion_rate}% complete
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-gray-500 flex items-center">
                  <Eye className="w-4 h-4 mr-2" />
                  Open Rate
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{selectedCampaign.open_rate}%</div>
                <div className="text-sm text-gray-500">
                  {selectedCampaign.emails_opened} opens
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-gray-500 flex items-center">
                  <Activity className="w-4 h-4 mr-2" />
                  Click Rate
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{selectedCampaign.click_rate}%</div>
                <div className="text-sm text-gray-500">
                  {selectedCampaign.emails_clicked} clicks
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Campaign Template */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
            <Card>
              <CardHeader>
                <CardTitle>Email Template</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="bg-gray-50 p-4 rounded-lg">
                  <div className="font-medium mb-2">Subject: {selectedCampaign.subject}</div>
                  <div className="text-sm text-gray-600 whitespace-pre-wrap">
                    {selectedCampaign.template}
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>AI Prompt</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="bg-blue-50 p-4 rounded-lg">
                  <div className="text-sm text-gray-700 whitespace-pre-wrap">
                    {selectedCampaign.ai_prompt}
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Leads Table */}
          <Card>
            <CardHeader>
              <CardTitle>Campaign Leads ({selectedCampaign.leads.length})</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-3">Contact</th>
                      <th className="text-left py-3">Company</th>
                      <th className="text-left py-3">Status</th>
                      <th className="text-left py-3">Sent At</th>
                      <th className="text-left py-3">Opens</th>
                      <th className="text-left py-3">Clicks</th>
                    </tr>
                  </thead>
                  <tbody>
                    {selectedCampaign.leads.map(lead => (
                      <tr key={lead.id} className="border-b hover:bg-gray-50">
                        <td className="py-3">
                          <div>
                            <div className="font-medium">{lead.first_name} {lead.last_name}</div>
                            <div className="text-gray-500 text-xs">{lead.email}</div>
                          </div>
                        </td>
                        <td className="py-3">
                          <div>
                            <div className="font-medium">{lead.company || '-'}</div>
                            <div className="text-gray-500 text-xs">{lead.title || '-'}</div>
                          </div>
                        </td>
                        <td className="py-3">
                          <span className={`px-2 py-1 text-xs rounded-full ${getLeadStatusColor(lead.status)}`}>
                            {lead.status}
                          </span>
                        </td>
                        <td className="py-3 text-gray-600">
                          {lead.sent_at ? new Date(lead.sent_at).toLocaleDateString() : '-'}
                        </td>
                        <td className="py-3">
                          <span className={`px-2 py-1 text-xs rounded ${lead.opens > 0 ? 'bg-green-100 text-green-800' : 'bg-gray-100'}`}>
                            {lead.opens}
                          </span>
                        </td>
                        <td className="py-3">
                          <span className={`px-2 py-1 text-xs rounded ${lead.clicks > 0 ? 'bg-blue-100 text-blue-800' : 'bg-gray-100'}`}>
                            {lead.clicks}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>

          {/* Click Analytics */}
          <div className="mt-8">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <MousePointer className="h-5 w-5" />
                  Click Analytics
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ClickAnalytics campaignId={selectedCampaign.id} />
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        <header className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Campaign Management</h1>
            <p className="text-gray-600 mt-2">Track and manage your email campaigns</p>
          </div>
          <Button onClick={() => window.location.href = '/campaigns/new'}>
            <Plus className="mr-2 h-4 w-4" />
            New Campaign
          </Button>
        </header>

        {/* Tab Navigation */}
        <div className="mb-6">
          <div className="flex space-x-1 bg-gray-100 p-1 rounded-lg w-fit">
            <button
              onClick={() => {
                setShowArchived(false)
                fetchCampaigns()
              }}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                !showArchived 
                  ? 'bg-white text-gray-900 shadow-sm' 
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              Active Campaigns ({campaigns.length})
            </button>
            <button
              onClick={() => {
                setShowArchived(true)
                fetchArchivedCampaigns()
              }}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                showArchived 
                  ? 'bg-white text-gray-900 shadow-sm' 
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              Archived ({archivedCampaigns.length})
            </button>
          </div>
        </div>

        {(showArchived ? archivedCampaigns : campaigns).length === 0 ? (
          <Card>
            <CardContent className="text-center py-12">
              <BarChart3 className="mx-auto w-16 h-16 text-gray-400 mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No campaigns yet</h3>
              <p className="text-gray-600 mb-6">Create your first email campaign to get started</p>
              <Button onClick={() => window.location.href = '/campaigns/new'}>
                <Plus className="mr-2 h-4 w-4" />
                Create Campaign
              </Button>
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
            {(showArchived ? archivedCampaigns : campaigns).map(campaign => (
              <Card key={campaign.id} className="hover:shadow-lg transition-shadow">
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <CardTitle className="text-lg truncate">{campaign.name}</CardTitle>
                      <p className="text-sm text-gray-600 mt-1 truncate">{campaign.subject}</p>
                    </div>
                    <span className={`px-2 py-1 text-xs font-medium rounded-full ${getStatusColor(campaign.status)}`}>
                      {campaign.status}
                    </span>
                  </div>
                </CardHeader>

                <CardContent className="space-y-4">
                  {/* Progress */}
                  <div>
                    <div className="flex justify-between items-center mb-2">
                      <span className="text-sm font-medium text-gray-700">Progress</span>
                      <span className="text-sm text-gray-600">
                        {campaign.emails_sent}/{campaign.total_leads}
                      </span>
                    </div>
                    <ProgressBar 
                      current={campaign.emails_sent} 
                      total={campaign.total_leads}
                    />
                    <div className="text-xs text-gray-500 mt-1">
                      {campaign.completion_rate}% complete
                    </div>
                  </div>

                  {/* Stats */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="text-center bg-gray-50 p-3 rounded-lg">
                      <div className="text-lg font-bold text-blue-600">{campaign.open_rate}%</div>
                      <div className="text-xs text-gray-500">Open Rate</div>
                    </div>
                    <div className="text-center bg-gray-50 p-3 rounded-lg">
                      <div className="text-lg font-bold text-green-600">{campaign.click_rate}%</div>
                      <div className="text-xs text-gray-500">Click Rate</div>
                    </div>
                  </div>

                  {/* Last Activity */}
                  <div className="flex items-center text-xs text-gray-500">
                    <Clock className="w-3 h-3 mr-1" />
                    {campaign.last_sent_at 
                      ? `Last sent: ${new Date(campaign.last_sent_at).toLocaleDateString()}`
                      : 'No emails sent yet'
                    }
                  </div>

                  {/* Actions */}
                  <div className="flex gap-2 pt-2">
                    <Button 
                      variant="outline" 
                      size="sm" 
                      onClick={() => fetchCampaignDetail(campaign.id)}
                      disabled={loading}
                      className="flex-1"
                    >
                      <Eye className="w-3 h-3 mr-1" />
                      View Details
                    </Button>
                    {!showArchived && (
                      <>
                        <Button 
                          variant="outline" 
                          size="sm" 
                          onClick={() => completeCampaign(campaign.id)}
                          disabled={loading}
                          className="text-green-600 hover:text-green-700"
                          title="Mark as Complete"
                        >
                          ✓
                        </Button>
                        <Button 
                          variant="outline" 
                          size="sm" 
                          onClick={() => archiveCampaign(campaign.id)}
                          disabled={loading}
                          className="text-red-600 hover:text-red-700"
                          title="Archive Campaign"
                        >
                          📦
                        </Button>
                      </>
                    )}
                    {showArchived && (
                      <Button 
                        variant="outline" 
                        size="sm" 
                        onClick={() => reactivateCampaign(campaign.id)}
                        disabled={loading}
                        className="text-blue-600 hover:text-blue-700"
                        title="Reactivate Campaign"
                      >
                        ↩️
                      </Button>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

export default withAuth(CampaignsPage)