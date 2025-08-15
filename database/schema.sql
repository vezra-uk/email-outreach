-- Email Automation System - Complete Database Schema
-- This script creates all tables needed for a fresh installation
-- Run this script once to set up your database from scratch

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Function to automatically update campaign statistics
CREATE OR REPLACE FUNCTION update_campaign_stats() RETURNS TRIGGER AS $$
BEGIN
    UPDATE campaigns 
    SET 
        total_leads = (
            SELECT COUNT(*) 
            FROM campaign_leads 
            WHERE campaign_id = NEW.campaign_id
        ),
        emails_sent = (
            SELECT COUNT(*) 
            FROM campaign_leads 
            WHERE campaign_id = NEW.campaign_id AND status = 'sent'
        ),
        emails_opened = (
            SELECT COUNT(*) 
            FROM campaign_leads 
            WHERE campaign_id = NEW.campaign_id AND opens > 0
        ),
        emails_clicked = (
            SELECT COUNT(*) 
            FROM campaign_leads 
            WHERE campaign_id = NEW.campaign_id AND clicks > 0
        ),
        completion_rate = (
            SELECT 
                CASE 
                    WHEN COUNT(*) > 0 THEN 
                        ROUND((COUNT(CASE WHEN status = 'sent' THEN 1 END) * 100.0 / COUNT(*)), 2)
                    ELSE 0 
                END
            FROM campaign_leads 
            WHERE campaign_id = NEW.campaign_id
        ),
        last_sent_at = (
            SELECT MAX(sent_at) 
            FROM campaign_leads 
            WHERE campaign_id = NEW.campaign_id AND status = 'sent'
        )
    WHERE id = NEW.campaign_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- CORE TABLES
-- ========================================

