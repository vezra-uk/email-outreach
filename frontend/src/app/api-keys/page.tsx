'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { Dialog } from '../../components/ui/dialog';
import { Plus, Copy, Trash2, ToggleLeft, ToggleRight, AlertTriangle } from 'lucide-react';
import { withAuth } from '../../contexts/AuthContext';
import { apiClient } from '@/utils/api';

interface APIKey {
  id: number;
  name: string;
  is_active: boolean;
  created_at: string;
  last_used_at?: string;
  key_preview: string;
  key?: string; // Full key only available when just created
}

interface NewAPIKey {
  name: string;
}

function APIKeys() {
  const [apiKeys, setApiKeys] = useState<APIKey[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [newKeyData, setNewKeyData] = useState<NewAPIKey>({ name: '' });
  const [justCreatedKey, setJustCreatedKey] = useState<APIKey | null>(null);
  const [showKeyDialog, setShowKeyDialog] = useState(false);

  useEffect(() => {
    fetchAPIKeys();
  }, []);

  const fetchAPIKeys = async () => {
    try {
      setLoading(true);
      const data = await apiClient.getJson<APIKey[]>('/api/auth/api-keys');
      setApiKeys(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch API keys');
      console.error('Error fetching API keys:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateAPIKey = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newKeyData.name.trim()) return;

    setIsSubmitting(true);
    try {
      const createdKey = await apiClient.postJson<APIKey>('/api/auth/api-keys', newKeyData);
      
      // Show the full key to the user (this is the only time they'll see it)
      setJustCreatedKey(createdKey);
      setShowKeyDialog(true);
      
      // Reset form and close
      setNewKeyData({ name: '' });
      setShowCreateForm(false);
      
      // Refresh the list
      await fetchAPIKeys();
      
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create API key');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteAPIKey = async (keyId: number, keyName: string) => {
    if (!confirm(`Are you sure you want to delete the API key "${keyName}"? This action cannot be undone.`)) {
      return;
    }

    try {
      await apiClient.delete(`/api/auth/api-keys/${keyId}`);
      await fetchAPIKeys();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete API key');
    }
  };

  const handleToggleAPIKey = async (keyId: number) => {
    try {
      await apiClient.put(`/api/auth/api-keys/${keyId}/toggle`, {});
      await fetchAPIKeys();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to toggle API key');
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text).then(() => {
      // Could add a toast notification here
      alert('API key copied to clipboard!');
    }).catch(() => {
      alert('Failed to copy to clipboard');
    });
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'Never';
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (loading) {
    return <div className="p-8">Loading API keys...</div>;
  }

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-4">API Key Management</h1>
        <p className="text-gray-600 mb-6">
          Create and manage API keys for external integrations. API keys allow external systems to create leads and access your campaigns.
        </p>
        
        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-md">
            <div className="flex">
              <AlertTriangle className="h-5 w-5 text-red-400 mr-2" />
              <span className="text-red-800">{error}</span>
            </div>
          </div>
        )}

        <div className="flex justify-between items-center mb-6">
          <div>
            <h2 className="text-lg font-semibold">Your API Keys ({apiKeys.length})</h2>
          </div>
          <Button onClick={() => setShowCreateForm(true)}>
            <Plus className="mr-2 h-4 w-4" />
            Create API Key
          </Button>
        </div>
      </div>

      {/* Create API Key Form */}
      {showCreateForm && (
        <Card className="mb-6">
          <CardHeader>
            <CardTitle>Create New API Key</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleCreateAPIKey} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">
                  API Key Name *
                </label>
                <input
                  type="text"
                  required
                  value={newKeyData.name}
                  onChange={(e) => setNewKeyData({ ...newKeyData, name: e.target.value })}
                  className="w-full p-2 border rounded"
                  placeholder="e.g., My Website Integration"
                  disabled={isSubmitting}
                />
                <p className="text-xs text-gray-500 mt-1">
                  Give your API key a descriptive name to identify its purpose.
                </p>
              </div>
              <div className="flex justify-end space-x-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setShowCreateForm(false);
                    setNewKeyData({ name: '' });
                  }}
                  disabled={isSubmitting}
                >
                  Cancel
                </Button>
                <Button type="submit" disabled={isSubmitting || !newKeyData.name.trim()}>
                  {isSubmitting ? 'Creating...' : 'Create API Key'}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* API Keys List */}
      <Card>
        <CardContent className="p-0">
          {apiKeys.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <div className="mb-4">
                <Plus className="mx-auto h-12 w-12 text-gray-400" />
              </div>
              <h3 className="text-lg font-medium mb-2">No API keys yet</h3>
              <p className="mb-4">Create your first API key to start integrating with external systems.</p>
              <Button onClick={() => setShowCreateForm(true)}>
                Create Your First API Key
              </Button>
            </div>
          ) : (
            <div className="divide-y divide-gray-200">
              {apiKeys.map((key) => (
                <div key={key.id} className="p-6">
                  <div className="flex items-center justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-3">
                        <h3 className="text-lg font-medium">{key.name}</h3>
                        <span
                          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                            key.is_active
                              ? 'bg-green-100 text-green-800'
                              : 'bg-gray-100 text-gray-800'
                          }`}
                        >
                          {key.is_active ? 'Active' : 'Inactive'}
                        </span>
                      </div>
                      <div className="mt-2 space-y-1">
                        <div className="flex items-center space-x-4 text-sm text-gray-500">
                          <span>Key: {key.key_preview}</span>
                          <span>Created: {formatDate(key.created_at)}</span>
                          <span>Last used: {formatDate(key.last_used_at)}</span>
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleToggleAPIKey(key.id)}
                        className="flex items-center"
                      >
                        {key.is_active ? (
                          <>
                            <ToggleRight className="h-4 w-4 mr-1" />
                            Disable
                          </>
                        ) : (
                          <>
                            <ToggleLeft className="h-4 w-4 mr-1" />
                            Enable
                          </>
                        )}
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleDeleteAPIKey(key.id, key.name)}
                        className="text-red-600 hover:text-red-900 hover:border-red-300"
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* New API Key Dialog */}
      <Dialog
        isOpen={showKeyDialog}
        onClose={() => {
          setShowKeyDialog(false);
          setJustCreatedKey(null);
        }}
        title="API Key Created Successfully"
      >
        {justCreatedKey && (
          <div className="space-y-4">
            <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-md">
              <div className="flex">
                <AlertTriangle className="h-5 w-5 text-yellow-400 mr-2" />
                <div>
                  <h4 className="text-sm font-medium text-yellow-800">Important!</h4>
                  <p className="text-sm text-yellow-700">
                    This is the only time you'll see the full API key. Copy it now and store it securely.
                  </p>
                </div>
              </div>
            </div>
            
            <div>
              <label className="block text-sm font-medium mb-2">Your New API Key:</label>
              <div className="flex items-center space-x-2">
                <input
                  type="text"
                  value={justCreatedKey.key || ''}
                  readOnly
                  className="flex-1 p-2 border rounded bg-gray-50 font-mono text-sm"
                />
                <Button
                  variant="outline"
                  onClick={() => copyToClipboard(justCreatedKey.key || '')}
                >
                  <Copy className="h-4 w-4" />
                </Button>
              </div>
            </div>

            <div className="space-y-2 text-sm text-gray-600">
              <p><strong>Usage Example:</strong></p>
              <pre className="bg-gray-100 p-2 rounded text-xs overflow-x-auto">
{`curl -X POST "https://your-domain.com/api/external/leads" \\
  -H "X-API-Key: ${justCreatedKey.key}" \\
  -H "Content-Type: application/json" \\
  -d '{"email": "lead@example.com", "campaign_id": 1}'`}
              </pre>
            </div>

            <div className="flex justify-end">
              <Button
                onClick={() => {
                  setShowKeyDialog(false);
                  setJustCreatedKey(null);
                }}
              >
                I've Saved My API Key
              </Button>
            </div>
          </div>
        )}
      </Dialog>

      {/* Documentation Section */}
      <Card className="mt-8">
        <CardHeader>
          <CardTitle>API Documentation</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4 text-sm">
            <div>
              <h4 className="font-medium mb-2">External API Endpoints:</h4>
              <ul className="space-y-1 text-gray-600">
                <li><code className="bg-gray-100 px-2 py-1 rounded">POST /api/external/leads</code> - Create a single lead</li>
                <li><code className="bg-gray-100 px-2 py-1 rounded">POST /api/external/leads/bulk</code> - Create multiple leads</li>
                <li><code className="bg-gray-100 px-2 py-1 rounded">GET /api/external/campaigns</code> - List available campaigns</li>
                <li><code className="bg-gray-100 px-2 py-1 rounded">GET /api/external/status</code> - Check API status</li>
              </ul>
            </div>
            <div>
              <h4 className="font-medium mb-2">Authentication:</h4>
              <p className="text-gray-600">
                Include your API key in the <code className="bg-gray-100 px-1 rounded">X-API-Key</code> header with all requests.
              </p>
            </div>
            <div>
              <p>
                <a 
                  href="/EXTERNAL_API_README.md" 
                  className="text-blue-600 hover:text-blue-800 underline"
                  target="_blank" 
                  rel="noopener noreferrer"
                >
                  View complete API documentation →
                </a>
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default withAuth(APIKeys);