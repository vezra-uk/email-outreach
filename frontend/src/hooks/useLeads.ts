import { useState, useEffect } from 'react';
import { Lead, PaginatedResponse } from '@/types';
import { apiClient } from '@/utils/api';
import { usePagination } from './usePagination';

interface UseLeadsOptions {
  paginated?: boolean;
  industry?: string;
  company?: string;
}

export function useLeads(options: UseLeadsOptions = {}) {
  const { paginated = false, industry, company } = options;
  const [leads, setLeads] = useState<Lead[]>([]);
  const [paginatedData, setPaginatedData] = useState<PaginatedResponse<Lead> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  const { pagination, goToPage, getQueryParams } = usePagination({ initialPerPage: 20 });

  const fetchLeads = async () => {
    try {
      setLoading(true);
      setError(null);
      
      if (paginated) {
        const queryParams = getQueryParams();
        if (industry) queryParams.set('industry', industry);
        if (company) queryParams.set('company', company);
        
        const data = await apiClient.getJson<PaginatedResponse<Lead>>(
          `/api/leads/paginated?${queryParams}`
        );
        setPaginatedData(data);
        setLeads(data.items);
      } else {
        const data = await apiClient.getJson<Lead[]>('/api/leads/');
        setLeads(data);
        setPaginatedData(null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      setLeads([]);
      setPaginatedData(null);
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
  }, [paginated, pagination.page, pagination.per_page, industry, company]);

  return {
    leads,
    paginatedData,
    pagination,
    goToPage,
    loading,
    error,
    refetch: fetchLeads,
    createLead,
    updateLead,
    deleteLead
  };
}