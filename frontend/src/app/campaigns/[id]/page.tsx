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
  include_previous_emails?: boolean;
}

interface Campaign {
  id: number;
  name: string;
  description?: string;
  status: string;
  created_at: string;
  steps: SequenceStep[];
}

interface CampaignProgress {
  total_leads: number;
  active_leads: number;
  completed_leads: number;
  stopped_leads: number;
  replied_leads: number;
  avg_step: number;
}

interface EnrolledLead {
  id: number;
  lead_id: number;
  sequence_id: number;
  current_step: number;
  status: string;
  started_at: string;
  next_send_at: string | null;
  last_sent_at: string | null;
  first_name: string;
  last_name: string;
  email: string;
  company: string | null;
  lead_status: string;
}

function SequenceDetailPage() {
  const params = useParams();
  const router = useRouter();
  const sequenceId = params.id as string;
  
  const [sequence, setSequence] = useState<Campaign | null>(null);
  const [progress, setProgress] = useState<CampaignProgress | null>(null);
  const [leads, setLeads] = useState<Lead[]>([]);
  const [selectedLeads, setSelectedLeads] = useState<number[]>([]);
  const [showAddLeads, setShowAddLeads] = useState(false);
  const [enrolledLeads, setEnrolledLeads] = useState<EnrolledLead[]>([]);
  const [showEnrolledLeads, setShowEnrolledLeads] = useState(false);
  const [loading, setLoading] = useState(true);
  const [editingStep, setEditingStep] = useState<number | null>(null);
  const [editingStepData, setEditingStepData] = useState<{
    name: string;
    ai_prompt: string;
    delay_days: number;
    delay_hours: number;
    include_previous_emails: boolean;
  }>({
    name: '',
    ai_prompt: '',
    delay_days: 0,
    delay_hours: 0,
    include_previous_emails: false
  });

  useEffect(() => {
    if (sequenceId) {
      fetchSequenceDetail();
      fetchCampaignProgress();
    }
  }, [sequenceId]);

  const fetchSequenceDetail = async () => {
    try {
      const data = await apiClient.getJson<Campaign>(`/api/campaigns/${sequenceId}`);
      setSequence(data);
    } catch (error) {
      console.error('Error fetching sequence:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchCampaignProgress = async () => {
    try {
      const data = await apiClient.getJson<CampaignProgress>(`/api/campaigns/${sequenceId}/progress`);
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

  const fetchEnrolledLeads = async () => {
    try {
      const data = await apiClient.getJson<EnrolledLead[]>(`/api/campaigns/${sequenceId}/leads`);
      setEnrolledLeads(data);
    } catch (error) {
      console.error('Error fetching enrolled leads:', error);
    }
  };

  const removeLeadFromCampaign = async (leadId: number, leadName: string) => {
    if (confirm(`Remove ${leadName} from this campaign? This will stop all future emails for this lead.`)) {
      try {
        await apiClient.delete(`/api/campaigns/${sequenceId}/leads/${leadId}`);
        alert('Lead removed from campaign successfully!');
        fetchEnrolledLeads(); // Refresh the list
        fetchCampaignProgress(); // Update progress stats
      } catch (error) {
        console.error('Error removing lead:', error);
        alert('Failed to remove lead from campaign');
      }
    }
  };

  const addLeadsToSequence = async () => {
    if (selectedLeads.length === 0) return;

    try {
      await apiClient.post(`/api/campaigns/${sequenceId}/leads`, {
        lead_ids: selectedLeads,
        sequence_id: parseInt(sequenceId)
      });

      alert(`Added ${selectedLeads.length} leads to sequence!`);
      setShowAddLeads(false);
      setSelectedLeads([]);
      fetchCampaignProgress(); // Refresh progress
    } catch (error) {
      console.error('Error adding leads:', error);
      alert('Failed to add leads to sequence');
    }
  };

  const deleteSequence = async () => {
    if (!sequence) return;
    
    if (confirm(`Are you sure you want to delete the sequence "${sequence.name}"? This cannot be undone.`)) {
      try {
        await apiClient.delete(`/api/campaigns/${sequenceId}`);
        alert('Sequence deleted successfully!');
        router.push('/campaigns');
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

  const startEditStep = (step: SequenceStep) => {
    setEditingStep(step.id);
    setEditingStepData({
      name: step.name,
      ai_prompt: step.ai_prompt || '',
      delay_days: step.delay_days,
      delay_hours: step.delay_hours,
      include_previous_emails: step.include_previous_emails || false
    });
  };

  const cancelEditStep = () => {
    setEditingStep(null);
    setEditingStepData({
      name: '',
      ai_prompt: '',
      delay_days: 0,
      delay_hours: 0,
      include_previous_emails: false
    });
  };

  const saveStepEdit = async () => {
    if (!editingStep) return;

    try {
      await apiClient.patchJson(`/api/campaigns/${sequenceId}/steps/${editingStep}`, {
        name: editingStepData.name,
        ai_prompt: editingStepData.ai_prompt,
        delay_days: editingStepData.delay_days,
        delay_hours: editingStepData.delay_hours,
        include_previous_emails: editingStepData.include_previous_emails
      });

      alert('Step updated successfully!');
      cancelEditStep();
      fetchSequenceDetail(); // Refresh the sequence data
    } catch (error) {
      console.error('Error updating step:', error);
      alert('Failed to update step');
    }
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
              setShowEnrolledLeads(true);
              fetchEnrolledLeads();
            }}
            variant="outline"
          >
            View Enrolled Leads
          </Button>
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
          <Button onClick={() => router.push('/campaigns')}>
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
              {editingStep === step.id ? (
                // Edit Mode
                <div className="space-y-4">
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center">
                      <div className="w-8 h-8 bg-blue-100 text-blue-800 rounded-full flex items-center justify-center font-semibold mr-4">
                        {step.step_number}
                      </div>
                      <input
                        type="text"
                        value={editingStepData.name}
                        onChange={(e) => setEditingStepData(prev => ({ ...prev, name: e.target.value }))}
                        className="text-lg font-medium border border-gray-300 rounded px-2 py-1"
                        placeholder="Step name"
                      />
                    </div>
                    <div className="flex space-x-2">
                      <Button onClick={saveStepEdit} size="sm">Save</Button>
                      <Button onClick={cancelEditStep} size="sm" variant="outline">Cancel</Button>
                    </div>
                  </div>
                  
                  <div className="grid grid-cols-3 gap-4">
                    <div>
                      <label className="block text-sm font-medium mb-1">Delay Days</label>
                      <input
                        type="number"
                        min="0"
                        value={editingStepData.delay_days}
                        onChange={(e) => setEditingStepData(prev => ({ ...prev, delay_days: parseInt(e.target.value) || 0 }))}
                        className="w-full border border-gray-300 rounded px-2 py-1"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium mb-1">Delay Hours</label>
                      <input
                        type="number"
                        min="0"
                        max="23"
                        value={editingStepData.delay_hours}
                        onChange={(e) => setEditingStepData(prev => ({ ...prev, delay_hours: parseInt(e.target.value) || 0 }))}
                        className="w-full border border-gray-300 rounded px-2 py-1"
                      />
                    </div>
                    <div>
                      <label className="flex items-center space-x-2 text-sm font-medium">
                        <input
                          type="checkbox"
                          checked={editingStepData.include_previous_emails}
                          onChange={(e) => setEditingStepData(prev => ({ ...prev, include_previous_emails: e.target.checked }))}
                        />
                        <span>Include Previous Emails</span>
                      </label>
                    </div>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium mb-2">AI Generation Instructions</label>
                    <textarea
                      value={editingStepData.ai_prompt}
                      onChange={(e) => setEditingStepData(prev => ({ ...prev, ai_prompt: e.target.value }))}
                      placeholder="Enter detailed instructions for AI email generation..."
                      rows={4}
                      className="w-full border border-gray-300 rounded px-3 py-2 text-sm"
                    />
                    <div className="mt-1 text-xs text-gray-500">
                      💡 The AI will generate both subject line and email content based on these instructions for each lead.
                    </div>
                  </div>
                </div>
              ) : (
                // View Mode
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center">
                      <div className="w-8 h-8 bg-blue-100 text-blue-800 rounded-full flex items-center justify-center font-semibold mr-4">
                        {step.step_number}
                      </div>
                      <h3 className="text-lg font-medium">{step.name}</h3>
                    </div>
                    <div className="flex items-center space-x-4">
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
                      <Button
                        onClick={() => startEditStep(step)}
                        size="sm"
                        variant="outline"
                        className="text-blue-600 hover:text-blue-700 hover:border-blue-300"
                      >
                        Edit
                      </Button>
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
                  
                  {step.include_previous_emails && (
                    <div className="mt-3 text-sm text-purple-600">
                      📧 Includes context from previous emails in sequence
                    </div>
                  )}
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

      {/* Enrolled Leads Modal */}
      {showEnrolledLeads && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-6xl max-h-[90vh] overflow-hidden">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-xl font-semibold">Enrolled Leads ({enrolledLeads.length})</h2>
              <Button 
                variant="outline" 
                onClick={() => setShowEnrolledLeads(false)}
              >
                Close
              </Button>
            </div>
            
            <div className="overflow-x-auto">
              <table className="w-full border-collapse border border-gray-200">
                <thead>
                  <tr className="bg-gray-50">
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Lead</th>
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Email</th>
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Company</th>
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Status</th>
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Current Step</th>
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Next Send</th>
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Last Sent</th>
                    <th className="border border-gray-200 p-3 text-left text-sm font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {enrolledLeads.length === 0 ? (
                    <tr>
                      <td colSpan={8} className="border border-gray-200 p-8 text-center text-gray-500">
                        No leads enrolled in this campaign
                      </td>
                    </tr>
                  ) : (
                    enrolledLeads.map((lead) => (
                      <tr key={lead.id} className="hover:bg-gray-50">
                        <td className="border border-gray-200 p-3">
                          <div className="font-medium">{lead.first_name} {lead.last_name}</div>
                        </td>
                        <td className="border border-gray-200 p-3">
                          <div className="text-sm">{lead.email}</div>
                        </td>
                        <td className="border border-gray-200 p-3">
                          <div className="text-sm">{lead.company || '-'}</div>
                        </td>
                        <td className="border border-gray-200 p-3">
                          <span className={`text-xs px-2 py-1 rounded-full ${
                            lead.status === 'active' ? 'bg-green-100 text-green-800' :
                            lead.status === 'completed' ? 'bg-blue-100 text-blue-800' :
                            lead.status === 'stopped' ? 'bg-red-100 text-red-800' :
                            'bg-gray-100 text-gray-600'
                          }`}>
                            {lead.status}
                          </span>
                        </td>
                        <td className="border border-gray-200 p-3">
                          <div className="text-sm">Step {lead.current_step}</div>
                        </td>
                        <td className="border border-gray-200 p-3">
                          <div className="text-xs">
                            {lead.next_send_at 
                              ? new Date(lead.next_send_at).toLocaleString() 
                              : '-'
                            }
                          </div>
                        </td>
                        <td className="border border-gray-200 p-3">
                          <div className="text-xs">
                            {lead.last_sent_at 
                              ? new Date(lead.last_sent_at).toLocaleString() 
                              : 'Never'
                            }
                          </div>
                        </td>
                        <td className="border border-gray-200 p-3">
                          {lead.status === 'active' && (
                            <Button 
                              size="sm" 
                              variant="outline"
                              onClick={() => removeLeadFromCampaign(lead.lead_id, `${lead.first_name} ${lead.last_name}`)}
                              className="text-red-600 hover:text-red-700 hover:border-red-300"
                            >
                              Remove
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
            
            <div className="mt-4 text-sm text-gray-600">
              Total: {enrolledLeads.length} leads • 
              Active: {enrolledLeads.filter(l => l.status === 'active').length} • 
              Completed: {enrolledLeads.filter(l => l.status === 'completed').length} • 
              Stopped: {enrolledLeads.filter(l => l.status === 'stopped').length}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default withAuth(SequenceDetailPage);