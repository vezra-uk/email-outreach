'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { withAuth } from '../../../contexts/AuthContext';
import { apiClient } from '@/utils/api';
import { Lead } from '@/types';
import LeadOpensTracker from '@/components/LeadOpensTracker';

interface SequenceStep {
  id: number;
  step_number: number;
  name: string;
  ai_prompt?: string;
  delay_days: number;
  delay_hours: number;
  is_active: string;
}

interface EmailSequence {
  id: number;
  name: string;
  description?: string;
  status: string;
  created_at: string;
  steps: SequenceStep[];
}

interface SequenceProgress {
  total_leads: number;
  active_leads: number;
  completed_leads: number;
  stopped_leads: number;
  replied_leads: number;
  avg_step: number;
}

function SequenceDetailPage() {
  const params = useParams();
  const router = useRouter();
  const sequenceId = params.id as string;
  
  const [sequence, setSequence] = useState<EmailSequence | null>(null);
  const [progress, setProgress] = useState<SequenceProgress | null>(null);
  const [leads, setLeads] = useState<Lead[]>([]);
  const [selectedLeads, setSelectedLeads] = useState<number[]>([]);
  const [showAddLeads, setShowAddLeads] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (sequenceId) {
      fetchSequenceDetail();
      fetchSequenceProgress();
    }
  }, [sequenceId]);

  const fetchSequenceDetail = async () => {
    try {
      const data = await apiClient.getJson<EmailSequence>(`/api/sequences/${sequenceId}`);
      setSequence(data);
    } catch (error) {
      console.error('Error fetching sequence:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchSequenceProgress = async () => {
    try {
      const data = await apiClient.getJson<SequenceProgress>(`/api/sequences/${sequenceId}/progress`);
      setProgress(data);
    } catch (error) {
      console.error('Error fetching progress:', error);
    }
  };

  const fetchLeads = async () => {
    try {
      const data = await apiClient.getJson<Lead[]>(`/api/leads/`);
      setLeads(data);
    } catch (error) {
      console.error('Error fetching leads:', error);
    }
  };

  const addLeadsToSequence = async () => {
    if (selectedLeads.length === 0) return;

    try {
      await apiClient.post(`/api/sequences/${sequenceId}/leads`, {
        lead_ids: selectedLeads,
        sequence_id: parseInt(sequenceId)
      });

      alert(`Added ${selectedLeads.length} leads to sequence!`);
      setShowAddLeads(false);
      setSelectedLeads([]);
      fetchSequenceProgress(); // Refresh progress
    } catch (error) {
      console.error('Error adding leads:', error);
      alert('Failed to add leads to sequence');
    }
  };

  const deleteSequence = async () => {
    if (!sequence) return;
    
    if (confirm(`Are you sure you want to delete the sequence "${sequence.name}"? This cannot be undone.`)) {
      try {
        await apiClient.delete(`/api/sequences/${sequenceId}`);
        alert('Sequence deleted successfully!');
        router.push('/sequences');
      } catch (error) {
        console.error('Error deleting sequence:', error);
        const errorMessage = error instanceof Error ? error.message : 'Failed to delete sequence';
        alert(`Failed to delete sequence: ${errorMessage}`);
      }
    }
  };

  const toggleLead = (leadId: number) => {
    setSelectedLeads(prev =>
      prev.includes(leadId)
        ? prev.filter(id => id !== leadId)
        : [...prev, leadId]
    );
  };

  if (loading) {
    return <div className="p-8">Loading sequence details...</div>;
  }

  if (!sequence) {
    return <div className="p-8">Sequence not found</div>;
  }

  return (
    <div className="p-8 max-w-6xl mx-auto">
      <div className="flex justify-between items-start mb-8">
        <div>
          <h1 className="text-3xl font-bold mb-2">{sequence.name}</h1>
          {sequence.description && (
            <p className="text-gray-600 mb-4">{sequence.description}</p>
          )}
          <span className={`text-sm px-3 py-1 rounded-full ${
            sequence.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'
          }`}>
            {sequence.status}
          </span>
        </div>
        
        <div className="space-x-4">
          <Button 
            onClick={() => {
              setShowAddLeads(true);
              fetchLeads();
            }}
            variant="outline"
          >
            Add Leads
          </Button>
          <Button 
            onClick={deleteSequence}
            variant="outline"
            className="text-red-600 hover:text-red-700 hover:border-red-300"
          >
            Delete Sequence
          </Button>
          <Button onClick={() => router.push('/sequences')}>
            Back to Sequences
          </Button>
        </div>
      </div>

      {/* Progress Statistics */}
      {progress && (
        <Card className="p-6 mb-8">
          <h2 className="text-xl font-semibold mb-4">Sequence Progress</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">{progress.total_leads}</div>
              <div className="text-sm text-gray-600">Total Leads</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">{progress.active_leads}</div>
              <div className="text-sm text-gray-600">Active</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">{progress.completed_leads}</div>
              <div className="text-sm text-gray-600">Completed</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-orange-600">{progress.replied_leads}</div>
              <div className="text-sm text-gray-600">Replied</div>
            </div>
          </div>
          <div className="mt-4">
            <div className="text-sm text-gray-600 mb-2">Average Step: {progress.avg_step.toFixed(1)}</div>
            {progress.total_leads > 0 && (
              <div className="w-full bg-gray-200 rounded-full h-3">
                <div 
                  className="bg-blue-600 h-3 rounded-full transition-all duration-300" 
                  style={{ 
                    width: `${(progress.completed_leads / progress.total_leads) * 100}%` 
                  }}
                ></div>
              </div>
            )}
          </div>
        </Card>
      )}

      {/* Email Opens Tracking */}
      <div className="mb-8">
        <LeadOpensTracker sequenceId={parseInt(sequenceId)} showFilters={false} />
      </div>

      {/* Sequence Steps */}
      <Card className="p-6">
        <h2 className="text-xl font-semibold mb-6">Email Steps</h2>
        
        <div className="space-y-6">
          {sequence.steps.map((step, index) => (
            <div key={step.id} className="border border-gray-200 rounded-lg p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center">
                  <div className="w-8 h-8 bg-blue-100 text-blue-800 rounded-full flex items-center justify-center font-semibold mr-4">
                    {step.step_number}
                  </div>
                  <h3 className="text-lg font-medium">{step.name}</h3>
                </div>
                <div className="text-sm text-gray-600">
                  {step.delay_days > 0 || step.delay_hours > 0 ? (
                    <>
                      Wait: {step.delay_days > 0 && `${step.delay_days}d`}
                      {step.delay_days > 0 && step.delay_hours > 0 && ' '}
                      {step.delay_hours > 0 && `${step.delay_hours}h`}
                    </>
                  ) : (
                    'Send immediately'
                  )}
                </div>
              </div>
              
              {step.ai_prompt && (
                <div>
                  <strong>AI Generation Instructions:</strong>
                  <div className="mt-2 p-3 bg-blue-50 rounded-md text-sm">
                    {step.ai_prompt}
                  </div>
                  <div className="mt-2 text-xs text-gray-500">
                    💡 The AI will generate both subject line and email content based on these instructions for each lead.
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </Card>

      {/* Add Leads Modal */}
      {showAddLeads && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-2xl max-h-[80vh] overflow-hidden">
            <h2 className="text-xl font-semibold mb-4">Add Leads to Sequence</h2>
            
            <div className="mb-4">
              <span className="text-sm text-gray-600">
                {selectedLeads.length} leads selected
              </span>
            </div>
            
            <div className="max-h-96 overflow-y-auto border border-gray-200 rounded-md mb-4">
              {leads.map((lead) => (
                <div key={lead.id} className="flex items-center p-3 border-b border-gray-100 last:border-b-0">
                  <input
                    type="checkbox"
                    checked={selectedLeads.includes(lead.id)}
                    onChange={() => toggleLead(lead.id)}
                    className="mr-3"
                  />
                  <div className="flex-1">
                    <div className="font-medium">{lead.first_name} {lead.last_name}</div>
                    <div className="text-sm text-gray-600">{lead.email}</div>
                    {lead.company && <div className="text-sm text-gray-500">{lead.company}</div>}
                  </div>
                </div>
              ))}
            </div>
            
            <div className="flex justify-end space-x-4">
              <Button 
                variant="outline" 
                onClick={() => {
                  setShowAddLeads(false);
                  setSelectedLeads([]);
                }}
              >
                Cancel
              </Button>
              <Button 
                onClick={addLeadsToSequence}
                disabled={selectedLeads.length === 0}
              >
                Add {selectedLeads.length} Leads
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default withAuth(SequenceDetailPage);