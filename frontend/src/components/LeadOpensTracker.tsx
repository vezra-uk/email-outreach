'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { Badge } from './ui/badge'
import { 
  Mail, 
  User, 
  Building2, 
  Calendar, 
  Eye, 
  Filter,
  ChevronDown,
  ChevronUp
} from 'lucide-react'
import { apiClient } from '@/utils/api'

interface OpenData {
  type: 'sequence' | 'campaign'
  name: string
  id: number
  opens: number
  sent_at: string
  tracking_id: string
}

interface LeadWithOpens {
  id: number
  email: string
  first_name: string
  last_name: string
  company: string
  title: string
  industry: string
  opens_data: OpenData[]
  total_opens: number
}

interface LeadOpensResponse {
  leads: LeadWithOpens[]
  total: number
}

interface LeadOpensTrackerProps {
  campaignId?: number
  sequenceId?: number
  showFilters?: boolean
}

export default function LeadOpensTracker({ 
  campaignId, 
  sequenceId, 
  showFilters = true 
}: LeadOpensTrackerProps) {
  const [leads, setLeads] = useState<LeadWithOpens[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedDays, setSelectedDays] = useState(30)
  const [expandedLeads, setExpandedLeads] = useState<Set<number>>(new Set())
  const [totalLeads, setTotalLeads] = useState(0)

  useEffect(() => {
    fetchLeadOpens()
  }, [campaignId, sequenceId, selectedDays])

  const fetchLeadOpens = async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({
        days: selectedDays.toString(),
        limit: '100'
      })
      
      if (campaignId) params.append('campaign_id', campaignId.toString())
      if (sequenceId) params.append('sequence_id', sequenceId.toString())

      const data = await apiClient.getJson<LeadOpensResponse>(`/api/leads/opened-emails?${params}`)
      setLeads(data.leads)
      setTotalLeads(data.total)
    } catch (error) {
      console.error('Error fetching lead opens:', error)
    } finally {
      setLoading(false)
    }
  }

  const toggleExpanded = (leadId: number) => {
    const newExpanded = new Set(expandedLeads)
    if (newExpanded.has(leadId)) {
      newExpanded.delete(leadId)
    } else {
      newExpanded.add(leadId)
    }
    setExpandedLeads(newExpanded)
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const getLeadName = (lead: LeadWithOpens) => {
    const parts = [lead.first_name, lead.last_name].filter(Boolean)
    return parts.length > 0 ? parts.join(' ') : 'Unknown'
  }

  if (loading) {
    return (
      <Card>
        <CardContent className="p-6">
          <div className="text-center">Loading email opens...</div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header with Filters */}
      {showFilters && (
        <div className="flex justify-between items-center">
          <div>
            <h2 className="text-2xl font-bold">Email Opens Tracking</h2>
            <p className="text-gray-600">{totalLeads} leads have opened emails</p>
          </div>
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
      )}

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <User className="h-5 w-5 text-blue-500" />
              <div>
                <p className="text-sm text-gray-600">Leads Who Opened</p>
                <p className="text-2xl font-bold">{totalLeads}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Eye className="h-5 w-5 text-green-500" />
              <div>
                <p className="text-sm text-gray-600">Total Opens</p>
                <p className="text-2xl font-bold">
                  {leads.reduce((sum, lead) => sum + lead.total_opens, 0)}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Calendar className="h-5 w-5 text-purple-500" />
              <div>
                <p className="text-sm text-gray-600">Time Period</p>
                <p className="text-2xl font-bold">{selectedDays}d</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Leads List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Mail className="h-5 w-5" />
            Leads with Email Opens
          </CardTitle>
        </CardHeader>
        <CardContent>
          {leads.length > 0 ? (
            <div className="space-y-4">
              {leads.map((lead) => (
                <div key={lead.id} className="border rounded-lg p-4 hover:bg-gray-50">
                  <div 
                    className="flex items-center justify-between cursor-pointer"
                    onClick={() => toggleExpanded(lead.id)}
                  >
                    <div className="flex-1">
                      <div className="flex items-center gap-3">
                        <div>
                          <h3 className="font-semibold text-lg">{getLeadName(lead)}</h3>
                          <p className="text-gray-600">{lead.email}</p>
                          {lead.company && (
                            <p className="text-sm text-gray-500 flex items-center gap-1">
                              <Building2 className="h-3 w-3" />
                              {lead.company}
                              {lead.title && ` • ${lead.title}`}
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex items-center gap-3">
                      <div className="text-right">
                        <div className="flex items-center gap-2">
                          <Eye className="h-4 w-4 text-green-500" />
                          <span className="font-semibold">{lead.total_opens} opens</span>
                        </div>
                        <p className="text-sm text-gray-500">
                          {lead.opens_data.length} email{lead.opens_data.length !== 1 ? 's' : ''}
                        </p>
                      </div>
                      {expandedLeads.has(lead.id) ? (
                        <ChevronUp className="h-5 w-5 text-gray-400" />
                      ) : (
                        <ChevronDown className="h-5 w-5 text-gray-400" />
                      )}
                    </div>
                  </div>

                  {/* Expanded Details */}
                  {expandedLeads.has(lead.id) && (
                    <div className="mt-4 pt-4 border-t">
                      <h4 className="font-medium mb-3">Email Open Details:</h4>
                      <div className="space-y-2">
                        {lead.opens_data.map((openData, index) => (
                          <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                            <div className="flex-1">
                              <div className="flex items-center gap-2">
                                <Badge 
                                  variant={openData.type === 'sequence' ? 'default' : 'secondary'}
                                  className="text-xs"
                                >
                                  {openData.type}
                                </Badge>
                                <span className="font-medium">{openData.name}</span>
                              </div>
                              <p className="text-sm text-gray-600 mt-1">
                                Sent: {formatDate(openData.sent_at)}
                              </p>
                              <p className="text-xs text-gray-500">
                                Tracking ID: {openData.tracking_id}
                              </p>
                            </div>
                            <div className="text-right">
                              <div className="flex items-center gap-1">
                                <Eye className="h-4 w-4 text-green-500" />
                                <span className="font-semibold">{openData.opens}</span>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8">
              <Eye className="h-12 w-12 text-gray-300 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No Opens Yet</h3>
              <p className="text-gray-600">
                No leads have opened emails in the selected time period.
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}