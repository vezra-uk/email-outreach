import { useState, useEffect } from 'react';
import { Lead } from '@/types';
import { apiClient } from '@/utils/api';

export function useLeads() {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchLeads = async () => {
    try {
      setLoading(true);
      const data = await apiClient.getJson<Lead[]>('/api/leads/');
      setLeads(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const createLead = async (leadData: Omit<Lead, 'id' | 'status' | 'created_at'>) => {
    try {
      const newLead = await apiClient.postJson<Lead>('/api/leads/', leadData);
      setLeads(prev => [...prev, newLead]);
      return newLead;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to create lead');
    }
  };

  const updateLead = async (id: number, updates: Partial<Lead>) => {
    try {
      const updatedLead = await apiClient.putJson<Lead>(`/api/leads/${id}/`, updates);
      setLeads(prev => prev.map(lead => lead.id === id ? updatedLead : lead));
      return updatedLead;
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update lead');
    }
  };

  const deleteLead = async (id: number) => {
    try {
      await apiClient.delete(`/api/leads/${id}/`);
      setLeads(prev => prev.filter(lead => lead.id !== id));
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to delete lead');
    }
  };

  useEffect(() => {
    fetchLeads();
  }, []);

  return {
    leads,
    loading,
    error,
    refetch: fetchLeads,
    createLead,
    updateLead,
    deleteLead
  };
}