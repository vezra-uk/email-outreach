'use client';

import { useState, useEffect } from 'react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { withAuth } from '../../contexts/AuthContext';
import { apiClient } from '@/utils/api';

interface DeliverabilityAlert {
  id: number;
  alert_type: string;
  severity: string;
  title: string;
  description: string;
  domain: string;
  is_resolved: boolean;
  created_at: string;
  resolved_at?: string;
}

interface DeliverabilityMetrics {
  health_score: number;
  blacklist_issues: number;
  dns_issues: number;
  open_alerts: number;
  status: 'good' | 'warning' | 'critical' | 'unknown';
}

interface HealthScoreData {
  overall_score: number;
  status: string;
  breakdown: {
    blacklist_health: {
      score: number;
      listed_count: number;
      total_checked: number;
    };
    dns_health: {
      score: number;
      valid_records: number;
      total_records: number;
    };
    alert_health: {
      open_alerts: number;
      score: number;
    };
  };
  last_updated: string;
}

function DeliverabilityPage() {
  const [loading, setLoading] = useState(true);
  const [summary, setSummary] = useState<DeliverabilityMetrics | null>(null);
  const [healthScore, setHealthScore] = useState<HealthScoreData | null>(null);
  const [alerts, setAlerts] = useState<DeliverabilityAlert[]>([]);
  const [blacklistStatus, setBlacklistStatus] = useState<any>({});
  const [dnsAuthStatus, setDnsAuthStatus] = useState<any>({});
  const [runningCheck, setRunningCheck] = useState(false);

  useEffect(() => {
    fetchDeliverabilityData();
  }, []);

  const fetchDeliverabilityData = async () => {
    try {
      setLoading(true);
      
      // Fetch all deliverability data in parallel
      const [summaryData, healthData, alertsData, blacklistData, dnsData] = await Promise.all([
        apiClient.getJson<DeliverabilityMetrics>('/api/deliverability/summary'),
        apiClient.getJson<HealthScoreData>('/api/deliverability/health-score'),
        apiClient.getJson<DeliverabilityAlert[]>('/api/deliverability/alerts'),
        apiClient.getJson<any>('/api/deliverability/blacklist-status'),
        apiClient.getJson<any>('/api/deliverability/dns-auth')
      ]);

      setSummary(summaryData);
      setHealthScore(healthData);
      setAlerts(alertsData);
      setBlacklistStatus(blacklistData);
      setDnsAuthStatus(dnsData);
    } catch (error) {
      console.error('Error fetching deliverability data:', error);
    } finally {
      setLoading(false);
    }
  };

  const runDeliverabilityCheck = async () => {
    try {
      setRunningCheck(true);
      const result = await apiClient.postJson('/api/deliverability/check/run', {});
      console.log('Deliverability check completed:', result);
      
      // Refresh data after check
      setTimeout(() => {
        fetchDeliverabilityData();
      }, 2000);
    } catch (error) {
      console.error('Error running deliverability check:', error);
    } finally {
      setRunningCheck(false);
    }
  };

  const resolveAlert = async (alertId: number) => {
    try {
      await apiClient.postJson(`/api/deliverability/alerts/${alertId}/resolve`, {});
      // Refresh alerts
      const updatedAlerts = await apiClient.getJson<DeliverabilityAlert[]>('/api/deliverability/alerts');
      setAlerts(updatedAlerts);
    } catch (error) {
      console.error('Error resolving alert:', error);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'good': return 'text-green-600';
      case 'warning': return 'text-yellow-600';
      case 'critical': return 'text-red-600';
      default: return 'text-gray-600';
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'low': return 'bg-blue-100 text-blue-800';
      case 'medium': return 'bg-yellow-100 text-yellow-800';
      case 'high': return 'bg-orange-100 text-orange-800';
      case 'critical': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Email Deliverability</h1>
        <Button 
          onClick={runDeliverabilityCheck} 
          disabled={runningCheck}
          className="bg-blue-600 hover:bg-blue-700"
        >
          {runningCheck ? 'Running Check...' : 'Run Check Now'}
        </Button>
      </div>

      {/* Health Score Overview */}
      {healthScore && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
          <Card className="p-6">
            <div className="text-center">
              <div className={`text-3xl font-bold ${getStatusColor(healthScore.status)}`}>
                {Math.round(healthScore.overall_score)}%
              </div>
              <div className="text-sm text-gray-600 mt-1">Overall Health</div>
              <div className={`text-xs mt-2 font-medium ${getStatusColor(healthScore.status)}`}>
                {healthScore.status.toUpperCase()}
              </div>
            </div>
          </Card>

          <Card className="p-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">
                {healthScore.breakdown.blacklist_health.score.toFixed(0)}%
              </div>
              <div className="text-sm text-gray-600 mt-1">Blacklist Health</div>
              <div className="text-xs text-gray-500 mt-2">
                {healthScore.breakdown.blacklist_health.listed_count} / {healthScore.breakdown.blacklist_health.total_checked} listed
              </div>
            </div>
          </Card>

          <Card className="p-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">
                {healthScore.breakdown.dns_health.score.toFixed(0)}%
              </div>
              <div className="text-sm text-gray-600 mt-1">DNS Auth Health</div>
              <div className="text-xs text-gray-500 mt-2">
                {healthScore.breakdown.dns_health.valid_records} / {healthScore.breakdown.dns_health.total_records} valid
              </div>
            </div>
          </Card>

          <Card className="p-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-900">
                {healthScore.breakdown.alert_health.open_alerts}
              </div>
              <div className="text-sm text-gray-600 mt-1">Open Alerts</div>
              <div className="text-xs text-gray-500 mt-2">
                Score: {healthScore.breakdown.alert_health.score}%
              </div>
            </div>
          </Card>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Active Alerts */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">Active Alerts</h2>
          {alerts.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <div className="text-green-600 text-4xl mb-2">✓</div>
              <div>No active deliverability alerts</div>
            </div>
          ) : (
            <div className="space-y-3">
              {alerts.slice(0, 5).map((alert) => (
                <div key={alert.id} className="border rounded-lg p-4">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <span className={`px-2 py-1 rounded text-xs font-medium ${getSeverityColor(alert.severity)}`}>
                          {alert.severity.toUpperCase()}
                        </span>
                        <span className="text-sm text-gray-500">{alert.alert_type}</span>
                      </div>
                      <div className="font-medium text-gray-900 mb-1">{alert.title}</div>
                      <div className="text-sm text-gray-600">{alert.description}</div>
                      <div className="text-xs text-gray-400 mt-2">
                        {new Date(alert.created_at).toLocaleString()}
                      </div>
                    </div>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => resolveAlert(alert.id)}
                      className="ml-4"
                    >
                      Resolve
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>

        {/* Blacklist Status */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">Blacklist Status</h2>
          {Object.keys(blacklistStatus).length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <div className="text-green-600 text-4xl mb-2">✓</div>
              <div>No blacklist issues detected</div>
            </div>
          ) : (
            <div className="space-y-3">
              {Object.entries(blacklistStatus).map(([provider, statuses]: [string, any]) => (
                <div key={provider} className="border rounded-lg p-4">
                  <div className="font-medium text-gray-900 mb-2">{provider}</div>
                  {Array.isArray(statuses) && statuses.map((status: any, index: number) => (
                    <div key={index} className="text-sm text-gray-600 ml-4">
                      <div className="flex justify-between items-center">
                        <span>{status.domain || status.ip_address}</span>
                        <span className={`px-2 py-1 rounded text-xs ${
                          status.is_listed ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'
                        }`}>
                          {status.is_listed ? 'Listed' : 'Clean'}
                        </span>
                      </div>
                      {status.last_checked && (
                        <div className="text-xs text-gray-400">
                          Last checked: {new Date(status.last_checked).toLocaleString()}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              ))}
            </div>
          )}
        </Card>

        {/* DNS Authentication Status */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">DNS Authentication</h2>
          {Object.keys(dnsAuthStatus).length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <div className="text-yellow-600 text-4xl mb-2">⚠</div>
              <div>DNS authentication records not checked yet</div>
            </div>
          ) : (
            <div className="space-y-4">
              {Object.entries(dnsAuthStatus).map(([domain, records]: [string, any]) => (
                <div key={domain} className="border rounded-lg p-4">
                  <div className="font-medium text-gray-900 mb-3">{domain}</div>
                  {Object.entries(records).map(([recordType, record]: [string, any]) => (
                    <div key={recordType} className="mb-3 ml-4">
                      <div className="flex justify-between items-center mb-1">
                        <span className="font-medium text-sm">{recordType}</span>
                        <span className={`px-2 py-1 rounded text-xs ${
                          record.is_valid ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                        }`}>
                          {record.is_valid ? 'Valid' : 'Invalid'}
                        </span>
                      </div>
                      {record.record_value && (
                        <div className="text-xs text-gray-600 mb-1 break-all">
                          {record.record_value}
                        </div>
                      )}
                      {record.validation_errors && (
                        <div className="text-xs text-red-600">
                          {record.validation_errors}
                        </div>
                      )}
                      {record.last_checked && (
                        <div className="text-xs text-gray-400">
                          Last checked: {new Date(record.last_checked).toLocaleString()}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              ))}
            </div>
          )}
        </Card>

        {/* Quick Stats */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">Quick Stats</h2>
          {summary ? (
            <div className="space-y-4">
              <div className="flex justify-between items-center p-3 bg-gray-50 rounded">
                <span className="font-medium">Health Score</span>
                <span className={`font-bold ${getStatusColor(summary.status)}`}>
                  {Math.round(summary.health_score)}%
                </span>
              </div>
              <div className="flex justify-between items-center p-3 bg-gray-50 rounded">
                <span className="font-medium">Blacklist Issues</span>
                <span className={`font-bold ${summary.blacklist_issues > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {summary.blacklist_issues}
                </span>
              </div>
              <div className="flex justify-between items-center p-3 bg-gray-50 rounded">
                <span className="font-medium">DNS Issues</span>
                <span className={`font-bold ${summary.dns_issues > 0 ? 'text-red-600' : 'text-green-600'}`}>
                  {summary.dns_issues}
                </span>
              </div>
              <div className="flex justify-between items-center p-3 bg-gray-50 rounded">
                <span className="font-medium">Open Alerts</span>
                <span className={`font-bold ${summary.open_alerts > 0 ? 'text-orange-600' : 'text-green-600'}`}>
                  {summary.open_alerts}
                </span>
              </div>
            </div>
          ) : (
            <div className="text-center py-8 text-gray-500">
              <div>Loading stats...</div>
            </div>
          )}
        </Card>
      </div>

      {/* Information Section */}
      <Card className="p-6 mt-6">
        <h2 className="text-xl font-semibold mb-4">About Email Deliverability Monitoring</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-sm text-gray-600">
          <div>
            <h3 className="font-medium text-gray-900 mb-2">Blacklist Monitoring</h3>
            <p>We check your domain and sending IP against major email blacklists including Spamhaus, SURBL, and others. Being blacklisted can severely impact your email deliverability.</p>
          </div>
          <div>
            <h3 className="font-medium text-gray-900 mb-2">DNS Authentication</h3>
            <p>We validate your SPF, DKIM, and DMARC records to ensure proper email authentication. These records help mailbox providers verify that your emails are legitimate.</p>
          </div>
          <div>
            <h3 className="font-medium text-gray-900 mb-2">Health Score</h3>
            <p>Your overall deliverability health score is calculated based on blacklist status, DNS authentication validity, and active alerts. Higher scores indicate better deliverability.</p>
          </div>
        </div>
      </Card>
    </div>
  );
}

export default withAuth(DeliverabilityPage);