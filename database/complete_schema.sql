-- Email Automation System - Complete Database Schema
-- PostgreSQL Schema for Email Campaign Management System
-- Generated: 2025-08-16

-- ============================================================================
-- USERS AND AUTHENTICATION
-- ============================================================================

-- Users table for authentication
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    hashed_password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_superuser BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- API Keys for programmatic access
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- LEADS MANAGEMENT
-- ============================================================================

-- Leads/Contacts table
CREATE TABLE leads (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    company VARCHAR(255),
    title VARCHAR(255),
    phone VARCHAR(255),
    website VARCHAR(255),
    industry VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Lead Groups for organizing contacts
CREATE TABLE lead_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    color VARCHAR(7) DEFAULT '#3B82F6',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Many-to-many relationship between leads and groups
CREATE TABLE lead_group_memberships (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    group_id INTEGER REFERENCES lead_groups(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    UNIQUE(lead_id, group_id)
);

-- ============================================================================
-- SENDING PROFILES
-- ============================================================================

-- Sender profiles for email personalization
CREATE TABLE sending_profiles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    sender_name VARCHAR(255),
    sender_title VARCHAR(255),
    sender_company VARCHAR(255),
    sender_email VARCHAR(255),
    sender_phone VARCHAR(255),
    sender_website VARCHAR(255),
    signature TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- EMAIL SEQUENCES (CAMPAIGNS)
-- ============================================================================

-- Email sequences (modern campaigns with multiple steps)
CREATE TABLE email_sequences (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sending_profile_id INTEGER REFERENCES sending_profiles(id),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Individual steps within a sequence
CREATE TABLE sequence_steps (
    id SERIAL PRIMARY KEY,
    sequence_id INTEGER REFERENCES email_sequences(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(255),
    template TEXT,
    ai_prompt TEXT,
    delay_days INTEGER DEFAULT 0,
    delay_hours INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    include_previous_emails BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Lead enrollment in sequences
CREATE TABLE lead_sequences (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    sequence_id INTEGER REFERENCES email_sequences(id) ON DELETE CASCADE,
    current_step INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'active',
    started_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    last_sent_at TIMESTAMP WITHOUT TIME ZONE,
    next_send_at TIMESTAMP WITHOUT TIME ZONE,
    completed_at TIMESTAMP WITHOUT TIME ZONE,
    stop_reason VARCHAR(255),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    UNIQUE(lead_id, sequence_id)
);

-- Individual email sends within sequences
CREATE TABLE sequence_emails (
    id SERIAL PRIMARY KEY,
    lead_sequence_id INTEGER REFERENCES lead_sequences(id) ON DELETE CASCADE,
    step_id INTEGER REFERENCES sequence_steps(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending',
    subject VARCHAR(255),
    content TEXT,
    sent_at TIMESTAMP WITHOUT TIME ZONE,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    tracking_pixel_id VARCHAR(255) UNIQUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- EMAIL REPLIES AND INTERACTIONS
-- ============================================================================

-- Email replies received from leads
CREATE TABLE email_replies (
    id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    sequence_id INTEGER REFERENCES email_sequences(id) ON DELETE CASCADE,
    reply_email_id VARCHAR(255),
    reply_content TEXT,
    reply_date TIMESTAMP WITHOUT TIME ZONE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- TRACKING AND ANALYTICS
-- ============================================================================

-- Link clicks tracking
CREATE TABLE link_clicks (
    id SERIAL PRIMARY KEY,
    tracking_id VARCHAR(255) NOT NULL,
    lead_sequence_id INTEGER REFERENCES lead_sequences(id) ON DELETE SET NULL,
    sequence_email_id INTEGER REFERENCES sequence_emails(id) ON DELETE SET NULL,
    original_url TEXT NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    referer TEXT,
    clicked_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Email tracking events (opens, etc.)
CREATE TABLE email_tracking_events (
    id SERIAL PRIMARY KEY,
    tracking_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    signal_type VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    referer TEXT,
    timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    delay_from_send INTEGER,
    is_prefetch BOOLEAN DEFAULT FALSE,
    confidence_score DECIMAL(3,2) DEFAULT 0.0,
    event_metadata JSONB,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Email open analysis (aggregated tracking data)
CREATE TABLE email_open_analysis (
    id SERIAL PRIMARY KEY,
    tracking_id VARCHAR(255) UNIQUE NOT NULL,
    lead_sequence_id INTEGER REFERENCES lead_sequences(id) ON DELETE SET NULL,
    sequence_email_id INTEGER REFERENCES sequence_emails(id) ON DELETE SET NULL,
    total_signals INTEGER DEFAULT 0,
    confidence_score DECIMAL(3,2) DEFAULT 0.0,
    is_opened BOOLEAN DEFAULT FALSE,
    open_method VARCHAR(50),
    first_open_at TIMESTAMP WITHOUT TIME ZONE,
    last_activity_at TIMESTAMP WITHOUT TIME ZONE,
    unique_ip_count INTEGER DEFAULT 0,
    prefetch_signals INTEGER DEFAULT 0,
    human_signals INTEGER DEFAULT 0,
    analysis_data JSONB,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- STATISTICS AND REPORTING
-- ============================================================================

-- Daily statistics for dashboard
CREATE TABLE daily_stats (
    date DATE PRIMARY KEY,
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    links_clicked INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Users and authentication indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_api_keys_key ON api_keys(key);
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);

-- Leads indexes
CREATE INDEX idx_leads_email ON leads(email);
CREATE INDEX idx_leads_company ON leads(company);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_created_at ON leads(created_at);

-- Lead groups indexes
CREATE INDEX idx_lead_groups_name ON lead_groups(name);
CREATE INDEX idx_lead_group_memberships_lead_id ON lead_group_memberships(lead_id);
CREATE INDEX idx_lead_group_memberships_group_id ON lead_group_memberships(group_id);

-- Sending profiles indexes
CREATE INDEX idx_sending_profiles_is_default ON sending_profiles(is_default);

-- Email sequences indexes
CREATE INDEX idx_email_sequences_status ON email_sequences(status);
CREATE INDEX idx_email_sequences_created_at ON email_sequences(created_at);

-- Sequence steps indexes
CREATE INDEX idx_sequence_steps_sequence_id ON sequence_steps(sequence_id);
CREATE INDEX idx_sequence_steps_step_number ON sequence_steps(step_number);

-- Lead sequences indexes
CREATE INDEX idx_lead_sequences_lead_id ON lead_sequences(lead_id);
CREATE INDEX idx_lead_sequences_sequence_id ON lead_sequences(sequence_id);
CREATE INDEX idx_lead_sequences_status ON lead_sequences(status);
CREATE INDEX idx_lead_sequences_next_send_at ON lead_sequences(next_send_at);

-- Sequence emails indexes
CREATE INDEX idx_sequence_emails_lead_sequence_id ON sequence_emails(lead_sequence_id);
CREATE INDEX idx_sequence_emails_step_id ON sequence_emails(step_id);
CREATE INDEX idx_sequence_emails_status ON sequence_emails(status);
CREATE INDEX idx_sequence_emails_tracking_pixel ON sequence_emails(tracking_pixel_id);
CREATE INDEX idx_sequence_emails_sent_at ON sequence_emails(sent_at);

-- Email replies indexes
CREATE INDEX idx_email_replies_lead_id ON email_replies(lead_id);
CREATE INDEX idx_email_replies_sequence_id ON email_replies(sequence_id);
CREATE INDEX idx_email_replies_reply_date ON email_replies(reply_date);

-- Tracking indexes
CREATE INDEX idx_link_clicks_tracking_id ON link_clicks(tracking_id);
CREATE INDEX idx_link_clicks_lead_sequence_id ON link_clicks(lead_sequence_id);
CREATE INDEX idx_link_clicks_sequence_email_id ON link_clicks(sequence_email_id);
CREATE INDEX idx_link_clicks_clicked_at ON link_clicks(clicked_at);

CREATE INDEX idx_email_tracking_events_tracking_id ON email_tracking_events(tracking_id);
CREATE INDEX idx_email_tracking_events_event_type ON email_tracking_events(event_type);
CREATE INDEX idx_email_tracking_events_timestamp ON email_tracking_events(timestamp);

CREATE INDEX idx_email_open_analysis_tracking_id ON email_open_analysis(tracking_id);
CREATE INDEX idx_email_open_analysis_lead_sequence_id ON email_open_analysis(lead_sequence_id);
CREATE INDEX idx_email_open_analysis_sequence_email_id ON email_open_analysis(sequence_email_id);

-- Daily stats indexes
CREATE INDEX idx_daily_stats_date ON daily_stats(date);

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE users IS 'System users with authentication credentials';
COMMENT ON TABLE api_keys IS 'API keys for programmatic access to the system';
COMMENT ON TABLE leads IS 'Contact database with lead information';
COMMENT ON TABLE lead_groups IS 'Groups for organizing leads into categories';
COMMENT ON TABLE lead_group_memberships IS 'Many-to-many relationship between leads and groups';
COMMENT ON TABLE sending_profiles IS 'Sender information for email personalization';
COMMENT ON TABLE email_sequences IS 'Email campaigns with multiple steps (sequences)';
COMMENT ON TABLE sequence_steps IS 'Individual steps within an email sequence';
COMMENT ON TABLE lead_sequences IS 'Tracks which leads are enrolled in which sequences';
COMMENT ON TABLE sequence_emails IS 'Individual email sends with actual content and tracking';
COMMENT ON TABLE email_replies IS 'Replies received from leads';
COMMENT ON TABLE link_clicks IS 'Tracks when links in emails are clicked';
COMMENT ON TABLE email_tracking_events IS 'Raw tracking events for email opens and interactions';
COMMENT ON TABLE email_open_analysis IS 'Aggregated analysis of email open behavior';
COMMENT ON TABLE daily_stats IS 'Daily aggregated statistics for reporting';

-- ============================================================================
-- SAMPLE DATA SETUP (OPTIONAL)
-- ============================================================================

-- Create a default admin user (password: admin123)
-- INSERT INTO users (email, username, full_name, hashed_password, is_superuser) 
-- VALUES ('admin@example.com', 'admin', 'System Administrator', '$2b$12$example_hash_here', TRUE);

-- Create a default sending profile
-- INSERT INTO sending_profiles (name, sender_name, sender_title, sender_company, sender_email, is_default)
-- VALUES ('Default Profile', 'Your Name', 'Your Title', 'Your Company', 'you@yourcompany.com', TRUE);