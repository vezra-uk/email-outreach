'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { ExternalLink, MousePointer, TrendingUp, Users, Calendar } from 'lucide-react'
import { apiClient } from '@/utils/api'

interface LinkClick {
  id: number
  tracking_id: string
  original_url: string
  ip_address: string
  user_agent: string
  referer: string
  clicked_at: string
  campaign_info?: {
    id: number
    name: string
  }
  sequence_info?: {
    id: number
    name: string
  }
  lead_info?: {
    id: number
    email: string
    name: string
  }
}

interface ClickAnalytics {
  total_clicks: number
  unique_clicks: number
  click_rate: number
  most_clicked_links: Array<{
    url: string
    clicks: number
  }>
  recent_clicks: LinkClick[]
}

interface ClickAnalyticsProps {
  campaignId?: number
  sequenceId?: number
  days?: number
}

export default function ClickAnalytics({ campaignId, sequenceId, days = 30 }: ClickAnalyticsProps) {
  const [analytics, setAnalytics] = useState<ClickAnalytics | null>(null)
  const [loading, setLoading] = useState(true)
  const [selectedDays, setSelectedDays] = useState(days)

  useEffect(() => {
    fetchAnalytics()
  }, [campaignId, sequenceId, selectedDays])

  const fetchAnalytics = async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({
        days: selectedDays.toString()
      })
      
      if (campaignId) params.append('campaign_id', campaignId.toString())
      if (sequenceId) params.append('sequence_id', sequenceId.toString())

      const data = await apiClient.getJson<ClickAnalytics>(`/api/analytics/clicks?${params}`)
      setAnalytics(data)
    } catch (error) {
      console.error('Error fetching click analytics:', error)
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString()
  }

  const truncateUrl = (url: string, maxLength: number = 50) => {
    return url.length > maxLength ? url.substring(0, maxLength) + '...' : url
  }

  if (loading) {
    return (
      <Card>
        <CardContent className="p-6">
          <div className="text-center">Loading click analytics...</div>
        </CardContent>
      </Card>
    )
  }

  if (!analytics) {
    return (
      <Card>
        <CardContent className="p-6">
          <div className="text-center text-gray-500">No click data available</div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header with Time Range Selection */}
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold">Link Click Analytics</h2>
        <div className="flex gap-2">
          {[7, 30, 90].map((dayOption) => (
            <Button
              key={dayOption}
              variant={selectedDays === dayOption ? "default" : "outline"}
              size="sm"
              onClick={() => setSelectedDays(dayOption)}
            >
              {dayOption}d
            </Button>
          ))}
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <MousePointer className="h-5 w-5 text-blue-500" />
              <div>
                <p className="text-sm text-gray-600">Total Clicks</p>
                <p className="text-2xl font-bold">{analytics.total_clicks}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Users className="h-5 w-5 text-green-500" />
              <div>
                <p className="text-sm text-gray-600">Unique Clicks</p>
                <p className="text-2xl font-bold">{analytics.unique_clicks}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <TrendingUp className="h-5 w-5 text-purple-500" />
              <div>
                <p className="text-sm text-gray-600">Click Rate</p>
                <p className="text-2xl font-bold">{analytics.click_rate}%</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Calendar className="h-5 w-5 text-orange-500" />
              <div>
                <p className="text-sm text-gray-600">Time Period</p>
                <p className="text-2xl font-bold">{selectedDays}d</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Most Clicked Links */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <ExternalLink className="h-5 w-5" />
              Most Clicked Links
            </CardTitle>
          </CardHeader>
          <CardContent>
            {analytics.most_clicked_links.length > 0 ? (
              <div className="space-y-3">
                {analytics.most_clicked_links.map((link, index) => (
                  <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div className="flex-1">
                      <a
                        href={link.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                        title={link.url}
                      >
                        {truncateUrl(link.url)}
                      </a>
                    </div>
                    <div className="text-right">
                      <span className="bg-blue-100 text-blue-800 px-2 py-1 rounded-full text-sm font-medium">
                        {link.clicks} clicks
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-gray-500 text-center py-4">No links clicked yet</p>
            )}
          </CardContent>
        </Card>

        {/* Recent Clicks */}
        <Card>
          <CardHeader>
            <CardTitle>Recent Clicks</CardTitle>
          </CardHeader>
          <CardContent>
            {analytics.recent_clicks.length > 0 ? (
              <div className="space-y-3 max-h-96 overflow-y-auto">
                {analytics.recent_clicks.map((click) => (
                  <div key={click.id} className="border-l-4 border-blue-500 pl-4 py-2">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <a
                          href={click.original_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                          title={click.original_url}
                        >
                          {truncateUrl(click.original_url, 40)}
                        </a>
                        
                        {/* Lead Info */}
                        {click.lead_info && (
                          <p className="text-xs text-gray-600 mt-1">
                            <span className="font-medium">{click.lead_info.name}</span> ({click.lead_info.email})
                          </p>
                        )}
                        
                        {/* Campaign/Sequence Info */}
                        {click.campaign_info && (
                          <p className="text-xs text-blue-600 mt-1">
                            Campaign: {click.campaign_info.name}
                          </p>
                        )}
                        {click.sequence_info && (
                          <p className="text-xs text-purple-600 mt-1">
                            Sequence: {click.sequence_info.name}
                          </p>
                        )}
                        
                        {/* Click Details */}
                        <p className="text-xs text-gray-500 mt-1">
                          {formatDate(click.clicked_at)} • IP: {click.ip_address}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-gray-500 text-center py-4">No recent clicks</p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}