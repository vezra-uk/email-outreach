'use client';

import { useState } from 'react';
import { Button } from '../ui/button';

interface BulkLeadImportFormProps {
  onSubmit: (leads: any[]) => Promise<void>;
  onCancel: () => void;
  isLoading?: boolean;
}

export default function BulkLeadImportForm({ onSubmit, onCancel, isLoading }: BulkLeadImportFormProps) {
  const [bulkLeads, setBulkLeads] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      // Parse CSV-like data
      const lines = bulkLeads.trim().split('\n');
      const leads = lines.map(line => {
        const [email, first_name, last_name, company, title, phone, website, industry] = line.split(',').map(s => s.trim());
        return {
          email: email || '',
          first_name: first_name || '',
          last_name: last_name || '',
          company: company || '',
          title: title || '',
          phone: phone || '',
          website: website || '',
          industry: industry || ''
        };
      }).filter(lead => lead.email); // Only include leads with email

      await onSubmit(leads);
    } catch (error) {
      console.error('Failed to parse bulk leads:', error);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium mb-2">
          Paste CSV Data (Email, First Name, Last Name, Company, Title, Phone, Website, Industry)
        </label>
        <textarea
          value={bulkLeads}
          onChange={(e) => setBulkLeads(e.target.value)}
          className="w-full p-3 border rounded h-32"
          placeholder="john@example.com,John,Doe,Acme Corp,CEO,555-0123,acme.com,Technology&#10;jane@example.com,Jane,Smith,Beta Inc,CTO,555-0124,beta.com,Software"
          required
          disabled={isLoading}
        />
        <p className="text-xs text-gray-500 mt-1">
          Each line should contain comma-separated values. Email is required for each lead.
        </p>
      </div>

      <div className="flex justify-end space-x-2 pt-4">
        <Button
          type="button"
          variant="outline"
          onClick={onCancel}
          disabled={isLoading}
        >
          Cancel
        </Button>
        <Button type="submit" disabled={isLoading}>
          {isLoading ? 'Importing...' : 'Import Leads'}
        </Button>
      </div>
    </form>
  );
}