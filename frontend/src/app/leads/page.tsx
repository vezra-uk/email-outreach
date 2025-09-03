'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { Dialog } from '../../components/ui/dialog';
import { Pagination } from '../../components/ui/pagination';
import { Plus, Filter, Upload, Download, Settings } from 'lucide-react';
import CSVUpload from '../../components/CSVUpload';
import LeadForm from '../../components/forms/LeadForm';
import BulkLeadImportForm from '../../components/forms/BulkLeadImportForm';
import LeadsTable from '../../components/LeadsTable';
import { useLeads } from '@/hooks/useLeads';
import { Lead, NewLead, Campaign } from '@/types';
import { withAuth } from '../../contexts/AuthContext';
import { apiClient } from '@/utils/api';

interface BulkImportResult {
  created: number;
  errors: any[];
}

function Leads() {
  const [industries, setIndustries] = useState<string[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [showAddForm, setShowAddForm] = useState(false);
  const [showBulkForm, setShowBulkForm] = useState(false);
  const [showCSVUpload, setShowCSVUpload] = useState(false);
  const [editingLead, setEditingLead] = useState<Lead | null>(null);
  const [showEditForm, setShowEditForm] = useState(false);
  const [selectedIndustry, setSelectedIndustry] = useState('');
  const [searchCompany, setSearchCompany] = useState('');
  const [showIndustryManager, setShowIndustryManager] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [appliedFilters, setAppliedFilters] = useState({ industry: '', company: '' });
  
  const { 
    leads, 
    paginatedData, 
    pagination, 
    goToPage, 
    loading, 
    error, 
    refetch, 
    createLead, 
    updateLead, 
    deleteLead 
  } = useLeads({ 
    paginated: true, 
    industry: appliedFilters.industry || undefined,
    company: appliedFilters.company || undefined 
  });

  useEffect(() => {
    fetchIndustries();
    fetchCampaigns();
  }, []);

  const fetchIndustries = async () => {
    try {
      const data = await apiClient.getJson('/api/leads/industries');
      setIndustries(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Failed to fetch industries:', error);
      setIndustries([]);
    }
  };

  const fetchCampaigns = async () => {
    try {
      const data = await apiClient.getJson('/api/campaigns');
      setCampaigns(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Failed to fetch campaigns:', error);
      setCampaigns([]);
    }
  };

  const handleAddLead = async (leadData: NewLead) => {
    setIsSubmitting(true);
    try {
      await createLead(leadData);
      setShowAddForm(false);
      alert('Lead added successfully!');
    } catch (error) {
      alert(`Error: ${error instanceof Error ? error.message : 'Failed to add lead'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleEditLead = (lead: Lead) => {
    setEditingLead(lead);
    setShowEditForm(true);
  };

  const handleUpdateLead = async (leadData: NewLead) => {
    if (!editingLead) return;
    
    setIsSubmitting(true);
    try {
      await updateLead(editingLead.id, leadData);
      setEditingLead(null);
      setShowEditForm(false);
      alert('Lead updated successfully!');
    } catch (error) {
      alert(`Error: ${error instanceof Error ? error.message : 'Failed to update lead'}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteLead = async (leadId: number, leadEmail: string) => {
    if (!confirm(`Are you sure you want to delete lead: ${leadEmail}?`)) {
      return;
    }
    
    try {
      await deleteLead(leadId);
      alert('Lead deleted successfully!');
    } catch (error) {
      alert(`Error: ${error instanceof Error ? error.message : 'Failed to delete lead'}`);
    }
  };

  const handleBulkImport = async (leadsList: any[]) => {
    setIsSubmitting(true);
    try {
      const result = await apiClient.postJson<BulkImportResult>('/api/leads/bulk', leadsList);
      setShowBulkForm(false);
      refetch();
      alert(`Successfully imported ${result.created} leads. ${result.errors.length} errors.`);
      if (result.errors.length > 0) {
        console.log('Import errors:', result.errors);
      }
    } catch (error) {
      alert('Failed to import leads');
      console.error(error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const exportToCSV = () => {
    const headers = ['Email', 'First Name', 'Last Name', 'Company', 'Title', 'Phone', 'Website', 'Industry', 'Status', 'Created'];
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
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'leads.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  if (loading) {
    return <div className="p-8">Loading leads...</div>;
  }

  if (error) {
    return <div className="p-8 text-red-600">Error: {error}</div>;
  }

  // Apply filters (now handled server-side)
  const applyFilters = () => {
    setAppliedFilters({ industry: selectedIndustry, company: searchCompany });
  };
  
  // Reset filters
  const clearFilters = () => {
    setSelectedIndustry('');
    setSearchCompany('');
    setAppliedFilters({ industry: '', company: '' });
  };
  
  // Use leads directly since filtering is now server-side
  const filteredLeads = leads;

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-4">Lead Management</h1>
        
        <div className="flex flex-wrap gap-4 mb-6">
          <Button onClick={() => setShowAddForm(true)}>
            <Plus className="mr-2 h-4 w-4" />
            Add Lead
          </Button>
          
          <Button variant="outline" onClick={() => setShowBulkForm(true)}>
            <Upload className="mr-2 h-4 w-4" />
            Bulk Import
          </Button>
          
          <Button variant="outline" onClick={() => setShowCSVUpload(true)}>
            <Upload className="mr-2 h-4 w-4" />
            CSV Upload
          </Button>
          
          <Button variant="outline" onClick={exportToCSV}>
            <Download className="mr-2 h-4 w-4" />
            Export CSV
          </Button>
        </div>

        {/* Filters */}
        <div className="flex flex-wrap gap-4 mb-6">
          <div>
            <select
              value={selectedIndustry}
              onChange={(e) => setSelectedIndustry(e.target.value)}
              className="p-2 border rounded"
            >
              <option value="">All Industries</option>
              {industries.map(industry => (
                <option key={industry} value={industry}>{industry}</option>
              ))}
            </select>
          </div>
          
          <div>
            <input
              type="text"
              placeholder="Search by company..."
              value={searchCompany}
              onChange={(e) => setSearchCompany(e.target.value)}
              className="p-2 border rounded"
              onKeyDown={(e) => e.key === 'Enter' && applyFilters()}
            />
          </div>
          
          <Button onClick={applyFilters} variant="outline">
            Apply Filters
          </Button>
          
          {(appliedFilters.industry || appliedFilters.company) && (
            <Button onClick={clearFilters} variant="outline">
              Clear Filters
            </Button>
          )}
        </div>
      </div>

      {/* Forms */}
      {showAddForm && (
        <Card className="mb-6">
          <CardHeader>
            <CardTitle>Add New Lead</CardTitle>
          </CardHeader>
          <CardContent>
            <LeadForm
              campaigns={campaigns}
              onSubmit={handleAddLead}
              onCancel={() => setShowAddForm(false)}
              isLoading={isSubmitting}
            />
          </CardContent>
        </Card>
      )}

      <Dialog
        isOpen={showEditForm}
        onClose={() => {
          setShowEditForm(false);
          setEditingLead(null);
        }}
        title="Edit Lead"
      >
        {editingLead && (
          <LeadForm
            lead={editingLead}
            campaigns={campaigns}
            onSubmit={handleUpdateLead}
            onCancel={() => {
              setShowEditForm(false);
              setEditingLead(null);
            }}
            isLoading={isSubmitting}
          />
        )}
      </Dialog>

      {showBulkForm && (
        <Card className="mb-6">
          <CardHeader>
            <CardTitle>Bulk Import Leads</CardTitle>
          </CardHeader>
          <CardContent>
            <BulkLeadImportForm
              onSubmit={handleBulkImport}
              onCancel={() => setShowBulkForm(false)}
              isLoading={isSubmitting}
            />
          </CardContent>
        </Card>
      )}

      {showCSVUpload && (
        <Card className="mb-6">
          <CardHeader>
            <CardTitle>CSV Upload</CardTitle>
          </CardHeader>
          <CardContent>
            <CSVUpload 
              onUploadComplete={() => {
                setShowCSVUpload(false);
                refetch();
              }}
              onClose={() => setShowCSVUpload(false)}
            />
          </CardContent>
        </Card>
      )}

      {/* Leads Table */}
      <Card>
        <CardHeader>
          <CardTitle>
            Leads ({paginatedData ? paginatedData.total : filteredLeads.length})
            {(appliedFilters.industry || appliedFilters.company) && (
              <span className="text-sm font-normal text-gray-600 ml-2">
                (filtered)
              </span>
            )}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <LeadsTable
            leads={filteredLeads}
            onEdit={handleEditLead}
            onDelete={handleDeleteLead}
          />
          
          {/* Pagination */}
          {paginatedData && paginatedData.total_pages > 1 && (
            <div className="mt-6">
              <Pagination
                currentPage={paginatedData.page}
                totalPages={paginatedData.total_pages}
                hasNext={paginatedData.has_next}
                hasPrev={paginatedData.has_prev}
                onPageChange={goToPage}
                totalItems={paginatedData.total}
                itemsPerPage={paginatedData.per_page}
              />
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export default withAuth(Leads);