'use client';

import { useState, useEffect } from 'react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import Link from 'next/link';
import { withAuth } from '../../contexts/AuthContext';
import { apiClient } from '@/utils/api';

interface Campaign {
  id: number;
  name: string;
  description?: string;
  status: string;
  created_at: string;
}

interface CampaignProgress {
  total_leads: number;
  active_leads: number;
  completed_leads: number;
  stopped_leads: number;
  replied_leads: number;
  avg_step: number;
}

function SequencesPage() {
  const [campaigns, setSequences] = useState<Campaign[]>([]);
  const [progress, setProgress] = useState<Record<number, CampaignProgress>>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchSequences();
  }, []);

  const fetchSequences = async () => {
    try {
      const data = await apiClient.getJson<Campaign[]>('/api/campaigns');
      setSequences(data);

      // Fetch progress for each campaign
      const progressPromises = data.map(async (seq: Campaign) => {
        try {
          const progressData = await apiClient.getJson<CampaignProgress>(`/api/campaigns/${seq.id}/progress`);
          return { id: seq.id, progress: progressData };
        } catch (error) {
          console.error(`Error fetching progress for campaign ${seq.id}:`, error);
          return { id: seq.id, progress: { total_leads: 0, active_leads: 0, completed_leads: 0, stopped_leads: 0, replied_leads: 0, avg_step: 0 } };
        }
      });

      const progressResults = await Promise.all(progressPromises);
      const progressMap: Record<number, CampaignProgress> = {};
      progressResults.forEach(({ id, progress }) => {
        progressMap[id] = progress;
      });
      setProgress(progressMap);
    } catch (error) {
      console.error('Error fetching campaigns:', error);
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

  const deleteSequence = async (campaignId: number, campaignName: string) => {
    if (confirm(`Are you sure you want to delete the campaign "${campaignName}"? This cannot be undone.`)) {
      try {
        await apiClient.delete(`/api/campaigns/${campaignId}`);
        alert('Sequence deleted successfully!');
        fetchSequences(); // Refresh the list
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
                    campaign.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'
                  }`}>
                    {campaign.status}
                  </span>
                </div>
              </div>

              {progress[campaign.id] && (
                <div className="mb-4 space-y-2">
                  <div className="text-sm">
                    <strong>Total Leads:</strong> {progress[campaign.id].total_leads}
                  </div>
                  <div className="text-sm">
                    <strong>Active:</strong> {progress[campaign.id].active_leads} | 
                    <strong> Completed:</strong> {progress[campaign.id].completed_leads} | 
                    <strong> Replied:</strong> {progress[campaign.id].replied_leads}
                  </div>
                  <div className="text-sm">
                    <strong>Avg Step:</strong> {progress[campaign.id].avg_step.toFixed(1)}
                  </div>
                  {progress[campaign.id].total_leads > 0 && (
                    <div className="w-full bg-gray-200 rounded-full h-2">
                      <div 
                        className="bg-blue-600 h-2 rounded-full" 
                        style={{ 
                          width: `${(progress[campaign.id].completed_leads / progress[campaign.id].total_leads) * 100}%` 
                        }}
                      ></div>
                    </div>
                  )}
                </div>
              )}

              <div className="flex justify-between items-center">
                <span className="text-xs text-gray-500">
                  Created {new Date(campaign.created_at).toLocaleDateString()}
                </span>
                <div className="space-x-2">
                  <Link href={`/campaigns/${campaign.id}`}>
                    <Button variant="outline" size="sm">View Details</Button>
                  </Link>
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
    </div>
  );
}

export default withAuth(SequencesPage);