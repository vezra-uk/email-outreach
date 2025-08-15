'use client'
import LeadOpensTracker from '@/components/LeadOpensTracker'

export default function OpensPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <LeadOpensTracker showFilters={true} />
    </div>
  )
}