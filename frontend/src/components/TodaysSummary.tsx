'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Badge } from './ui/badge'
import { 
  Clock, 
  Mail, 
  Eye, 
  MousePointer, 
  TrendingUp, 
  TrendingDown, 
  Target,
  Activity,
  Zap,
  CheckCircle,
  AlertCircle
} from 'lucide-react'
import { apiClient } from '../utils/api'

interface ActivityEvent {
  id: number
  type: 'email_sent' | 'email_opened' | 'email_clicked' | 'campaign_started' | 'lead_added'
  title: string
  description: string
  timestamp: string
  campaign_name?: string
  lead_email?: string
  metadata?: Record<string, any>
}

interface TodaysHighlight {
  type: 'top_campaign' | 'milestone' | 'goal_progress' | 'performance'
  title: string
  value: string
  description: string
  is_positive: boolean
}

interface TodayActivity {
  recent_events: ActivityEvent[]
  highlights: TodaysHighlight[]
  hourly_send_rate: number[]
  live_metrics: Record<string, any>
}

const getEventIcon = (type: string) => {
  switch (type) {
    case 'email_sent': return Mail
    case 'email_opened': return Eye
    case 'email_clicked': return MousePointer
    case 'campaign_started': return Zap
    case 'lead_added': return Target
    default: return Activity
  }
}

const getEventColor = (type: string) => {
  switch (type) {
    case 'email_sent': return 'bg-blue-100 text-blue-600'
    case 'email_opened': return 'bg-green-100 text-green-600'
    case 'email_clicked': return 'bg-purple-100 text-purple-600'
    case 'campaign_started': return 'bg-orange-100 text-orange-600'
    case 'lead_added': return 'bg-gray-100 text-gray-600'
    default: return 'bg-gray-100 text-gray-600'
  }
}

const formatTimeAgo = (timestamp: string) => {
  const now = new Date()
  const eventTime = new Date(timestamp)
  const diffMs = now.getTime() - eventTime.getTime()
  const diffMins = Math.floor(diffMs / (1000 * 60))
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
  
  if (diffMins < 1) return 'Just now'
  if (diffMins < 60) return `${diffMins}m ago`
  if (diffHours < 24) return `${diffHours}h ago`
  return eventTime.toLocaleDateString()
}

export function TodaysSummary() {
  const [activity, setActivity] = useState<TodayActivity>({
    recent_events: [],
    highlights: [],
    hourly_send_rate: Array(24).fill(0),
    live_metrics: {}
  })
  const [loading, setLoading] = useState(true)

  const fetchTodayActivity = async () => {
    try {
      const data = await apiClient.getJson<TodayActivity>('/api/dashboard/today-activity')
      setActivity(data)
    } catch (error) {
      console.error('Failed to fetch today activity:', error)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchTodayActivity()
    // Set up polling every 30 seconds for live updates
    const interval = setInterval(fetchTodayActivity, 30000)
    return () => clearInterval(interval)
  }, [])

  if (loading) {
    return (
      <Card className="shadow-sm">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Activity className="w-5 h-5 text-blue-600" />
            Happening Today
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="animate-pulse space-y-4">
            <div className="h-4 bg-gray-200 rounded w-3/4"></div>
            <div className="h-4 bg-gray-200 rounded w-1/2"></div>
            <div className="h-4 bg-gray-200 rounded w-2/3"></div>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Highlights */}
      {activity.highlights.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {activity.highlights.map((highlight, index) => (
            <Card key={index} className="shadow-sm">
              <CardContent className="p-4">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="font-medium text-gray-900">{highlight.title}</h4>
                  {highlight.is_positive ? (
                    <TrendingUp className="w-4 h-4 text-green-500" />
                  ) : (
                    <TrendingDown className="w-4 h-4 text-red-500" />
                  )}
                </div>
                <div className="text-2xl font-bold mb-1">{highlight.value}</div>
                <p className="text-sm text-gray-600">{highlight.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Activity */}
        <Card className="shadow-sm">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Clock className="w-5 h-5 text-blue-600" />
              Recent Activity
            </CardTitle>
          </CardHeader>
          <CardContent>
            {activity.recent_events.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Activity className="mx-auto w-12 h-12 text-gray-400 mb-3" />
                <p>No activity today yet</p>
                <p className="text-sm">Your daily activities will appear here</p>
              </div>
            ) : (
              <div className="space-y-3 max-h-96 overflow-y-auto">
                {activity.recent_events.map((event) => {
                  const Icon = getEventIcon(event.type)
                  return (
                    <div key={event.id} className="flex items-start gap-3 p-3 hover:bg-gray-50 rounded-lg transition">
                      <div className={`p-2 rounded-full ${getEventColor(event.type)}`}>
                        <Icon className="w-4 h-4" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <h4 className="font-medium text-gray-900">{event.title}</h4>
                          <span className="text-xs text-gray-500">
                            {formatTimeAgo(event.timestamp)}
                          </span>
                        </div>
                        <p className="text-sm text-gray-600 truncate">{event.description}</p>
                        {event.campaign_name && (
                          <Badge variant="secondary" className="text-xs mt-1">
                            {event.campaign_name}
                          </Badge>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Live Metrics */}
        <Card className="shadow-sm">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Zap className="w-5 h-5 text-orange-600" />
              Live Metrics
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-3 bg-blue-50 rounded-lg">
                <div className="flex items-center gap-2">
                  <Mail className="w-4 h-4 text-blue-600" />
                  <span className="font-medium">Emails Remaining</span>
                </div>
                <span className="text-xl font-bold text-blue-600">
                  {activity.live_metrics.emails_remaining || 0}
                </span>
              </div>
              
              <div className="flex items-center justify-between p-3 bg-green-50 rounded-lg">
                <div className="flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-green-600" />
                  <span className="font-medium">Active Campaigns</span>
                </div>
                <span className="text-xl font-bold text-green-600">
                  {activity.live_metrics.active_campaigns_today || 0}
                </span>
              </div>
              
              <div className="flex items-center justify-between p-3 bg-purple-50 rounded-lg">
                <div className="flex items-center gap-2">
                  <Eye className="w-4 h-4 text-purple-600" />
                  <span className="font-medium">Avg. Open Time</span>
                </div>
                <span className="text-xl font-bold text-purple-600">
                  {activity.live_metrics.avg_open_time_minutes || 0}m
                </span>
              </div>
              
              <div className="flex items-center justify-between p-3 bg-orange-50 rounded-lg">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-4 h-4 text-orange-600" />
                  <span className="font-medium">Response Rate</span>
                </div>
                <span className="text-xl font-bold text-orange-600">
                  {activity.live_metrics.response_rate || 0}%
                </span>
              </div>
            </div>

            {/* Simple hourly activity chart */}
            <div className="mt-6">
              <h4 className="font-medium text-gray-700 mb-3">Email Activity by Hour</h4>
              <div className="flex items-end gap-1 h-16">
                {activity.hourly_send_rate.map((count, hour) => (
                  <div
                    key={hour}
                    className="flex-1 bg-blue-200 rounded-t min-h-[4px] relative group hover:bg-blue-300 transition"
                    style={{ height: `${Math.max((count / Math.max(...activity.hourly_send_rate)) * 100, 4)}%` }}
                  >
                    <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-1 px-2 py-1 bg-gray-800 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition whitespace-nowrap">
                      {hour}:00 - {count} emails
                    </div>
                  </div>
                ))}
              </div>
              <div className="flex justify-between text-xs text-gray-500 mt-1">
                <span>00:00</span>
                <span>06:00</span>
                <span>12:00</span>
                <span>18:00</span>
                <span>23:59</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}