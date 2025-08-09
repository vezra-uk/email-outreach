'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card'
import { Button } from '../components/ui/button'
import { Plus, Mail, Users, Activity } from 'lucide-react'

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
        fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/dashboard`),
        fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/campaigns`)
      ])
      setStats(await statsRes.json())
      setCampaigns(await campaignsRes.json())
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error)
    }
  }

  const triggerEmailSend = async () => {
    setLoading(true)
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/send-emails`, {
        method: 'POST'
      })
      const result = await response.json()
      if (response.ok) {
        alert(`Email sending started! ${result.message}`)
        fetchDashboardData()
      } else {
        alert(`Error: ${result.detail}`)
      }
    } catch {
      alert('Failed to trigger email send')
    } finally {
      setLoading(false)
    }
  }

  const StatCard = ({ title, value, children }: { title: string; value: React.ReactNode; children?: React.ReactNode }) => (
    <Card className="shadow-md hover:shadow-lg transition border border-gray-100">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-gray-500">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-3xl font-bold">{value}</div>
        {children}
      </CardContent>
    </Card>
  )

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 p-8">
      <div className="max-w-7xl mx-auto space-y-10">
        {/* Header */}
        <header className="flex flex-col sm:flex-row sm:items-center sm:justify-between bg-white p-6 rounded-2xl shadow-sm">
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-gray-900">
              Email Campaign Dashboard
            </h1>
            <p className="text-gray-600 mt-1">Manage your cold email campaigns with ease</p>
          </div>
          <Button
            onClick={triggerEmailSend}
            disabled={loading || stats.emails_sent_today >= stats.daily_limit}
            className="mt-4 sm:mt-0 bg-blue-600 hover:bg-blue-700 text-white shadow-sm"
          >
            <Mail className="mr-2 h-4 w-4" />
            {loading ? 'Sending...' : "Send Today's Batch"}
          </Button>
        </header>

        {/* Stats */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          <StatCard title="Total Leads" value={stats.total_leads}>
            <Users className="text-gray-400 mt-2" />
          </StatCard>

          <StatCard title="Emails Sent Today" value={`${stats.emails_sent_today}/${stats.daily_limit}`}>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-3 overflow-hidden">
              <div
                className="bg-blue-600 h-2 rounded-full transition-all duration-500"
                style={{ width: `${(stats.emails_sent_today / stats.daily_limit) * 100}%` }}
              />
            </div>
          </StatCard>

          <StatCard title="Opens Today" value={stats.emails_opened_today}>
            <div className="text-sm text-gray-500 mt-1">
              {stats.emails_sent_today > 0
                ? `${Math.round((stats.emails_opened_today / stats.emails_sent_today) * 100)}% rate`
                : '0% rate'}
            </div>
          </StatCard>

          <StatCard title="Active Campaigns" value={stats.active_campaigns}>
            <Activity className="text-gray-400 mt-2" />
          </StatCard>
        </div>

{/* Actions */}
<div className="flex flex-wrap gap-4">
  <Button
    onClick={triggerEmailSend}
    disabled={loading || stats.emails_sent_today >= stats.daily_limit}
    className="bg-blue-600 hover:bg-blue-700 text-white shadow-sm"
  >
    <Mail className="mr-2 h-4 w-4" />
    {loading ? 'Sending...' : "Send Today's Batch"}
  </Button>

  <Button
    variant="outline"
    onClick={() => (window.location.href = '/campaigns/new')}
  >
    <Plus className="mr-2 h-4 w-4" />
    New Campaign
  </Button>

  <Button
    variant="outline"
    onClick={() => (window.location.href = '/leads')}
  >
    <Users className="mr-2 h-4 w-4" />
    Manage Leads
  </Button>
</div>

        {/* Campaigns */}
        <Card className="shadow-sm">
          <CardHeader>
            <CardTitle>Recent Campaigns</CardTitle>
          </CardHeader>
          <CardContent>
            {campaigns.length === 0 ? (
              <div className="text-center py-12 text-gray-500">
                <img
                  src="/empty-state.svg"
                  alt="No campaigns"
                  className="mx-auto w-40 mb-4 opacity-70"
                />
                No campaigns yet. Create your first one!
              </div>
            ) : (
              <div className="divide-y divide-gray-200">
                {campaigns.map((campaign) => (
                  <div
                    key={campaign.id}
                    className="flex items-center justify-between py-4 hover:bg-gray-50 px-3 rounded-lg transition"
                  >
                    <div>
                      <h3 className="font-medium text-gray-900">{campaign.name}</h3>
                      <p className="text-sm text-gray-600">{campaign.subject}</p>
                      <p className="text-xs text-gray-400">
                        {new Date(campaign.created_at).toLocaleDateString()}
                      </p>
                    </div>
                    <span
                      className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                        campaign.status === 'active'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-600'
                      }`}
                    >
                      {campaign.status}
                    </span>
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