-- Leads table - Main contact management
CREATE TABLE leads (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company VARCHAR(255),
    title VARCHAR(255),
    phone VARCHAR(50),
    website VARCHAR(500),
    industry VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Sending profiles - Sender identity and contact information
CREATE TABLE sending_profiles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    sender_name VARCHAR(255) NOT NULL,
    sender_title VARCHAR(255),
    sender_company VARCHAR(255),
    sender_email VARCHAR(255) NOT NULL,
    sender_phone VARCHAR(50),
    sender_website VARCHAR(255),
    signature TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Campaigns table - Email campaign management
CREATE TABLE campaigns (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(500),
    template TEXT,
    ai_prompt TEXT,
    sending_profile_id INTEGER,
    status VARCHAR(50) DEFAULT 'active',
    daily_limit INTEGER DEFAULT 30,
    total_leads INTEGER DEFAULT 0,
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    emails_clicked INTEGER DEFAULT 0,
    completion_rate NUMERIC(5,2) DEFAULT 0.00,
    last_sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (sending_profile_id) REFERENCES sending_profiles(id) ON DELETE SET NULL
);

-- Campaign-Lead relationship tracking
CREATE TABLE campaign_leads (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER NOT NULL,
    lead_id INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    sent_at TIMESTAMP,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    tracking_pixel_id VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
    FOREIGN KEY (lead_id) REFERENCES leads(id) ON DELETE CASCADE,
    UNIQUE(campaign_id, lead_id)
);

-- Daily statistics tracking
CREATE TABLE daily_stats (
    date DATE PRIMARY KEY,
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    links_clicked INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ========================================
-- EMAIL SEQUENCES SYSTEM
-- ========================================

-- Email sequence definitions
CREATE TABLE email_sequences (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sending_profile_id INTEGER,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (sending_profile_id) REFERENCES sending_profiles(id) ON DELETE SET NULL
);

-- Individual steps within sequences
CREATE TABLE sequence_steps (
    id SERIAL PRIMARY KEY,
    sequence_id INTEGER NOT NULL,
    step_number INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(500) NOT NULL,
    template TEXT NOT NULL,
    ai_prompt TEXT,
    delay_days INTEGER NOT NULL DEFAULT 0,
    delay_hours INTEGER NOT NULL DEFAULT 0,
    is_active VARCHAR(10) DEFAULT 'true',
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (sequence_id) REFERENCES email_sequences(id) ON DELETE CASCADE,
    UNIQUE(sequence_id, step_number)
);

-- Lead progress through sequences
CREATE TABLE lead_sequences (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER NOT NULL,
    sequence_id INTEGER NOT NULL,
    current_step INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'active',
    started_at TIMESTAMP DEFAULT NOW(),
    last_sent_at TIMESTAMP,
    next_send_at TIMESTAMP,
    completed_at TIMESTAMP,
    stop_reason VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (lead_id) REFERENCES leads(id) ON DELETE CASCADE,
    FOREIGN KEY (sequence_id) REFERENCES email_sequences(id) ON DELETE CASCADE,
    UNIQUE(lead_id, sequence_id)
);

-- Individual sequence email sends
CREATE TABLE sequence_emails (
    id SERIAL PRIMARY KEY,
    lead_sequence_id INTEGER NOT NULL,
    step_id INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    sent_at TIMESTAMP,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    tracking_pixel_id VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (lead_sequence_id) REFERENCES lead_sequences(id) ON DELETE CASCADE,
    FOREIGN KEY (step_id) REFERENCES sequence_steps(id) ON DELETE CASCADE
);

-- Email reply tracking
CREATE TABLE email_replies (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER NOT NULL,
    sequence_id INTEGER NOT NULL,
    reply_email_id VARCHAR(255),
    reply_content TEXT,
    reply_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (lead_id) REFERENCES leads(id) ON DELETE CASCADE,
    FOREIGN KEY (sequence_id) REFERENCES email_sequences(id) ON DELETE CASCADE
);

-- ========================================
-- LEAD GROUPS SYSTEM
-- ========================================

-- Lead groups for organization
CREATE TABLE lead_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    color VARCHAR(50) DEFAULT '#3B82F6',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Many-to-many relationship between leads and groups
CREATE TABLE lead_group_memberships (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (lead_id) REFERENCES leads(id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES lead_groups(id) ON DELETE CASCADE,
    UNIQUE(lead_id, group_id)
);

-- ========================================
-- ENHANCED TRACKING SYSTEM
-- ========================================

-- Modern multi-signal tracking events
CREATE TABLE email_tracking_events (
    id SERIAL PRIMARY KEY,
    tracking_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    signal_type VARCHAR(50) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    referer TEXT,
    timestamp TIMESTAMP DEFAULT NOW(),
    delay_from_send INTEGER,
    is_prefetch BOOLEAN DEFAULT FALSE,
    confidence_score DECIMAL(3,2) DEFAULT 0.0,
    event_metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Email open analysis results
CREATE TABLE email_open_analysis (
    id SERIAL PRIMARY KEY,
    tracking_id VARCHAR(255) UNIQUE NOT NULL,
    campaign_lead_id INTEGER,
    sequence_email_id INTEGER,
    total_signals INTEGER DEFAULT 0,
    confidence_score DECIMAL(3,2) DEFAULT 0.0,
    is_opened BOOLEAN DEFAULT FALSE,
    open_method VARCHAR(50),
    first_open_at TIMESTAMP,
    last_activity_at TIMESTAMP,
    unique_ip_count INTEGER DEFAULT 0,
    prefetch_signals INTEGER DEFAULT 0,
    human_signals INTEGER DEFAULT 0,
    analysis_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (campaign_lead_id) REFERENCES campaign_leads(id) ON DELETE SET NULL,
    FOREIGN KEY (sequence_email_id) REFERENCES sequence_emails(id) ON DELETE SET NULL
);

-- Link click tracking
CREATE TABLE link_clicks (
    id SERIAL PRIMARY KEY,
    tracking_id VARCHAR(255) NOT NULL,
    campaign_lead_id INTEGER,
    sequence_email_id INTEGER,
    original_url TEXT NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    referer TEXT,
    clicked_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (campaign_lead_id) REFERENCES campaign_leads(id) ON DELETE CASCADE,
    FOREIGN KEY (sequence_email_id) REFERENCES sequence_emails(id) ON DELETE CASCADE
);

-- Legacy tracking events (for backwards compatibility)
CREATE TABLE tracking_events (
    id SERIAL PRIMARY KEY,
    campaign_lead_id INTEGER,
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (campaign_lead_id) REFERENCES campaign_leads(id) ON DELETE CASCADE
);

-- ========================================
-- VIEWS FOR ANALYTICS
-- ========================================

-- Campaign progress view with calculated statistics
CREATE VIEW campaign_progress AS
SELECT 
    c.id,
    c.name,
    c.subject,
    c.status,
    c.created_at,
    COUNT(cl.id) AS total_leads,
    COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) AS emails_sent,
    COUNT(CASE WHEN cl.opens > 0 THEN 1 END) AS emails_opened,
    COUNT(CASE WHEN cl.clicks > 0 THEN 1 END) AS emails_clicked,
    CASE 
        WHEN COUNT(cl.id) > 0 THEN 
            ROUND((COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) * 100.0 / COUNT(cl.id)), 2)
        ELSE 0 
    END AS completion_rate,
    CASE 
        WHEN COUNT(CASE WHEN cl.status = 'sent' THEN 1 END) > 0 THEN 
            ROUND((COUNT(CASE WHEN cl.opens > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cl.status = 'sent' THEN 1 END)), 2)
        ELSE 0 
    END AS open_rate,
    MAX(cl.sent_at) AS last_sent_at
FROM campaigns c
LEFT JOIN campaign_leads cl ON c.id = cl.campaign_id
GROUP BY c.id, c.name, c.subject, c.status, c.created_at;

-- ========================================
-- TRIGGERS
-- ========================================

-- Trigger to automatically update campaign statistics
CREATE TRIGGER update_campaign_stats_trigger
    AFTER INSERT OR UPDATE ON campaign_leads
    FOR EACH ROW
    EXECUTE FUNCTION update_campaign_stats();

-- ========================================
-- INDEXES FOR PERFORMANCE
-- ========================================

-- Core table indexes
CREATE INDEX idx_leads_email ON leads(email);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_industry ON leads(industry);
CREATE INDEX idx_leads_company ON leads(company);
CREATE INDEX idx_leads_created_at ON leads(created_at);

-- Sending profile indexes
CREATE INDEX idx_sending_profiles_is_default ON sending_profiles(is_default);
CREATE INDEX idx_sending_profiles_sender_email ON sending_profiles(sender_email);

-- Campaign indexes
CREATE INDEX idx_campaigns_status ON campaigns(status);
CREATE INDEX idx_campaigns_sending_profile_id ON campaigns(sending_profile_id);
CREATE INDEX idx_campaigns_created_at ON campaigns(created_at);
CREATE INDEX idx_campaign_leads_campaign_id ON campaign_leads(campaign_id);
CREATE INDEX idx_campaign_leads_lead_id ON campaign_leads(lead_id);
CREATE INDEX idx_campaign_leads_status ON campaign_leads(status);
CREATE INDEX idx_campaign_leads_sent_at ON campaign_leads(sent_at);
CREATE INDEX idx_campaign_leads_tracking_pixel ON campaign_leads(tracking_pixel_id);

-- Sequence indexes
CREATE INDEX idx_email_sequences_status ON email_sequences(status);
CREATE INDEX idx_email_sequences_sending_profile_id ON email_sequences(sending_profile_id);
CREATE INDEX idx_sequence_steps_sequence_id ON sequence_steps(sequence_id);
CREATE INDEX idx_sequence_steps_step_number ON sequence_steps(sequence_id, step_number);
CREATE INDEX idx_lead_sequences_lead_id ON lead_sequences(lead_id);
CREATE INDEX idx_lead_sequences_sequence_id ON lead_sequences(sequence_id);
CREATE INDEX idx_lead_sequences_status ON lead_sequences(status);
CREATE INDEX idx_lead_sequences_next_send_at ON lead_sequences(next_send_at);
CREATE INDEX idx_sequence_emails_lead_sequence_id ON sequence_emails(lead_sequence_id);
CREATE INDEX idx_sequence_emails_status ON sequence_emails(status);
CREATE INDEX idx_sequence_emails_tracking_pixel ON sequence_emails(tracking_pixel_id);

-- Lead groups indexes
CREATE INDEX idx_lead_groups_name ON lead_groups(name);
CREATE INDEX idx_lead_group_memberships_lead_id ON lead_group_memberships(lead_id);
CREATE INDEX idx_lead_group_memberships_group_id ON lead_group_memberships(group_id);

-- Tracking indexes
CREATE INDEX idx_tracking_events_campaign_lead_id ON tracking_events(campaign_lead_id);
CREATE INDEX idx_tracking_events_event_type ON tracking_events(event_type);
CREATE INDEX idx_email_tracking_events_tracking_id ON email_tracking_events(tracking_id);
CREATE INDEX idx_email_tracking_events_event_type ON email_tracking_events(event_type);
CREATE INDEX idx_email_tracking_events_timestamp ON email_tracking_events(timestamp);
CREATE INDEX idx_email_open_analysis_tracking_id ON email_open_analysis(tracking_id);
CREATE INDEX idx_email_open_analysis_confidence ON email_open_analysis(confidence_score);
CREATE INDEX idx_link_clicks_tracking_id ON link_clicks(tracking_id);
CREATE INDEX idx_link_clicks_campaign_lead ON link_clicks(campaign_lead_id);
CREATE INDEX idx_link_clicks_sequence_email ON link_clicks(sequence_email_id);
CREATE INDEX idx_link_clicks_clicked_at ON link_clicks(clicked_at);
CREATE INDEX idx_link_clicks_url ON link_clicks(original_url);

-- Daily stats index
CREATE INDEX idx_daily_stats_date ON daily_stats(date);

-- ========================================
-- SAMPLE DATA (OPTIONAL)
-- ========================================

-- Insert default sending profile
INSERT INTO sending_profiles (name, sender_name, sender_title, sender_company, sender_email, sender_phone, sender_website, signature, is_default) VALUES 
    ('Default Profile', 'Alex Johnson', 'Business Development Manager', 'Growth Solutions Inc.', 'alex@growthsolutions.com', '(555) 123-4567', 'https://growthsolutions.com', 
     'Best regards,<br><br>Alex Johnson<br>Business Development Manager<br>Growth Solutions Inc.<br>alex@growthsolutions.com | (555) 123-4567', true)
ON CONFLICT DO NOTHING;

-- Insert sample lead groups
INSERT INTO lead_groups (name, description, color) VALUES 
    ('Florists', 'Flower shops and floral businesses', '#F59E0B'),
    ('Plumbers', 'Professional plumbing services and contractors', '#F59E0B'),
    ('Tech Companies', 'Software development and technology businesses', '#3B82F6'),
    ('Restaurants', 'Food service and restaurant businesses', '#EF4444'),
    ('Healthcare', 'Medical practices and healthcare providers', '#10B981'),
    ('Real Estate', 'Real estate agents and property management', '#8B5CF6'),
    ('Consultants', 'Business consultants and professional services', '#06B6D4')
ON CONFLICT (name) DO NOTHING;

-- Insert initial daily stats record
INSERT INTO daily_stats (date, emails_sent, emails_opened, links_clicked) 
VALUES (CURRENT_DATE, 0, 0, 0) 
ON CONFLICT (date) DO NOTHING;

-- ========================================
-- HELPFUL COMMENTS
-- ========================================

COMMENT ON TABLE leads IS 'Main table for storing lead contact information';
COMMENT ON TABLE campaigns IS 'Email campaigns with templates and AI prompts';
COMMENT ON TABLE campaign_leads IS 'Junction table tracking campaign progress per lead';
COMMENT ON TABLE email_sequences IS 'Automated email sequence definitions';
COMMENT ON TABLE sequence_steps IS 'Individual steps within email sequences';
COMMENT ON TABLE lead_sequences IS 'Progress tracking for leads in sequences';
COMMENT ON TABLE lead_groups IS 'Groups for organizing leads by category';
COMMENT ON TABLE lead_group_memberships IS 'Many-to-many relationship between leads and groups';
COMMENT ON TABLE email_tracking_events IS 'Modern multi-signal email tracking events';
COMMENT ON TABLE email_open_analysis IS 'Analysis results for email opens with confidence scores';
COMMENT ON TABLE link_clicks IS 'Detailed tracking of individual link clicks in emails';

COMMENT ON COLUMN leads.website IS 'Company website URL';
COMMENT ON COLUMN leads.industry IS 'Industry category for lead segmentation';
COMMENT ON COLUMN campaigns.ai_prompt IS 'Instructions for AI to personalize emails';
COMMENT ON COLUMN campaigns.completion_rate IS 'Percentage of leads that have been contacted';
COMMENT ON COLUMN sequence_steps.subject IS 'Email subject line template for this step';
COMMENT ON COLUMN sequence_steps.template IS 'Email body template for this step';
COMMENT ON COLUMN sequence_steps.is_active IS 'String boolean for SQLAlchemy compatibility';
COMMENT ON COLUMN lead_groups.color IS 'Hex color code for UI display (e.g., #FF0000)';
COMMENT ON COLUMN email_tracking_events.confidence_score IS 'AI confidence that this is a real human interaction (0.0-1.0)';
COMMENT ON COLUMN link_clicks.tracking_id IS 'Links to campaign_leads or sequence_emails tracking pixel ID';
COMMENT ON COLUMN link_clicks.original_url IS 'The actual URL that was clicked (before tracking redirect)';
COMMENT ON COLUMN link_clicks.ip_address IS 'IP address of the clicker';
COMMENT ON COLUMN link_clicks.user_agent IS 'Browser/client user agent string';
COMMENT ON COLUMN link_clicks.referer IS 'HTTP referer header from the click request';

-- ========================================
-- SETUP COMPLETE
-- ========================================

-- Display success message
DO $$
BEGIN
    RAISE NOTICE '✅ Email Automation Database Schema Created Successfully!';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tables Created:';
    RAISE NOTICE '   • leads - Contact management';
    RAISE NOTICE '   • campaigns - Email campaigns'; 
    RAISE NOTICE '   • campaign_leads - Campaign progress';
    RAISE NOTICE '   • email_sequences - Automated sequences';
    RAISE NOTICE '   • sequence_steps - Sequence step definitions';
    RAISE NOTICE '   • lead_sequences - Sequence progress';
    RAISE NOTICE '   • sequence_emails - Individual emails';
    RAISE NOTICE '   • lead_groups - Lead organization';
    RAISE NOTICE '   • lead_group_memberships - Group memberships';
    RAISE NOTICE '   • email_tracking_events - Modern tracking';
    RAISE NOTICE '   • email_open_analysis - Open analysis';
    RAISE NOTICE '   • link_clicks - Click tracking';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Your email automation system is ready to use!';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Next Steps:';
    RAISE NOTICE '   1. Import your leads';
    RAISE NOTICE '   2. Create lead groups to organize them';
    RAISE NOTICE '   3. Set up your email campaigns or sequences';
    RAISE NOTICE '   4. Configure your Gmail API and OpenAI credentials';
END $$;