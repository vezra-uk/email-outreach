// frontend/src/app/page.tsx
'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card'
import { Button } from '../components/ui/button'

interface DashboardStats {
  total_leads: number
  emails_sent_today: number
  emails_opened_today: number
  active_campaigns: number
  daily_limit: number
}

interface Campaign {
  id: number
  name: string
  subject: string
  status: string
  created_at: string
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>({
    total_leads: 0,
    emails_sent_today: 0,
    emails_opened_today: 0,
    active_campaigns: 0,
    daily_limit: 30
  })
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    fetchDashboardData()
  }, [])

  const fetchDashboardData = async () => {
    try {
      const [statsRes, campaignsRes] = await Promise.all([
        fetch(`${process.env.NEXT_PUBLIC_API_URL}/dashboard`),
        fetch(`${process.env.NEXT_PUBLIC_API_URL}/campaigns`)
      ])
      
      const statsData = await statsRes.json()
      const campaignsData = await campaignsRes.json()
      
      setStats(statsData)
      setCampaigns(campaignsData)
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error)
    }
  }

  const triggerEmailSend = async () => {
    setLoading(true)
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/send-emails`, {
        method: 'POST'
      })
      const result = await response.json()
      
      if (response.ok) {
        alert(`Email sending started! ${result.message}`)
        fetchDashboardData() // Refresh data
      } else {
        alert(`Error: ${result.detail}`)
      }
    } catch (error) {
      alert('Failed to trigger email send')
      console.error(error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        <header className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Email Campaign Dashboard</h1>
          <p className="text-gray-600 mt-2">Manage your cold email campaigns</p>
        </header>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-gray-600">Total Leads</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.total_leads}</div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-gray-600">Emails Sent Today</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {stats.emails_sent_today}/{stats.daily_limit}
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                <div 
                  className="bg-blue-600 h-2 rounded-full" 
                  style={{width: `${(stats.emails_sent_today / stats.daily_limit) * 100}%`}}
                ></div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-gray-600">Opens Today</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.emails_opened_today}</div>
              <div className="text-sm text-gray-500">
                {stats.emails_sent_today > 0 ? 
                  `${Math.round((stats.emails_opened_today / stats.emails_sent_today) * 100)}% rate` : 
                  '0% rate'
                }
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-gray-600">Active Campaigns</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.active_campaigns}</div>
            </CardContent>
          </Card>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-wrap gap-4 mb-8">
          <Button 
            onClick={triggerEmailSend}
            disabled={loading || stats.emails_sent_today >= stats.daily_limit}
            className="bg-blue-600 hover:bg-blue-700"
          >
            {loading ? 'Sending...' : 'Send Today\'s Batch'}
          </Button>
          <Button 
            variant="outline"
            onClick={() => window.location.href = '/campaigns/new'}
          >
            New Campaign
          </Button>
          <Button 
            variant="outline"
            onClick={() => window.location.href = '/leads'}
          >
            Manage Leads
          </Button>
        </div>

        {/* Campaigns List */}
        <Card>
          <CardHeader>
            <CardTitle>Recent Campaigns</CardTitle>
          </CardHeader>
          <CardContent>
            {campaigns.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No campaigns yet. Create your first one!</p>
              </div>
            ) : (
              <div className="space-y-3">
                {campaigns.map(campaign => (
                  <div key={campaign.id} className="flex items-center justify-between p-4 border rounded-lg">
                    <div>
                      <h3 className="font-medium">{campaign.name}</h3>
                      <p className="text-sm text-gray-600">{campaign.subject}</p>
                    </div>
                    <div className="text-right">
                      <span className={`inline-flex px-2 py-1 text-xs rounded-full ${
                        campaign.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'
                      }`}>
                        {campaign.status}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}