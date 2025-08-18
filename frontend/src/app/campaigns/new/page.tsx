'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import MessagePreview from '@/components/MessagePreview';
import { apiClient } from '@/utils/api'
import { withAuth } from '../../../contexts/AuthContext';
import { Lead, LeadGroup, SendingProfile } from '@/types';

interface SequenceStep {
  step_number: number;
  name: string;
  ai_prompt: string;
  delay_days: number;
  delay_hours: number;
  include_previous_emails: boolean;
}

interface CreatedSequence {
  id: number;
  name: string;
}

function NewSequencePage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [leads, setLeads] = useState<Lead[]>([]);
  const [groups, setGroups] = useState<LeadGroup[]>([]);
  const [profiles, setProfiles] = useState<SendingProfile[]>([]);
  const [selectedLeads, setSelectedLeads] = useState<number[]>([]);
  const [showPreview, setShowPreview] = useState(false);
  const [previewStep, setPreviewStep] = useState<SequenceStep | null>(null);
  const [selectionMode, setSelectionMode] = useState<'individual' | 'groups'>('individual');
  
  const [sequenceData, setSequenceData] = useState({
    name: '',
    description: '',
    sending_profile_id: null as number | null,
    steps: [
      {
        step_number: 1,
        name: 'Initial Outreach',
        ai_prompt: 'Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead\'s name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.',
        delay_days: 0,
        delay_hours: 0,
        include_previous_emails: false
      }
    ]
  });

  useEffect(() => {
    fetchLeads();
    fetchGroups();
    fetchProfiles();
  }, []);

const fetchLeads = async () => {
  try {
    const data = await apiClient.getJson<Lead[]>('/api/leads/')
    setLeads(data)
  } catch (error) {
    console.error('Failed to fetch leads:', error)
  }
}

const fetchGroups = async () => {
  try {
    const data = await apiClient.getJson<LeadGroup[]>('/api/groups/')
    setGroups(Array.isArray(data) ? data : [])
  } catch (error) {
    console.error('Failed to fetch groups:', error)
    setGroups([])
  }
}

