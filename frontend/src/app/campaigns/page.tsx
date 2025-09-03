'use client';

import { useState, useEffect } from 'react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Pagination } from '@/components/ui/pagination';
import Link from 'next/link';
import { withAuth } from '../../contexts/AuthContext';
import { apiClient } from '@/utils/api';
import { usePagination } from '@/hooks/usePagination';
import { CampaignWithProgress, PaginatedResponse } from '@/types';


function SequencesPage() {
  const [campaigns, setCampaigns] = useState<CampaignWithProgress[]>([]);
  const [paginatedData, setPaginatedData] = useState<PaginatedResponse<CampaignWithProgress> | null>(null);
  const [loading, setLoading] = useState(true);
  const { pagination, goToPage, getQueryParams } = usePagination({ initialPerPage: 12 });

  useEffect(() => {
    fetchCampaigns();
  }, [pagination.page, pagination.per_page]);

  const fetchCampaigns = async () => {
    try {
      setLoading(true);
      const queryParams = getQueryParams();
      const data = await apiClient.getJson<PaginatedResponse<CampaignWithProgress>>(
        `/api/campaigns/paginated?${queryParams}`
      );
      
      setPaginatedData(data);
      setCampaigns(data.items);
    } catch (error) {
      console.error('Error fetching campaigns:', error);
      setCampaigns([]);
      setPaginatedData(null);
    } finally {
      setLoading(false);
    }
  };

  const triggerSequenceEmails = async () => {
    try {
      await apiClient.post('/api/campaigns/send');
      alert('Sequence emails queued for sending!');
    } catch (error) {
      console.error('Error triggering campaign emails:', error);
      alert('Failed to trigger campaign emails');
    }
  };

  const pauseCampaign = async (campaignId: number, campaignName: string) => {
    if (confirm(`Pause campaign "${campaignName}"? No emails will be sent while paused.`)) {
      try {
        await apiClient.post(`/api/campaigns/${campaignId}/pause`);
        alert('Campaign paused successfully!');
        fetchCampaigns(); // Refresh the list
      } catch (error) {
        console.error('Error pausing campaign:', error);
        const errorMessage = error instanceof Error ? error.message : 'Failed to pause campaign';
        alert(`Failed to pause campaign: ${errorMessage}`);
      }
    }
  };

  const unpauseCampaign = async (campaignId: number, campaignName: string) => {
    if (confirm(`Resume campaign "${campaignName}"? Email sending will continue.`)) {
      try {
        await apiClient.post(`/api/campaigns/${campaignId}/unpause`);
        alert('Campaign resumed successfully!');
        fetchCampaigns(); // Refresh the list
      } catch (error) {
        console.error('Error resuming campaign:', error);
        const errorMessage = error instanceof Error ? error.message : 'Failed to resume campaign';
        alert(`Failed to resume campaign: ${errorMessage}`);
      }
    }
  };

  const deleteSequence = async (campaignId: number, campaignName: string) => {
    if (confirm(`Are you sure you want to delete the campaign "${campaignName}"? This cannot be undone.`)) {
      try {
        await apiClient.delete(`/api/campaigns/${campaignId}`);
        alert('Sequence deleted successfully!');
        fetchCampaigns(); // Refresh the list
      } catch (error) {
        console.error('Error deleting campaign:', error);
        const errorMessage = error instanceof Error ? error.message : 'Failed to delete campaign';
        alert(`Failed to delete campaign: ${errorMessage}`);
      }
    }
  };

  if (loading) {
    return <div className="p-8">Loading campaigns...</div>;
  }

  return (
    <div className="p-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Email Sequences</h1>
        <div className="space-x-4">
          <Button onClick={triggerSequenceEmails} variant="outline">
            Send Due Sequences
          </Button>
          <Link href="/campaigns/new">
            <Button>Create New Sequence</Button>
          </Link>
        </div>
      </div>

      {campaigns.length === 0 ? (
        <Card className="p-8 text-center">
          <h2 className="text-xl mb-4">No campaigns found</h2>
          <p className="text-gray-600 mb-4">Create your first email campaign to start automated follow-ups</p>
          <Link href="/campaigns/new">
            <Button>Create Your First Sequence</Button>
          </Link>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {campaigns.map((campaign) => (
            <Card key={campaign.id} className="p-6">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-lg font-semibold mb-1">{campaign.name}</h3>
                  {campaign.description && (
                    <p className="text-gray-600 text-sm mb-2">{campaign.description}</p>
                  )}
                  <span className={`text-xs px-2 py-1 rounded-full ${
                    campaign.status === 'active' ? 'bg-green-100 text-green-800' :
                    campaign.status === 'paused' ? 'bg-yellow-100 text-yellow-800' :
                    'bg-gray-100 text-gray-600'
                  }`}>
                    {campaign.status}
                  </span>
                </div>
              </div>

              <div className="mb-4 space-y-2">
                <div className="text-sm">
                  <strong>Total Leads:</strong> {campaign.total_leads}
                </div>
                <div className="text-sm">
                  <strong>Sent:</strong> {campaign.emails_sent} | 
                  <strong> Opened:</strong> {campaign.emails_opened}
                </div>
                <div className="text-sm">
                  <strong>Completion Rate:</strong> {campaign.completion_rate}% | 
                  <strong> Open Rate:</strong> {campaign.open_rate}%
                </div>
                {campaign.total_leads > 0 && (
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div 
                      className="bg-blue-600 h-2 rounded-full" 
                      style={{ 
                        width: `${campaign.completion_rate}%` 
                      }}
                    ></div>
                  </div>
                )}
              </div>

              <div className="flex justify-between items-center">
                <span className="text-xs text-gray-500">
                  Created {new Date(campaign.created_at).toLocaleDateString()}
                </span>
                <div className="flex flex-wrap gap-2">
                  <Link href={`/campaigns/${campaign.id}`}>
                    <Button variant="outline" size="sm">View Details</Button>
                  </Link>
                  {campaign.status === 'active' && (
                    <Button 
                      variant="outline" 
                      size="sm" 
                      onClick={() => pauseCampaign(campaign.id, campaign.name)}
                      className="text-yellow-600 hover:text-yellow-700 hover:border-yellow-300"
                    >
                      Pause
                    </Button>
                  )}
                  {campaign.status === 'paused' && (
                    <Button 
                      variant="outline" 
                      size="sm" 
                      onClick={() => unpauseCampaign(campaign.id, campaign.name)}
                      className="text-green-600 hover:text-green-700 hover:border-green-300"
                    >
                      Resume
                    </Button>
                  )}
                  <Button 
                    variant="outline" 
                    size="sm" 
                    onClick={() => deleteSequence(campaign.id, campaign.name)}
                    className="text-red-600 hover:text-red-700 hover:border-red-300"
                  >
                    Delete
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
      
      {/* Pagination */}
      {paginatedData && paginatedData.total_pages > 1 && (
        <div className="mt-8">
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
    </div>
  );
}

export default withAuth(SequencesPage);