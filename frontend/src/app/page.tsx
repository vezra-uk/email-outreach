// frontend/src/app/page.tsx - Enhanced Dashboard
'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card'
import { Button } from '../components/ui/button'
import { Plus, Mail, Users, Activity, Eye, BarChart3, TrendingUp } from 'lucide-react'

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
        fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/campaigns/progress`)
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
      case 'draft': return 'bg-gray-100 text-gray-600'
      default: return 'bg-gray-100 text-gray-600'
    }
  }

  const StatCard = ({ 
    title, 
    value, 
    icon: Icon, 
    children, 
    trend 
  }: { 
    title: string
    value: React.ReactNode
    icon: any
    children?: React.ReactNode
    trend?: { value: string; isPositive: boolean }
  }) => (
    <Card className="shadow-md hover:shadow-lg transition border border-gray-100">
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm font-medium text-gray-500">{title}</CardTitle>
          <Icon className="w-4 h-4 text-gray-400" />
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-3xl font-bold mb-2">{value}</div>
        {trend && (
          <div className={`flex items-center text-sm ${trend.isPositive ? 'text-green-600' : 'text-red-600'}`}>
            <TrendingUp className={`w-3 h-3 mr-1 ${!trend.isPositive ? 'rotate-180' : ''}`} />
            {trend.value}
          </div>
        )}
        {children}
      </CardContent>
    </Card>
  )

  // Calculate trends (you can enhance this with historical data)
  const openRate = stats.emails_sent_today > 0 
    ? Math.round((stats.emails_opened_today / stats.emails_sent_today) * 100)
    : 0

  const activeCampaignsWithProgress = campaigns.filter(c => c.status === 'active' && c.completion_rate > 0)
  const avgCompletionRate = activeCampaignsWithProgress.length > 0
    ? Math.round(activeCampaignsWithProgress.reduce((acc, c) => acc + c.completion_rate, 0) / activeCampaignsWithProgress.length)
    : 0

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 p-8">
      <div className="max-w-7xl mx-auto space-y-8">
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

        {/* Stats Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          <StatCard 
            title="Total Active Leads" 
            value={stats.total_leads}
            icon={Users}
          />

          <StatCard 
            title="Daily Progress" 
            value={`${stats.emails_sent_today}/${stats.daily_limit}`}
            icon={Mail}
          >
            <ProgressBar 
              current={stats.emails_sent_today} 
              total={stats.daily_limit}
              className="mt-3"
            />
            <div className="text-xs text-gray-500 mt-1">
              {Math.round((stats.emails_sent_today / stats.daily_limit) * 100)}% of daily limit
            </div>
          </StatCard>

          <StatCard 
            title="Open Rate Today" 
            value={`${openRate}%`}
            icon={Eye}
            trend={{ value: `${stats.emails_opened_today} opens`, isPositive: openRate > 20 }}
          />

          <StatCard 
            title="Active Campaigns" 
            value={stats.active_campaigns}
            icon={Activity}
            trend={
              avgCompletionRate > 0 
                ? { value: `${avgCompletionRate}% avg progress`, isPositive: avgCompletionRate > 50 }
                : undefined
            }
          />
        </div>

        {/* Quick Actions */}
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
            onClick={() => (window.location.href = '/campaigns')}
          >
            <BarChart3 className="mr-2 h-4 w-4" />
            View All Campaigns
          </Button>

          <Button
            variant="outline"
            onClick={() => (window.location.href = '/leads')}
          >
            <Users className="mr-2 h-4 w-4" />
            Manage Leads
          </Button>
        </div>

        {/* Campaign Overview */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
          {/* Recent Campaigns */}
          <Card className="xl:col-span-2 shadow-sm">
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>Campaign Progress</CardTitle>
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => (window.location.href = '/campaigns')}
                >
                  View All
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {campaigns.length === 0 ? (
                <div className="text-center py-12 text-gray-500">
                  <BarChart3 className="mx-auto w-16 h-16 text-gray-400 mb-4" />
                  <h3 className="text-lg font-medium text-gray-900 mb-2">No campaigns yet</h3>
                  <p className="text-gray-600 mb-6">Create your first email campaign to get started</p>
                  <Button onClick={() => window.location.href = '/campaigns/new'}>
                    <Plus className="mr-2 h-4 w-4" />
                    Create Campaign
                  </Button>
                </div>
              ) : (
                <div className="space-y-4">
                  {campaigns.slice(0, 5).map((campaign) => (
                    <div
                      key={campaign.id}
                      className="flex items-center justify-between p-4 hover:bg-gray-50 rounded-lg transition"
                    >
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-3">
                          <h3 className="font-medium text-gray-900 truncate">{campaign.name}</h3>
                          <span className={`px-2 py-1 text-xs font-medium rounded-full ${getStatusColor(campaign.status)}`}>
                            {campaign.status}
                          </span>
                        </div>
                        <p className="text-sm text-gray-600 truncate mt-1">{campaign.subject}</p>
                        
                        <div className="flex items-center gap-4 mt-3">
                          <div className="flex-1">
                            <div className="flex justify-between text-xs text-gray-600 mb-1">
                              <span>Progress</span>
                              <span>{campaign.emails_sent}/{campaign.total_leads}</span>
                            </div>
                            <ProgressBar 
                              current={campaign.emails_sent} 
                              total={campaign.total_leads}
                            />
                          </div>
                          
                          <div className="flex gap-4 text-xs text-gray-500">
                            <div className="text-center">
                              <div className="font-medium text-blue-600">{campaign.open_rate}%</div>
                              <div>Opens</div>
                            </div>
                            <div className="text-center">
                              <div className="font-medium text-green-600">{campaign.click_rate}%</div>
                              <div>Clicks</div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Quick Stats */}
          <Card className="shadow-sm">
            <CardHeader>
              <CardTitle>Today's Performance</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="text-center">
                <div className="text-4xl font-bold text-blue-600 mb-2">
                  {stats.emails_sent_today}
                </div>
                <div className="text-sm text-gray-600">Emails Sent Today</div>
                <ProgressBar 
                  current={stats.emails_sent_today} 
                  total={stats.daily_limit}
                  className="mt-3"
                />
                <div className="text-xs text-gray-500 mt-1">
                  {stats.daily_limit - stats.emails_sent_today} remaining
                </div>
              </div>

              <div className="border-t pt-6">
                <div className="space-y-4">
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Opens</span>
                    <span className="font-medium">{stats.emails_opened_today}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Open Rate</span>
                    <span className="font-medium">{openRate}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Active Campaigns</span>
                    <span className="font-medium">{stats.active_campaigns}</span>
                  </div>
                </div>
              </div>

              {avgCompletionRate > 0 && (
                <div className="border-t pt-6 text-center">
                  <div className="text-2xl font-bold text-green-600 mb-1">
                    {avgCompletionRate}%
                  </div>
                  <div className="text-sm text-gray-600">Average Campaign Progress</div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}