// frontend/src/app/leads/page.tsx - Enhanced with website and industry
'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/card'
import { Button } from '../../components/ui/button'
import { Plus, Filter, Upload, Download } from 'lucide-react'

interface Lead {
  id: number
  email: string
  first_name: string
  last_name: string
  company: string
  title: string
  phone: string
  website: string  // New field
  industry: string  // New field
  status: string
  created_at: string
}

export default function Leads() {
  const [leads, setLeads] = useState<Lead[]>([])
  const [industries, setIndustries] = useState<string[]>([])
  const [showAddForm, setShowAddForm] = useState(false)
  const [showBulkForm, setShowBulkForm] = useState(false)
  const [selectedIndustry, setSelectedIndustry] = useState('')
  const [searchCompany, setSearchCompany] = useState('')
  const [newLead, setNewLead] = useState({
    email: '',
    first_name: '',
    last_name: '',
    company: '',
    title: '',
    phone: '',
    website: '',  // New field
    industry: ''  // New field
  })
  const [bulkLeads, setBulkLeads] = useState('')

  // Common industries for the dropdown
  const commonIndustries = [
    'Technology', 'Software', 'SaaS', 'E-commerce', 'Marketing', 'Advertising',
    'Finance', 'Banking', 'Insurance', 'Healthcare', 'Education', 'Manufacturing',
    'Real Estate', 'Construction', 'Consulting', 'Legal', 'Non-profit', 'Retail',
    'Hospitality', 'Transportation', 'Energy', 'Media', 'Entertainment', 'Other'
  ]

  useEffect(() => {
    fetchLeads()
    fetchIndustries()
  }, [])

  const fetchLeads = async () => {
    try {
      const params = new URLSearchParams()
      if (selectedIndustry) params.append('industry', selectedIndustry)
      if (searchCompany) params.append('company', searchCompany)
      
      const url = `${process.env.NEXT_PUBLIC_API_URL}/api/leads${params.toString() ? '/filter?' + params.toString() : ''}`
      const response = await fetch(url)
      const data = await response.json()
      setLeads(data)
    } catch (error) {
      console.error('Failed to fetch leads:', error)
    }
  }

  const fetchIndustries = async () => {
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/leads/industries`)
      const data = await response.json()
      setIndustries(data)
    } catch (error) {
      console.error('Failed to fetch industries:', error)
    }
  }

  useEffect(() => {
    const debounceTimer = setTimeout(() => {
      fetchLeads()
    }, 500)
    return () => clearTimeout(debounceTimer)
  }, [selectedIndustry, searchCompany])

  const handleAddLead = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      // Clean up website URL
      let website = newLead.website.trim()
      if (website && !website.startsWith('http') && !website.startsWith('www.')) {
        website = 'https://' + website
      }

      const leadData = { ...newLead, website }

      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/leads`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(leadData)
      })

      if (response.ok) {
        setNewLead({
          email: '',
          first_name: '',
          last_name: '',
          company: '',
          title: '',
          phone: '',
          website: '',
          industry: ''
        })
        setShowAddForm(false)
        fetchLeads()
        alert('Lead added successfully!')
      } else {
        const error = await response.json()
        alert(`Error: ${error.detail}`)
      }
    } catch (error) {
      alert('Failed to add lead')
      console.error(error)
    }
  }

  const handleBulkImport = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      // Parse CSV-like data
      const lines = bulkLeads.trim().split('\n')
      const leads = lines.map(line => {
        const [email, first_name, last_name, company, title, phone, website, industry] = line.split(',').map(s => s.trim())
        return {
          email: email || '',
          first_name: first_name || '',
          last_name: last_name || '',
          company: company || '',
          title: title || '',
          phone: phone || '',
          website: website || '',
          industry: industry || ''
        }
      }).filter(lead => lead.email) // Only include leads with email

      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/leads/bulk`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(leads)
      })

      if (response.ok) {
        const result = await response.json()
        setBulkLeads('')
        setShowBulkForm(false)
        fetchLeads()
        alert(`Successfully imported ${result.created} leads. ${result.errors.length} errors.`)
        if (result.errors.length > 0) {
          console.log('Import errors:', result.errors)
        }
      } else {
        const error = await response.json()
        alert(`Error: ${error.detail}`)
      }
    } catch (error) {
      alert('Failed to import leads')
      console.error(error)
    }
  }

  const exportToCSV = () => {
    const headers = ['Email', 'First Name', 'Last Name', 'Company', 'Title', 'Phone', 'Website', 'Industry', 'Status', 'Created']
    const csvContent = [
      headers.join(','),
      ...leads.map(lead => [
        lead.email,
        lead.first_name || '',
        lead.last_name || '',
        lead.company || '',
        lead.title || '',
        lead.phone || '',
        lead.website || '',
        lead.industry || '',
        lead.status,
        new Date(lead.created_at).toLocaleDateString()
      ].join(','))
    ].join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'leads.csv'
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        <header className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Lead Management</h1>
          <p className="text-gray-600 mt-2">Manage your email prospects with detailed information</p>
        </header>

        {/* Action Bar */}
        <div className="mb-6 flex flex-wrap gap-4 items-center justify-between">
          <div className="flex flex-wrap gap-2">
            <Button onClick={() => setShowAddForm(!showAddForm)}>
              <Plus className="mr-2 h-4 w-4" />
              {showAddForm ? 'Cancel' : 'Add Lead'}
            </Button>
            <Button variant="outline" onClick={() => setShowBulkForm(!showBulkForm)}>
              <Upload className="mr-2 h-4 w-4" />
              Bulk Import
            </Button>
            <Button variant="outline" onClick={exportToCSV}>
              <Download className="mr-2 h-4 w-4" />
              Export CSV
            </Button>
          </div>

          {/* Filters */}
          <div className="flex gap-4 items-center">
            <select
              value={selectedIndustry}
              onChange={(e) => setSelectedIndustry(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">All Industries</option>
              {Array.from(new Set([...industries, ...commonIndustries])).sort().map(industry => (
  <option key={industry} value={industry}>{industry}</option>
))}

            </select>
            
            <input
              type="text"
              placeholder="Search company..."
              value={searchCompany}
              onChange={(e) => setSearchCompany(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            
            {(selectedIndustry || searchCompany) && (
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => {
                  setSelectedIndustry('')
                  setSearchCompany('')
                }}
              >
                Clear Filters
              </Button>
            )}
          </div>
        </div>

        {/* Add Single Lead Form */}
        {showAddForm && (
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Add New Lead</CardTitle>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleAddLead} className="grid grid-cols-2 gap-4">
                <input
                  type="email"
                  placeholder="Email *"
                  required
                  value={newLead.email}
                  onChange={(e) => setNewLead(prev => ({ ...prev, email: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  type="text"
                  placeholder="First Name"
                  value={newLead.first_name}
                  onChange={(e) => setNewLead(prev => ({ ...prev, first_name: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  type="text"
                  placeholder="Last Name"
                  value={newLead.last_name}
                  onChange={(e) => setNewLead(prev => ({ ...prev, last_name: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  type="text"
                  placeholder="Company"
                  value={newLead.company}
                  onChange={(e) => setNewLead(prev => ({ ...prev, company: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  type="text"
                  placeholder="Title"
                  value={newLead.title}
                  onChange={(e) => setNewLead(prev => ({ ...prev, title: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  type="text"
                  placeholder="Phone"
                  value={newLead.phone}
                  onChange={(e) => setNewLead(prev => ({ ...prev, phone: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <input
                  type="url"
                  placeholder="Website (e.g., company.com)"
                  value={newLead.website}
                  onChange={(e) => setNewLead(prev => ({ ...prev, website: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <select
                  value={newLead.industry}
                  onChange={(e) => setNewLead(prev => ({ ...prev, industry: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">Select Industry</option>
                  {commonIndustries.map(industry => (
                    <option key={industry} value={industry}>{industry}</option>
                  ))}
                </select>
                <div className="col-span-2">
                  <Button type="submit">Add Lead</Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        {/* Bulk Import Form */}
        {showBulkForm && (
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Bulk Import Leads</CardTitle>
              <p className="text-sm text-gray-600">
                Enter leads in CSV format: email,first_name,last_name,company,title,phone,website,industry (one per line)
              </p>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleBulkImport} className="space-y-4">
                <textarea
                  value={bulkLeads}
                  onChange={(e) => setBulkLeads(e.target.value)}
                  rows={6}
                  placeholder="john@example.com,John,Doe,Acme Corp,CEO,555-1234,acme.com,Technology&#10;jane@example.com,Jane,Smith,Beta Inc,CTO,555-5678,beta.com,Software"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <div className="flex gap-2">
                  <Button type="submit">Import Leads</Button>
                  <Button type="button" variant="outline" onClick={() => setShowBulkForm(false)}>
                    Cancel
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        {/* Leads Table */}
        <Card>
          <CardHeader>
            <div className="flex justify-between items-center">
              <CardTitle>All Leads ({leads.length})</CardTitle>
              {(selectedIndustry || searchCompany) && (
                <div className="text-sm text-gray-600">
                  Filtered {selectedIndustry && `by industry: ${selectedIndustry}`}
                  {selectedIndustry && searchCompany && ', '}
                  {searchCompany && `company contains: "${searchCompany}"`}
                </div>
              )}
            </div>
          </CardHeader>
          <CardContent>
            {leads.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No leads found. {(selectedIndustry || searchCompany) ? 'Try adjusting your filters or' : ''} Add your first lead above!</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-2">Contact</th>
                      <th className="text-left py-2">Company</th>
                      <th className="text-left py-2">Industry</th>
                      <th className="text-left py-2">Website</th>
                      <th className="text-left py-2">Phone</th>
                      <th className="text-left py-2">Status</th>
                      <th className="text-left py-2">Added</th>
                    </tr>
                  </thead>
                  <tbody>
                    {leads.map(lead => (
                      <tr key={lead.id} className="border-b hover:bg-gray-50">
                        <td className="py-3">
                          <div>
                            <div className="font-medium">{lead.first_name} {lead.last_name}</div>
                            <div className="text-gray-500 text-xs">{lead.email}</div>
                            {lead.title && <div className="text-gray-500 text-xs">{lead.title}</div>}
                          </div>
                        </td>
                        <td className="py-3">
                          <div className="font-medium">{lead.company || '-'}</div>
                        </td>
                        <td className="py-3">
                          {lead.industry && (
                            <span className="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">
                              {lead.industry}
                            </span>
                          )}
                        </td>
                        <td className="py-3">
                          {lead.website ? (
                            <a 
                              href={lead.website.startsWith('http') ? lead.website : `https://${lead.website}`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-blue-600 hover:text-blue-800 text-xs"
                            >
                              {lead.website.replace(/^https?:\/\//, '')}
                            </a>
                          ) : (
                            '-'
                          )}
                        </td>
                        <td className="py-3 text-gray-600">
                          {lead.phone || '-'}
                        </td>
                        <td className="py-3">
                          <span className={`px-2 py-1 text-xs rounded-full ${
                            lead.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'
                          }`}>
                            {lead.status}
                          </span>
                        </td>
                        <td className="py-3 text-gray-500">
                          {new Date(lead.created_at).toLocaleDateString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}