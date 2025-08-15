'use client';

import { useState, useEffect } from 'react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { apiClient } from '@/utils/api';

interface Lead {
  id: number;
  email: string;
  first_name?: string;
  last_name?: string;
  company?: string;
  title?: string;
}

interface SendingProfile {
  id: number;
  name: string;
  sender_name: string;
  sender_title?: string;
  sender_company?: string;
  sender_email: string;
  sender_phone?: string;
  sender_website?: string;
  signature?: string;
  is_default: boolean;
}

interface MessagePreviewProps {
  template: string;
  aiPrompt: string;
  leads: Lead[];
  onClose: () => void;
}

interface PreviewResponse {
  original_template: string;
  personalized_message: string;
  subject: string;
  lead_info: {
    id: number;
    email: string;
    first_name?: string;
    last_name?: string;
    company?: string;
    title?: string;
  };
}

export default function MessagePreview({ template, aiPrompt, leads, onClose }: MessagePreviewProps) {
  const [selectedLead, setSelectedLead] = useState<Lead | null>(leads[0] || null);
  const [selectedProfile, setSelectedProfile] = useState<SendingProfile | null>(null);
  const [profiles, setProfiles] = useState<SendingProfile[]>([]);
  const [preview, setPreview] = useState<PreviewResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [profilesLoading, setProfilesLoading] = useState(true);

  useEffect(() => {
    const fetchProfiles = async () => {
      try {
        const data = await apiClient.getJson<SendingProfile[]>('/api/sending-profiles/');
        setProfiles(Array.isArray(data) ? data : []);
        // Set default profile as selected if available
        const profilesArray = Array.isArray(data) ? data : [];
        const defaultProfile = profilesArray.find((p: SendingProfile) => p.is_default);
        if (defaultProfile) {
          setSelectedProfile(defaultProfile);
        }
      } catch (error) {
        console.error('Failed to fetch sending profiles:', error);
      } finally {
        setProfilesLoading(false);
      }
    };

    fetchProfiles();
  }, []);

  const generatePreview = async () => {
    if (!selectedLead) {
      setError('Please select a lead');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const data: PreviewResponse = await apiClient.postJson('/api/preview-message', {
        template: "",  // Empty since AI generates everything
        ai_prompt: aiPrompt,
        lead_id: selectedLead.id,
        sending_profile_id: selectedProfile?.id,
      });
      setPreview(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate preview');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        <div className="p-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-bold">Message Preview</h2>
            <Button variant="outline" onClick={onClose}>
              Close
            </Button>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Left side - Controls */}
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">
                  Sending Profile
                </label>
                <select
                  value={selectedProfile?.id || ''}
                  onChange={(e) => {
                    const profile = profiles.find(p => p.id === parseInt(e.target.value));
                    setSelectedProfile(profile || null);
                    setPreview(null); // Clear preview when profile changes
                  }}
                  className="w-full p-2 border border-gray-300 rounded-md"
                  disabled={profilesLoading}
                >
                  <option value="">No sending profile</option>
                  {profiles.map((profile) => (
                    <option key={profile.id} value={profile.id}>
                      {profile.name} ({profile.sender_name})
                      {profile.is_default ? ' - Default' : ''}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">
                  Select Lead for Preview
                </label>
                <select
                  value={selectedLead?.id || ''}
                  onChange={(e) => {
                    const lead = leads.find(l => l.id === parseInt(e.target.value));
                    setSelectedLead(lead || null);
                    setPreview(null); // Clear preview when lead changes
                  }}
                  className="w-full p-2 border border-gray-300 rounded-md"
                >
                  <option value="">Select a lead...</option>
                  {leads.map((lead) => (
                    <option key={lead.id} value={lead.id}>
                      {lead.first_name} {lead.last_name} - {lead.email}
                      {lead.company && ` (${lead.company})`}
                    </option>
                  ))}
                </select>
              </div>

              {selectedProfile && (
                <Card className="p-4">
                  <h3 className="font-medium mb-2">Sending Profile</h3>
                  <div className="text-sm space-y-1">
                    <div><span className="font-medium">Name:</span> {selectedProfile.sender_name}</div>
                    <div><span className="font-medium">Email:</span> {selectedProfile.sender_email}</div>
                    {selectedProfile.sender_company && <div><span className="font-medium">Company:</span> {selectedProfile.sender_company}</div>}
                    {selectedProfile.sender_title && <div><span className="font-medium">Title:</span> {selectedProfile.sender_title}</div>}
                    {selectedProfile.sender_phone && <div><span className="font-medium">Phone:</span> {selectedProfile.sender_phone}</div>}
                  </div>
                </Card>
              )}

              {selectedLead && (
                <Card className="p-4">
                  <h3 className="font-medium mb-2">Lead Information</h3>
                  <div className="text-sm space-y-1">
                    <div><span className="font-medium">Name:</span> {selectedLead.first_name} {selectedLead.last_name}</div>
                    <div><span className="font-medium">Email:</span> {selectedLead.email}</div>
                    {selectedLead.company && <div><span className="font-medium">Company:</span> {selectedLead.company}</div>}
                    {selectedLead.title && <div><span className="font-medium">Title:</span> {selectedLead.title}</div>}
                  </div>
                </Card>
              )}


              <Card className="p-4">
                <h3 className="font-medium mb-2">AI Email Generation Instructions</h3>
                <div className="text-sm bg-gray-50 p-3 rounded max-h-32 overflow-y-auto">
                  {aiPrompt || 'No AI instructions provided'}
                </div>
                <p className="text-xs text-gray-500 mt-2">
                  The AI will use these instructions to generate both the subject line and email content.
                </p>
              </Card>

              <Button 
                onClick={generatePreview} 
                disabled={!selectedLead || loading}
                className="w-full"
              >
                {loading ? 'Generating Preview...' : 'Generate AI Email Preview'}
              </Button>

              {error && (
                <div className="text-red-600 text-sm p-3 bg-red-50 rounded">
                  {error}
                </div>
              )}
            </div>

            {/* Right side - Preview */}
            <div>
              <Card className="p-4 h-full">
                <h3 className="font-medium mb-4">AI-Generated Preview</h3>
                
                {loading && (
                  <div className="flex items-center justify-center h-32">
                    <div className="text-gray-500">Generating personalized message...</div>
                  </div>
                )}

                {!loading && !preview && !error && (
                  <div className="flex items-center justify-center h-32 text-gray-500">
                    Select a lead and click "Generate AI Email Preview" to see the personalized message with subject line
                  </div>
                )}

                {preview && (
                  <div className="space-y-4">
                    <div>
                      <h4 className="font-medium text-sm text-gray-700 mb-2">For: {preview.lead_info.first_name} {preview.lead_info.last_name}</h4>
                      
                      {/* Subject Line */}
                      <div className="mb-3">
                        <label className="text-xs font-medium text-gray-600">Subject Line:</label>
                        <div className="bg-blue-50 border border-blue-200 rounded p-2 mt-1">
                          <div className="text-sm font-medium text-blue-900">
                            {preview.subject}
                          </div>
                        </div>
                      </div>

                      {/* Email Body */}
                      <div>
                        <label className="text-xs font-medium text-gray-600">Email Content:</label>
                        <div className="bg-white border border-gray-200 rounded p-4 mt-1 max-h-96 overflow-y-auto">
                          <div className="text-sm prose prose-sm max-w-none" dangerouslySetInnerHTML={{ __html: preview.personalized_message }} />
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>✓ AI-generated subject line and content</div>
                      <div>✓ Personalized using lead data</div>
                      <div>✓ Ready to send</div>
                    </div>
                  </div>
                )}
              </Card>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}