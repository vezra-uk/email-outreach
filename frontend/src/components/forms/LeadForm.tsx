'use client';

import { useState } from 'react';
import { Button } from '../ui/button';
import { Lead, NewLead } from '@/types';

interface LeadFormProps {
  lead?: Lead | null;
  onSubmit: (leadData: NewLead) => Promise<void>;
  onCancel: () => void;
  isLoading?: boolean;
}

const commonIndustries = [
  'Technology', 'Software', 'SaaS', 'E-commerce', 'Marketing', 'Advertising',
  'Finance', 'Banking', 'Insurance', 'Healthcare', 'Education', 'Manufacturing',
  'Real Estate', 'Construction', 'Consulting', 'Legal', 'Non-profit', 'Retail',
  'Hospitality', 'Transportation', 'Energy', 'Media', 'Entertainment', 'Other'
];

export default function LeadForm({ lead, onSubmit, onCancel, isLoading }: LeadFormProps) {
  const [formData, setFormData] = useState<NewLead>({
    email: lead?.email || '',
    first_name: lead?.first_name || '',
    last_name: lead?.last_name || '',
    company: lead?.company || '',
    title: lead?.title || '',
    phone: lead?.phone || '',
    website: lead?.website || '',
    industry: lead?.industry || ''
  });

  const [customIndustry, setCustomIndustry] = useState('');
  const [showCustomIndustry, setShowCustomIndustry] = useState(
    lead?.industry && !commonIndustries.includes(lead.industry)
  );

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Clean up website URL
    let website = formData.website.trim();
    if (website && !website.startsWith('http') && !website.startsWith('www.')) {
      website = 'https://' + website;
    }

    // Use custom industry if "Other" is selected and custom industry is provided
    const industry = showCustomIndustry && customIndustry.trim() 
      ? customIndustry.trim() 
      : formData.industry;

    const leadData = { ...formData, website, industry };
    await onSubmit(leadData);
  };

  const handleIndustryChange = (value: string) => {
    setFormData({ ...formData, industry: value });
    setShowCustomIndustry(value === 'Other');
    if (value !== 'Other') {
      setCustomIndustry('');
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium mb-1">Email *</label>
          <input
            type="email"
            required
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            className="w-full p-2 border rounded"
            disabled={isLoading}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Phone</label>
          <input
            type="text"
            value={formData.phone}
            onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
            className="w-full p-2 border rounded"
            disabled={isLoading}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">First Name</label>
          <input
            type="text"
            value={formData.first_name}
            onChange={(e) => setFormData({ ...formData, first_name: e.target.value })}
            className="w-full p-2 border rounded"
            disabled={isLoading}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Last Name</label>
          <input
            type="text"
            value={formData.last_name}
            onChange={(e) => setFormData({ ...formData, last_name: e.target.value })}
            className="w-full p-2 border rounded"
            disabled={isLoading}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Company</label>
          <input
            type="text"
            value={formData.company}
            onChange={(e) => setFormData({ ...formData, company: e.target.value })}
            className="w-full p-2 border rounded"
            disabled={isLoading}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Title</label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            className="w-full p-2 border rounded"
            disabled={isLoading}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Website</label>
          <input
            type="text"
            value={formData.website}
            onChange={(e) => setFormData({ ...formData, website: e.target.value })}
            className="w-full p-2 border rounded"
            placeholder="example.com"
            disabled={isLoading}
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Industry</label>
          <select
            value={formData.industry}
            onChange={(e) => handleIndustryChange(e.target.value)}
            className="w-full p-2 border rounded"
            disabled={isLoading}
          >
            <option value="">Select Industry</option>
            {commonIndustries.map(industry => (
              <option key={industry} value={industry}>{industry}</option>
            ))}
          </select>
        </div>
      </div>

      {showCustomIndustry && (
        <div>
          <label className="block text-sm font-medium mb-1">Custom Industry</label>
          <input
            type="text"
            value={customIndustry}
            onChange={(e) => setCustomIndustry(e.target.value)}
            className="w-full p-2 border rounded"
            placeholder="Enter custom industry"
            disabled={isLoading}
          />
        </div>
      )}

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
          {isLoading ? 'Saving...' : lead ? 'Update Lead' : 'Add Lead'}
        </Button>
      </div>
    </form>
  );
}