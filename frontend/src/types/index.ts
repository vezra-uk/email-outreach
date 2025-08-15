export interface Lead {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  company: string;
  title: string;
  phone: string;
  website: string;
  industry: string;
  status: string;
  created_at: string;
}

export interface LeadGroup {
  id: number;
  name: string;
  description?: string;
  color: string;
  lead_count: number;
}

export interface SendingProfile {
  id: number;
  name: string;
  sender_name: string;
  sender_title?: string;
  sender_company?: string;
  sender_email: string;
  sender_phone?: string;
  sender_website?: string;
  signature?: string;
  is_default: boolean;
}

export interface SequenceStep {
  step_number: number;
  name: string;
  ai_prompt: string;
  delay_days: number;
  delay_hours: number;
}

export interface Campaign {
  id: number;
  name: string;
  subject: string;
  template: string;
  status: string;
  total_leads: number;
  emails_sent: number;
  emails_opened: number;
  completion_rate: number;
  created_at: string;
}

export interface NewLead {
  email: string;
  first_name: string;
  last_name: string;
  company: string;
  title: string;
  phone: string;
  website: string;
  industry: string;
}