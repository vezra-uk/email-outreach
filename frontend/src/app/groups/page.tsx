'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { withAuth } from '../../contexts/AuthContext';
import { apiClient } from '@/utils/api';

interface LeadGroup {
  id: number;
  name: string;
  description?: string;
  color: string;
  lead_count: number;
  created_at: string;
}

interface Lead {
  id: number;
  email: string;
  first_name?: string;
  last_name?: string;
  company?: string;
  title?: string;
  status: string;
}

interface GroupDetail {
  id: number;
  name: string;
  description?: string;
  color: string;
  created_at: string;
  leads: Lead[];
}

const PRESET_COLORS = [
  '#3B82F6', '#EF4444', '#10B981', '#F59E0B',
  '#8B5CF6', '#06B6D4', '#84CC16', '#F97316',
  '#EC4899', '#6366F1', '#14B8A6', '#F59E0B'
];

function GroupsPage() {
  const [groups, setGroups] = useState<LeadGroup[]>([]);
  const [allLeads, setAllLeads] = useState<Lead[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [selectedGroup, setSelectedGroup] = useState<GroupDetail | null>(null);
  const [showEditModal, setShowEditModal] = useState(false);
  
  // Form states
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    color: '#3B82F6'
  });
  const [selectedLeadIds, setSelectedLeadIds] = useState<number[]>([]);

  useEffect(() => {
    fetchGroups();
    fetchAllLeads();
  }, []);

  const fetchGroups = async () => {
    try {
      const data = await apiClient.getJson<LeadGroup[]>('/api/groups/');
      setGroups(data);
    } catch (error) {
      console.error('Error fetching groups:', error);
    }
  };

  const fetchAllLeads = async () => {
    try {
      const data = await apiClient.getJson<Lead[]>('/api/leads/');
      setAllLeads(data);
    } catch (error) {
      console.error('Error fetching leads:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchGroupDetail = async (groupId: number) => {
    try {
      const data = await apiClient.getJson<GroupDetail>(`/api/groups/${groupId}/`);
      setSelectedGroup(data);
      setSelectedLeadIds(data.leads.map((lead: Lead) => lead.id));
    } catch (error) {
      console.error('Error fetching group detail:', error);
    }
  };

  const handleCreateGroup = async () => {
    if (!formData.name.trim()) return;

    try {
      const newGroup = await apiClient.postJson<LeadGroup>('/api/groups/', formData);
      
      // Add leads to the group if any selected
      if (selectedLeadIds.length > 0) {
        await apiClient.post(`/api/groups/${newGroup.id}/members/`, {
          lead_ids: selectedLeadIds
        });
      }

      // Reset form and refresh data
      setFormData({ name: '', description: '', color: '#3B82F6' });
      setSelectedLeadIds([]);
      setShowCreateForm(false);
      fetchGroups();
    } catch (error) {
      console.error('Error creating group:', error);
    }
  };

  const handleUpdateGroup = async () => {
    if (!selectedGroup) return;

    try {
      // Update group details
      await apiClient.put(`/api/groups/${selectedGroup.id}`, {
        name: formData.name,
        description: formData.description,
        color: formData.color
      });

      // Update group members
      await apiClient.post(`/api/groups/${selectedGroup.id}/members`, {
        lead_ids: selectedLeadIds
      });

      // Reset and refresh
      setShowEditModal(false);
      setSelectedGroup(null);
      fetchGroups();
    } catch (error) {
      console.error('Error updating group:', error);
    }
  };

  const handleDeleteGroup = async (groupId: number) => {
    if (!confirm('Are you sure you want to delete this group?')) return;

    try {
      await apiClient.delete(`/api/groups/${groupId}`);
      fetchGroups();
    } catch (error) {
      console.error('Error deleting group:', error);
    }
  };

  const openEditModal = (group: LeadGroup) => {
    setFormData({
      name: group.name,
      description: group.description || '',
      color: group.color
    });
    fetchGroupDetail(group.id);
    setShowEditModal(true);
  };

  const toggleLead = (leadId: number) => {
    setSelectedLeadIds(prev =>
      prev.includes(leadId)
        ? prev.filter(id => id !== leadId)
        : [...prev, leadId]
    );
  };

  if (loading) {
    return (
      <div className="p-8 max-w-6xl mx-auto">
        <div className="text-center">Loading...</div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-6xl mx-auto">
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold mb-2">Lead Groups</h1>
          <p className="text-gray-600">Organize your leads into groups for easier campaign management</p>
        </div>
        <Button onClick={() => setShowCreateForm(true)}>
          Create New Group
        </Button>
      </div>

      {/* Groups Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {groups.map((group) => (
          <Card key={group.id} className="hover:shadow-lg transition-shadow">
            <CardHeader className="pb-3">
              <div className="flex items-center gap-3">
                <div 
                  className="w-4 h-4 rounded-full"
                  style={{ backgroundColor: group.color }}
                />
                <CardTitle className="text-lg">{group.name}</CardTitle>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-gray-600 mb-4 min-h-[40px]">
                {group.description || 'No description'}
              </p>
              
              <div className="flex items-center justify-between mb-4">
                <span className="text-sm font-medium">
                  {group.lead_count} lead{group.lead_count !== 1 ? 's' : ''}
                </span>
                <span className="text-xs text-gray-500">
                  Created {new Date(group.created_at).toLocaleDateString()}
                </span>
              </div>

              <div className="flex gap-2">
                <Button 
                  size="sm" 
                  variant="outline" 
                  onClick={() => openEditModal(group)}
                  className="flex-1"
                >
                  Edit
                </Button>
                <Button 
                  size="sm" 
                  variant="outline" 
                  onClick={() => handleDeleteGroup(group.id)}
                  className="text-red-600 hover:text-red-700"
                >
                  Delete
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {groups.length === 0 && (
        <Card className="text-center py-12">
          <CardContent>
            <h3 className="text-lg font-medium mb-2">No Groups Yet</h3>
            <p className="text-gray-600 mb-4">Create your first lead group to get started</p>
            <Button onClick={() => setShowCreateForm(true)}>
              Create Your First Group
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Create/Edit Modal */}
      {(showCreateForm || showEditModal) && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-2xl font-bold">
                  {showEditModal ? 'Edit Group' : 'Create New Group'}
                </h2>
                <Button 
                  variant="outline" 
                  onClick={() => {
                    setShowCreateForm(false);
                    setShowEditModal(false);
                    setSelectedGroup(null);
                    setFormData({ name: '', description: '', color: '#3B82F6' });
                    setSelectedLeadIds([]);
                  }}
                >
                  Cancel
                </Button>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Left side - Group details */}
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium mb-2">Group Name</label>
                    <input
                      type="text"
                      required
                      className="w-full p-3 border border-gray-300 rounded-md"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      placeholder="e.g., Plumbers, Tech Companies"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-2">Description (optional)</label>
                    <textarea
                      className="w-full p-3 border border-gray-300 rounded-md h-24"
                      value={formData.description}
                      onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                      placeholder="Brief description of this group..."
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-2">Group Color</label>
                    <div className="flex gap-2 flex-wrap">
                      {PRESET_COLORS.map((color) => (
                        <button
                          key={color}
                          type="button"
                          className={`w-8 h-8 rounded-full border-2 ${
                            formData.color === color ? 'border-gray-800' : 'border-gray-300'
                          }`}
                          style={{ backgroundColor: color }}
                          onClick={() => setFormData({ ...formData, color })}
                        />
                      ))}
                    </div>
                    <input
                      type="color"
                      className="mt-2 w-16 h-8 border border-gray-300 rounded"
                      value={formData.color}
                      onChange={(e) => setFormData({ ...formData, color: e.target.value })}
                    />
                  </div>

                  <div className="pt-4">
                    <div className="flex items-center gap-3 mb-2">
                      <div 
                        className="w-4 h-4 rounded-full"
                        style={{ backgroundColor: formData.color }}
                      />
                      <span className="font-medium">Preview: {formData.name || 'Group Name'}</span>
                    </div>
                    <p className="text-sm text-gray-600">
                      {selectedLeadIds.length} lead{selectedLeadIds.length !== 1 ? 's' : ''} selected
                    </p>
                  </div>
                </div>

                {/* Right side - Lead selection */}
                <div>
                  <div className="flex justify-between items-center mb-4">
                    <label className="block text-sm font-medium">Select Leads</label>
                    <div className="space-x-2">
                      <Button 
                        type="button" 
                        size="sm" 
                        variant="outline"
                        onClick={() => setSelectedLeadIds(allLeads.map(l => l.id))}
                      >
                        Select All
                      </Button>
                      <Button 
                        type="button" 
                        size="sm" 
                        variant="outline"
                        onClick={() => setSelectedLeadIds([])}
                      >
                        Clear
                      </Button>
                    </div>
                  </div>

                  <div className="border border-gray-200 rounded-md max-h-96 overflow-y-auto">
                    {allLeads.map((lead) => (
                      <div key={lead.id} className="flex items-center p-3 border-b border-gray-100 last:border-b-0 hover:bg-gray-50">
                        <input
                          type="checkbox"
                          checked={selectedLeadIds.includes(lead.id)}
                          onChange={() => toggleLead(lead.id)}
                          className="mr-3"
                        />
                        <div className="flex-1">
                          <div className="font-medium">
                            {lead.first_name} {lead.last_name}
                          </div>
                          <div className="text-sm text-gray-600">{lead.email}</div>
                          {lead.company && (
                            <div className="text-sm text-gray-500">{lead.company}</div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>

                  {allLeads.length === 0 && (
                    <div className="text-center text-gray-500 py-8">
                      No leads available. Import some leads first.
                    </div>
                  )}
                </div>
              </div>

              <div className="flex justify-end gap-4 mt-8">
                <Button 
                  variant="outline" 
                  onClick={() => {
                    setShowCreateForm(false);
                    setShowEditModal(false);
                    setSelectedGroup(null);
                    setFormData({ name: '', description: '', color: '#3B82F6' });
                    setSelectedLeadIds([]);
                  }}
                >
                  Cancel
                </Button>
                <Button 
                  onClick={showEditModal ? handleUpdateGroup : handleCreateGroup}
                  disabled={!formData.name.trim()}
                >
                  {showEditModal ? 'Update Group' : 'Create Group'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default withAuth(GroupsPage);