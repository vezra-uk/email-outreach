// frontend/src/app/leads/page.tsx
'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/card'
import { Button } from '../../components/ui/button'

interface Lead {
  id: number
  email: string
  first_name: string
  last_name: string
  company: string
  title: string
  status: string
  created_at: string
}

export default function Leads() {
  const [leads, setLeads] = useState<Lead[]>([])
  const [showAddForm, setShowAddForm] = useState(false)
  const [newLead, setNewLead] = useState({
    email: '',
    first_name: '',
    last_name: '',
    company: '',
    title: '',
    phone: ''
  })

  useEffect(() => {
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

  const handleAddLead = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/leads`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(newLead)
      })

      if (response.ok) {
        setNewLead({
          email: '',
          first_name: '',
          last_name: '',
          company: '',
          title: '',
          phone: ''
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

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-6xl mx-auto">
        <header className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Lead Management</h1>
          <p className="text-gray-600 mt-2">Manage your email prospects</p>
        </header>

        <div className="mb-6">
          <Button onClick={() => setShowAddForm(!showAddForm)}>
            {showAddForm ? 'Cancel' : 'Add New Lead'}
          </Button>
        </div>

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
                <div className="col-span-2">
                  <Button type="submit">Add Lead</Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        <Card>
          <CardHeader>
            <CardTitle>All Leads ({leads.length})</CardTitle>
          </CardHeader>
          <CardContent>
            {leads.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <p>No leads yet. Add your first lead above!</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-2">Name</th>
                      <th className="text-left py-2">Email</th>
                      <th className="text-left py-2">Company</th>
                      <th className="text-left py-2">Title</th>
                      <th className="text-left py-2">Status</th>
                      <th className="text-left py-2">Added</th>
                    </tr>
                  </thead>
                  <tbody>
                    {leads.map(lead => (
                      <tr key={lead.id} className="border-b hover:bg-gray-50">
                        <td className="py-3">{lead.first_name} {lead.last_name}</td>
                        <td className="py-3">{lead.email}</td>
                        <td className="py-3">{lead.company || '-'}</td>
                        <td className="py-3">{lead.title || '-'}</td>
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
