import { useState, useEffect } from 'react';
import { LeadGroup } from '@/types';
import { apiClient } from '@/utils/api';

export function useLeadGroups() {
  const [groups, setGroups] = useState<LeadGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchGroups = async () => {
    try {
      setLoading(true);
      const data = await apiClient.getJson<LeadGroup[]>('/api/groups/');
      setGroups(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const createGroup = async (groupData: Omit<LeadGroup, 'id' | 'lead_count'>) => {
    try {
      const newGroup = await apiClient.postJson<LeadGroup>('/api/groups/', groupData);
      setGroups(prev => [...prev, newGroup]);
      return newGroup;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create group');
    }
  };

  const updateGroup = async (id: number, updates: Partial<LeadGroup>) => {
    try {
      const updatedGroup = await apiClient.putJson<LeadGroup>(`/api/groups/${id}/`, updates);
      setGroups(prev => prev.map(group => group.id === id ? updatedGroup : group));
      return updatedGroup;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update group');
    }
  };

  const deleteGroup = async (id: number) => {
    try {
      await apiClient.delete(`/api/groups/${id}/`);
      setGroups(prev => prev.filter(group => group.id !== id));
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete group');
    }
  };

  useEffect(() => {
    fetchGroups();
  }, []);

  return {
    groups,
    loading,
    error,
    refetch: fetchGroups,
    createGroup,
    updateGroup,
    deleteGroup
  };
}