const fetchProfiles = async () => {
  try {
    const data = await apiClient.getJson<SendingProfile[]>('/api/sending-profiles/')
    const profilesArray = Array.isArray(data) ? data : []
    setProfiles(profilesArray)
    // Set default profile as selected if available
    const defaultProfile = profilesArray.find((p: SendingProfile) => p.is_default)
    if (defaultProfile) {
      setSequenceData(prev => ({ ...prev, sending_profile_id: defaultProfile.id }));
    }
  } catch (error) {
    console.error('Failed to fetch sending profiles:', error)
    setProfiles([])
  }
}

  const loadGroupLeads = async (groupId: number) => {
    try {
      const data = await apiClient.getJson<Lead[]>(`/api/groups/${groupId}/leads/`);
      const groupLeadIds = data.map((lead: Lead) => lead.id);
      
      setSelectedLeads(prev => Array.from(new Set([...prev, ...groupLeadIds])));
    } catch (error) {
      console.error('Error fetching group leads:', error);
    }
  };

  const addStep = () => {
    const stepNumber = sequenceData.steps.length + 1;
    const contextPrompt = stepNumber === 2 
      ? 'Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn\'t respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.'
      : `Write a professional follow-up email for step ${stepNumber} of the sequence. Reference the previous emails in the conversation naturally. The recipient hasn't responded yet, so try a different approach or provide more value. Keep it concise and respectful. Create an engaging subject line that stands out.`;

    const newStep: SequenceStep = {
      step_number: stepNumber,
      name: `Follow-up ${stepNumber}`,
      ai_prompt: contextPrompt,
      delay_days: 3,
      delay_hours: 0,
      include_previous_emails: true
    };
    
    setSequenceData({
      ...sequenceData,
      steps: [...sequenceData.steps, newStep]
    });
  };

  const removeStep = (stepNumber: number) => {
    if (sequenceData.steps.length <= 1) return;
    
    const updatedSteps = sequenceData.steps
      .filter(step => step.step_number !== stepNumber)
      .map((step, index) => ({ ...step, step_number: index + 1 }));
    
    setSequenceData({
      ...sequenceData,
      steps: updatedSteps
    });
  };

  const updateStep = (stepNumber: number, field: keyof SequenceStep, value: string | number | boolean) => {
    const updatedSteps = sequenceData.steps.map(step =>
      step.step_number === stepNumber ? { ...step, [field]: value } : step
    );
    
    setSequenceData({
      ...sequenceData,
      steps: updatedSteps
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      // Create sequence
      const sequence = await apiClient.postJson<CreatedSequence>('/api/campaigns/', {
        name: sequenceData.name,
        description: sequenceData.description,
        sending_profile_id: sequenceData.sending_profile_id,
        steps: sequenceData.steps,
      });

      // Add leads to sequence if any selected
      if (selectedLeads.length > 0) {
        await apiClient.post(`/api/campaigns/${sequence.id}/leads/`, {
          lead_ids: selectedLeads,
          sequence_id: sequence.id,
        });
      }

      router.push('/campaigns');
    } catch (error) {
      console.error('Error creating sequence:', error);
      alert('Failed to create sequence');
    } finally {
      setLoading(false);
    }
  };

  const toggleLead = (leadId: number) => {
    setSelectedLeads(prev =>
      prev.includes(leadId)
        ? prev.filter(id => id !== leadId)
        : [...prev, leadId]
    );
  };

  const selectAllLeads = () => {
    setSelectedLeads(leads.map(lead => lead.id));
  };

  const deselectAllLeads = () => {
    setSelectedLeads([]);
  };

  return (
    <div className="p-8 max-w-4xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Create Email Sequence</h1>
        <p className="text-gray-600">Set up an automated email sequence with multiple steps and delays</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-8">
        {/* Basic Info */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">Sequence Information</h2>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Sequence Name</label>
              <input
                type="text"
                required
                className="w-full p-3 border border-gray-300 rounded-md"
                value={sequenceData.name}
                onChange={(e) => setSequenceData({ ...sequenceData, name: e.target.value })}
                placeholder="e.g. New Lead Onboarding"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium mb-2">Description (optional)</label>
              <textarea
                className="w-full p-3 border border-gray-300 rounded-md h-20"
                value={sequenceData.description}
                onChange={(e) => setSequenceData({ ...sequenceData, description: e.target.value })}
                placeholder="Brief description of this sequence..."
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-2">Sending Profile</label>
              <select
                value={sequenceData.sending_profile_id || ''}
                onChange={(e) => setSequenceData({ 
                  ...sequenceData, 
                  sending_profile_id: e.target.value ? parseInt(e.target.value) : null 
                })}
                className="w-full p-3 border border-gray-300 rounded-md"
              >
                <option value="">No sending profile</option>
                {profiles.map((profile) => (
                  <option key={profile.id} value={profile.id}>
                    {profile.name} ({profile.sender_name})
                    {profile.is_default ? ' - Default' : ''}
                  </option>
                ))}
              </select>
              <p className="text-sm text-gray-500 mt-1">
                Select a sending profile to replace placeholders like [Your Name] with your actual details
              </p>
            </div>
          </div>
        </Card>

        {/* Email Steps */}
        <Card className="p-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-semibold">Email Steps</h2>
            <Button type="button" onClick={addStep} variant="outline">
              Add Step
            </Button>
          </div>

          {sequenceData.steps.map((step, index) => (
            <div key={step.step_number} className="border border-gray-200 rounded-lg p-4 mb-4">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-medium">Step {step.step_number}</h3>
                {sequenceData.steps.length > 1 && (
                  <Button 
                    type="button" 
                    onClick={() => removeStep(step.step_number)}
                    variant="outline"
                    size="sm"
                  >
                    Remove
                  </Button>
                )}
              </div>

              <div className="mb-4">
                <label className="block text-sm font-medium mb-2">Step Name</label>
                <input
                  type="text"
                  required
                  className="w-full p-2 border border-gray-300 rounded-md"
                  value={step.name}
                  onChange={(e) => updateStep(step.step_number, 'name', e.target.value)}
                />
              </div>

              <div className="grid grid-cols-2 gap-4 mb-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Delay (Days)</label>
                  <input
                    type="number"
                    min="0"
                    className="w-full p-2 border border-gray-300 rounded-md"
                    value={step.delay_days}
                    onChange={(e) => updateStep(step.step_number, 'delay_days', parseInt(e.target.value))}
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium mb-2">Delay (Hours)</label>
                  <input
                    type="number"
                    min="0"
                    max="23"
                    className="w-full p-2 border border-gray-300 rounded-md"
                    value={step.delay_hours}
                    onChange={(e) => updateStep(step.step_number, 'delay_hours', parseInt(e.target.value))}
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">
                  AI Email Generation Instructions 
                  {step.step_number > 1 && <span className="text-sm text-blue-600 ml-2">(Context: Email #{step.step_number} in sequence)</span>}
                </label>
                <textarea
                  required
                  className="w-full p-3 border border-gray-300 rounded-md h-32"
                  value={step.ai_prompt}
                  onChange={(e) => updateStep(step.step_number, 'ai_prompt', e.target.value)}
                  placeholder={step.step_number === 1 
                    ? "Tell the AI how to write the initial email and subject line. The AI will generate unique, personalized content for each lead."
                    : "Tell the AI how to write this follow-up email. Include how it should reference previous emails in the sequence and what new value to provide."}
                />
                <p className="text-sm text-gray-500 mt-1">
                  {step.step_number === 1 
                    ? "This is the first email in the sequence. The AI will generate both subject line and email content based on these instructions."
                    : `This is email #${step.step_number} in the sequence. The AI will automatically have context of previous emails and generate both subject and content.`}
                </p>
              </div>

              {step.step_number > 1 && (
                <div className="mt-4">
                  <label className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      checked={step.include_previous_emails || false}
                      onChange={(e) => updateStep(step.step_number, 'include_previous_emails', e.target.checked)}
                      className="rounded border-gray-300"
                    />
                    <span className="text-sm font-medium">Include previous emails for context</span>
                  </label>
                  <p className="text-xs text-gray-500 mt-1 ml-6">
                    When checked, the AI will see the subject and content of previous emails in this sequence to maintain continuity and avoid repetition.
                  </p>
                </div>
              )}

              <div className="pt-4 border-t border-gray-200">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    setPreviewStep(step);
                    setShowPreview(true);
                  }}
                  disabled={!step.ai_prompt.trim() || selectedLeads.length === 0}
                >
                  Preview Step {step.step_number}
                </Button>
              </div>
            </div>
          ))}
        </Card>

        {/* Lead Selection */}
        <Card className="p-6">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold">Add Recipients to Sequence</h2>
            <div className="flex gap-2">
              <Button 
                type="button"
                variant={selectionMode === 'individual' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setSelectionMode('individual')}
              >
                Individual Leads
              </Button>
              <Button 
                type="button"
                variant={selectionMode === 'groups' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setSelectionMode('groups')}
              >
                Groups
              </Button>
            </div>
          </div>

          {selectionMode === 'individual' ? (
            <>
              <div className="mb-4 space-x-2">
                <Button type="button" onClick={selectAllLeads} variant="outline" size="sm">
                  Select All
                </Button>
                <Button type="button" onClick={deselectAllLeads} variant="outline" size="sm">
                  Deselect All
                </Button>
                <span className="text-sm text-gray-600">
                  {selectedLeads.length} of {leads.length} leads selected
                </span>
              </div>

              <div className="max-h-60 overflow-y-auto border border-gray-200 rounded-md">
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
                {leads.length === 0 && (
                  <div className="text-center py-4">
                    <p className="text-gray-500 mb-2">No leads available.</p>
                    <a href="/leads" className="text-blue-600">Import some leads first</a>
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="space-y-3">
              {groups.map(group => (
                <div key={group.id} className="flex items-center justify-between p-3 border border-gray-200 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div 
                      className="w-4 h-4 rounded-full"
                      style={{ backgroundColor: group.color }}
                    />
                    <div>
                      <div className="font-medium">{group.name}</div>
                      <div className="text-sm text-gray-600">
                        {group.lead_count} lead{group.lead_count !== 1 ? 's' : ''}
                        {group.description && ` • ${group.description}`}
                      </div>
                    </div>
                  </div>
                  <Button 
                    type="button"
                    size="sm"
                    onClick={() => loadGroupLeads(group.id)}
                  >
                    Add Group
                  </Button>
                </div>
              ))}
              {groups.length === 0 && (
                <div className="text-center py-4">
                  <p className="text-gray-500 mb-2">No groups available.</p>
                  <a href="/groups" className="text-blue-600">Create some groups first</a>
                </div>
              )}
              {selectedLeads.length > 0 && (
                <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                  <div className="text-sm font-medium text-blue-900">
                    Selected: {selectedLeads.length} lead{selectedLeads.length !== 1 ? 's' : ''} from groups
                  </div>
                  <Button 
                    type="button"
                    size="sm"
                    variant="outline"
                    onClick={() => setSelectedLeads([])}
                    className="mt-2"
                  >
                    Clear Selection
                  </Button>
                </div>
              )}
            </div>
          )}
        </Card>

        {/* Submit */}
        <div className="flex justify-end space-x-4">
          <Button type="button" variant="outline" onClick={() => router.push('/campaigns')}>
            Cancel
          </Button>
          <Button type="submit" disabled={loading}>
            {loading ? 'Creating...' : 'Create Sequence'}
          </Button>
        </div>
      </form>

      {showPreview && previewStep && (
        <MessagePreview
          template=""
          aiPrompt={previewStep.ai_prompt}
          leads={leads.filter(lead => selectedLeads.includes(lead.id))}
          onClose={() => {
            setShowPreview(false);
            setPreviewStep(null);
          }}
        />
      )}
    </div>
  );
}

export default withAuth(NewSequencePage);