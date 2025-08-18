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

export interface CampaignStep {
  step_number: number;
  name: string;
  subject?: string;
  template?: string;
  ai_prompt: string;
  delay_days: number;
  delay_hours: number;
}

export interface CampaignProgress {
  total_leads: number;
  active_leads: number;
  completed_leads: number;
  stopped_leads: number;
  replied_leads: number;
  avg_step: number;
}

export interface Campaign {
  id: number;
  name: string;
  description?: string;
  status: string;
  created_at: string;
  steps?: CampaignStep[];
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