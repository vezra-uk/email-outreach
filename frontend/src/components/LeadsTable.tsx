'use client';

import { Edit, Trash2 } from 'lucide-react';
import { Button } from './ui/button';
import { Lead } from '@/types';

interface LeadsTableProps {
  leads: Lead[];
  onEdit: (lead: Lead) => void;
  onDelete: (leadId: number, leadEmail: string) => void;
}

export default function LeadsTable({ leads, onEdit, onDelete }: LeadsTableProps) {
  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString();
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse border border-gray-200">
        <thead>
          <tr className="bg-gray-50">
            <th className="border border-gray-200 px-4 py-2 text-left">Name</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Email</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Company</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Title</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Phone</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Website</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Industry</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Status</th>
            <th className="border border-gray-200 px-4 py-2 text-left">Created</th>
            <th className="border border-gray-200 px-4 py-2 text-center">Actions</th>
          </tr>
        </thead>
        <tbody>
          {leads.map((lead) => (
            <tr key={lead.id} className="hover:bg-gray-50">
              <td className="border border-gray-200 px-4 py-2">
                {[lead.first_name, lead.last_name].filter(Boolean).join(' ') || '-'}
              </td>
              <td className="border border-gray-200 px-4 py-2">{lead.email}</td>
              <td className="border border-gray-200 px-4 py-2">{lead.company || '-'}</td>
              <td className="border border-gray-200 px-4 py-2">{lead.title || '-'}</td>
              <td className="border border-gray-200 px-4 py-2">{lead.phone || '-'}</td>
              <td className="border border-gray-200 px-4 py-2">
                {lead.website ? (
                  <a
                    href={lead.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-600 hover:text-blue-800 underline"
                  >
                    {lead.website.replace(/https?:\/\//, '')}
                  </a>
                ) : '-'}
              </td>
              <td className="border border-gray-200 px-4 py-2">{lead.industry || '-'}</td>
              <td className="border border-gray-200 px-4 py-2">
                <span className={`px-2 py-1 rounded-full text-xs ${
                  lead.status === 'active' 
                    ? 'bg-green-100 text-green-800' 
                    : 'bg-gray-100 text-gray-800'
                }`}>
                  {lead.status}
                </span>
              </td>
              <td className="border border-gray-200 px-4 py-2">
                {formatDate(lead.created_at)}
              </td>
              <td className="border border-gray-200 px-4 py-2 text-center">
                <div className="flex justify-center space-x-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => onEdit(lead)}
                    className="p-2"
                  >
                    <Edit className="h-4 w-4" />
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => onDelete(lead.id, lead.email)}
                    className="p-2 text-red-600 hover:text-red-800"
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {leads.length === 0 && (
        <div className="text-center py-8 text-gray-500">
          No leads found. Add some leads to get started.
        </div>
      )}
    </div>
  );
}