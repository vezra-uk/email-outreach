'use client'
import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { Upload, Download, FileText, CheckCircle, AlertCircle, X, Plus } from 'lucide-react'
import { apiClient } from '@/utils/api'
import { LeadGroup } from '@/types'

interface CSVUploadProps {
  onUploadComplete: () => void
  onClose: () => void
}

interface CSVPreview {
  headers: string[]
  sample_data: string[][]
  total_rows: number
  detected_columns: Record<string, string>
}

interface UploadResult {
  created: number
  errors: string[]
  skipped: number
  total_processed: number
}

const LEAD_FIELDS = [
  { value: '', label: 'Do not import' },
  { value: 'email', label: 'Email *', required: true },
  { value: 'first_name', label: 'First Name' },
  { value: 'last_name', label: 'Last Name' },
  { value: 'company', label: 'Company' },
  { value: 'title', label: 'Title/Position' },
  { value: 'phone', label: 'Phone' },
  { value: 'website', label: 'Website' },
  { value: 'industry', label: 'Industry' }
]

export default function CSVUpload({ onUploadComplete, onClose }: CSVUploadProps) {
  const [csvFile, setCsvFile] = useState<File | null>(null)
  const [csvContent, setCsvContent] = useState('')
  const [hasHeader, setHasHeader] = useState(true)
  const [preview, setPreview] = useState<CSVPreview | null>(null)
  const [columnMapping, setColumnMapping] = useState<Record<string, string>>({})
  const [isProcessing, setIsProcessing] = useState(false)
  const [uploadResult, setUploadResult] = useState<UploadResult | null>(null)
  const [step, setStep] = useState<'upload' | 'mapping' | 'result'>('upload')
  
  // Group selection state
  const [groups, setGroups] = useState<LeadGroup[]>([])
  const [selectedGroupId, setSelectedGroupId] = useState<number | null>(null)
  const [newGroupName, setNewGroupName] = useState('')
  const [groupSelection, setGroupSelection] = useState<'none' | 'existing' | 'new'>('none')

  // Fetch groups on component mount
  useEffect(() => {
    const fetchGroups = async () => {
      try {
        const groupData = await apiClient.getJson<LeadGroup[]>('/api/groups/')
        setGroups(groupData)
      } catch (error) {
        console.error('Failed to fetch groups:', error)
      }
    }
    fetchGroups()
  }, [])

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    if (!file.name.toLowerCase().endsWith('.csv')) {
      alert('Please select a CSV file')
      return
    }

    setCsvFile(file)
    
    // Read file content
    const reader = new FileReader()
    reader.onload = async (e) => {
      const content = e.target?.result as string
      setCsvContent(content)
      
      // Preview the CSV
      try {
        const previewData = await apiClient.postJson<CSVPreview>('/api/leads/csv/preview', {
          csv_content: content,
          has_header: hasHeader
        })
        setPreview(previewData)
        setColumnMapping(previewData.detected_columns)
        setStep('mapping')
      } catch (error) {
        alert('Failed to preview CSV file')
        console.error(error)
      }
    }
    reader.readAsText(file)
  }

  const handleMappingChange = (csvColumn: string, dbField: string) => {
    setColumnMapping(prev => ({
      ...prev,
      [csvColumn]: dbField
    }))
  }

  const validateMapping = () => {
    // Check if email is mapped
    const hasEmail = Object.values(columnMapping).includes('email')
    if (!hasEmail) {
      alert('Email field mapping is required')
      return false
    }
    return true
  }

  const handleUpload = async () => {
    if (!validateMapping()) return

    setIsProcessing(true)
    try {
      const uploadData: any = {
        csv_content: csvContent,
        column_mapping: columnMapping,
        has_header: hasHeader
      }

      // Add group data based on selection
      if (groupSelection === 'existing' && selectedGroupId) {
        uploadData.group_id = selectedGroupId
      } else if (groupSelection === 'new' && newGroupName.trim()) {
        uploadData.new_group_name = newGroupName.trim()
      }

      const result = await apiClient.postJson<UploadResult>('/api/leads/csv/upload', uploadData)
      setUploadResult(result)
      setStep('result')
      if (result.created > 0) {
        onUploadComplete()
      }
    } catch (error) {
      alert('Failed to upload CSV')
      console.error(error)
    } finally {
      setIsProcessing(false)
    }
  }

  const downloadSampleCSV = () => {
    const sampleData = [
      ['email', 'first_name', 'last_name', 'company', 'title', 'phone', 'website', 'industry'],
      ['john@example.com', 'John', 'Doe', 'Acme Corp', 'CEO', '555-1234', 'acme.com', 'Technology'],
      ['jane@beta.com', 'Jane', 'Smith', 'Beta Inc', 'CTO', '555-5678', 'beta.com', 'Software'],
      ['mike@gamma.org', 'Mike', 'Johnson', 'Gamma LLC', 'Manager', '555-9012', 'gamma.org', 'Consulting']
    ]
    
    const csvContent = sampleData.map(row => row.join(',')).join('\n')
    const blob = new Blob([csvContent], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'sample_leads.csv'
    a.click()
    URL.revokeObjectURL(url)
  }

  const resetUpload = () => {
    setCsvFile(null)
    setCsvContent('')
    setPreview(null)
    setColumnMapping({})
    setUploadResult(null)
    setStep('upload')
    setSelectedGroupId(null)
    setNewGroupName('')
    setGroupSelection('none')
  }

  return (
    <Card className="w-full max-w-4xl mx-auto">
      <CardHeader>
        <div className="flex justify-between items-center">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Upload className="h-5 w-5" />
              CSV Lead Import
            </CardTitle>
            <p className="text-sm text-gray-600 mt-1">
              Import leads from a CSV file with custom column mapping
            </p>
          </div>
          <Button variant="outline" size="sm" onClick={onClose}>
            <X className="h-4 w-4" />
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {step === 'upload' && (
          <div className="space-y-6">
            {/* Upload Section */}
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
              <FileText className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <div className="space-y-2">
                <h3 className="text-lg font-medium">Upload CSV File</h3>
                <p className="text-gray-600">
                  Select a CSV file containing your leads data
                </p>
                <div className="pt-4">
                  <input
                    type="file"
                    accept=".csv"
                    onChange={handleFileUpload}
                    className="hidden"
                    id="csv-upload"
                    ref={(input) => {
                      if (input) {
                        (window as any).csvFileInput = input;
                      }
                    }}
                  />
                  <Button 
                    onClick={() => {
                      const input = document.getElementById('csv-upload') as HTMLInputElement;
                      if (input) input.click();
                    }}
                    className="cursor-pointer"
                  >
                    <Upload className="mr-2 h-4 w-4" />
                    Choose CSV File
                  </Button>
                </div>
              </div>
            </div>

            {/* Options */}
            <div className="flex items-center space-x-4">
              <label className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  checked={hasHeader}
                  onChange={(e) => setHasHeader(e.target.checked)}
                  className="rounded"
                />
                <span className="text-sm">First row contains column headers</span>
              </label>
            </div>

            {/* Sample Download */}
            <div className="bg-blue-50 p-4 rounded-lg">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="font-medium text-blue-900">Need a sample file?</h4>
                  <p className="text-blue-700 text-sm">
                    Download our sample CSV to see the expected format
                  </p>
                </div>
                <Button variant="outline" size="sm" onClick={downloadSampleCSV}>
                  <Download className="mr-2 h-4 w-4" />
                  Sample CSV
                </Button>
              </div>
            </div>
          </div>
        )}

        {step === 'mapping' && preview && (
          <div className="space-y-6">
            {/* Preview Info */}
            <div className="bg-gray-50 p-4 rounded-lg">
              <h3 className="font-medium mb-2">File Preview</h3>
              <div className="grid grid-cols-3 gap-4 text-sm">
                <div>
                  <span className="text-gray-600">File:</span> {csvFile?.name}
                </div>
                <div>
                  <span className="text-gray-600">Columns:</span> {preview.headers.length}
                </div>
                <div>
                  <span className="text-gray-600">Rows:</span> {preview.total_rows}
                </div>
              </div>
            </div>

            {/* Column Mapping */}
            <div>
              <h3 className="font-medium mb-4">Map CSV Columns to Lead Fields</h3>
              <div className="space-y-3">
                {preview.headers.map((header, index) => (
                  <div key={index} className="flex items-center gap-4 p-3 border rounded-lg">
                    <div className="flex-1">
                      <div className="font-medium">{header}</div>
                      <div className="text-sm text-gray-600">
                        Sample: {preview.sample_data[0]?.[index] || 'No data'}
                      </div>
                    </div>
                    <div className="flex-1">
                      <select
                        value={columnMapping[header] || ''}
                        onChange={(e) => handleMappingChange(header, e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      >
                        {LEAD_FIELDS.map((field) => (
                          <option key={field.value} value={field.value}>
                            {field.label}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Group Assignment */}
            <div>
              <h3 className="font-medium mb-4">Assign to Group (Optional)</h3>
              <div className="space-y-4">
                <div className="flex gap-4">
                  <label className="flex items-center space-x-2 cursor-pointer">
                    <input
                      type="radio"
                      name="groupSelection"
                      value="none"
                      checked={groupSelection === 'none'}
                      onChange={() => setGroupSelection('none')}
                      className="text-blue-600"
                    />
                    <span>No group assignment</span>
                  </label>
                  
                  <label className="flex items-center space-x-2 cursor-pointer">
                    <input
                      type="radio"
                      name="groupSelection"
                      value="existing"
                      checked={groupSelection === 'existing'}
                      onChange={() => setGroupSelection('existing')}
                      className="text-blue-600"
                    />
                    <span>Assign to existing group</span>
                  </label>
                  
                  <label className="flex items-center space-x-2 cursor-pointer">
                    <input
                      type="radio"
                      name="groupSelection"
                      value="new"
                      checked={groupSelection === 'new'}
                      onChange={() => setGroupSelection('new')}
                      className="text-blue-600"
                    />
                    <span>Create new group</span>
                  </label>
                </div>

                {groupSelection === 'existing' && (
                  <div>
                    <select
                      value={selectedGroupId || ''}
                      onChange={(e) => setSelectedGroupId(e.target.value ? parseInt(e.target.value) : null)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="">Select a group</option>
                      {groups.map((group) => (
                        <option key={group.id} value={group.id}>
                          {group.name} ({group.lead_count} leads)
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                {groupSelection === 'new' && (
                  <div>
                    <input
                      type="text"
                      value={newGroupName}
                      onChange={(e) => setNewGroupName(e.target.value)}
                      placeholder="Enter new group name"
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                )}
              </div>
            </div>

            {/* Sample Data Preview */}
            <div>
              <h3 className="font-medium mb-2">Sample Data Preview</h3>
              <div className="overflow-x-auto">
                <table className="w-full text-sm border border-gray-300">
                  <thead>
                    <tr className="bg-gray-50">
                      {preview.headers.map((header, index) => (
                        <th key={index} className="px-3 py-2 text-left border-b">
                          {header}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {preview.sample_data.slice(0, 3).map((row, rowIndex) => (
                      <tr key={rowIndex}>
                        {row.map((cell, cellIndex) => (
                          <td key={cellIndex} className="px-3 py-2 border-b">
                            {cell || <span className="text-gray-400">-</span>}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Actions */}
            <div className="flex gap-3">
              <Button onClick={resetUpload} variant="outline">
                Back
              </Button>
              <Button onClick={handleUpload} disabled={isProcessing}>
                {isProcessing ? 'Processing...' : `Import ${preview.total_rows} Leads`}
              </Button>
            </div>
          </div>
        )}

        {step === 'result' && uploadResult && (
          <div className="space-y-6">
            {/* Results Summary */}
            <div className="text-center space-y-4">
              {uploadResult.created > 0 ? (
                <CheckCircle className="h-16 w-16 text-green-500 mx-auto" />
              ) : (
                <AlertCircle className="h-16 w-16 text-yellow-500 mx-auto" />
              )}
              
              <div>
                <h3 className="text-lg font-medium">
                  {uploadResult.created > 0 ? 'Import Completed!' : 'Import Finished with Issues'}
                </h3>
                <p className="text-gray-600">
                  {uploadResult.created > 0 
                    ? `Successfully imported ${uploadResult.created} leads`
                    : 'No leads were imported due to errors'
                  }
                </p>
              </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-4 gap-4">
              <div className="text-center p-3 bg-green-50 rounded-lg">
                <div className="text-2xl font-bold text-green-600">{uploadResult.created}</div>
                <div className="text-sm text-green-700">Created</div>
              </div>
              <div className="text-center p-3 bg-red-50 rounded-lg">
                <div className="text-2xl font-bold text-red-600">{uploadResult.errors.length}</div>
                <div className="text-sm text-red-700">Errors</div>
              </div>
              <div className="text-center p-3 bg-yellow-50 rounded-lg">
                <div className="text-2xl font-bold text-yellow-600">{uploadResult.skipped}</div>
                <div className="text-sm text-yellow-700">Skipped</div>
              </div>
              <div className="text-center p-3 bg-gray-50 rounded-lg">
                <div className="text-2xl font-bold text-gray-600">{uploadResult.total_processed}</div>
                <div className="text-sm text-gray-700">Total</div>
              </div>
            </div>

            {/* Error Details */}
            {uploadResult.errors.length > 0 && (
              <div>
                <h4 className="font-medium mb-2 text-red-700">
                  Errors ({uploadResult.errors.length})
                </h4>
                <div className="bg-red-50 border border-red-200 rounded-lg p-3 max-h-48 overflow-y-auto">
                  {uploadResult.errors.map((error, index) => (
                    <div key={index} className="text-sm text-red-700 mb-1">
                      {error}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Actions */}
            <div className="flex gap-3 justify-center">
              <Button onClick={resetUpload} variant="outline">
                Import Another File
              </Button>
              <Button onClick={onClose}>
                Done
              </Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}