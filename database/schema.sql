-- Email Automation Database Schema

CREATE TABLE leads (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company VARCHAR(255),
    title VARCHAR(255),
    phone VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE campaigns (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    subject VARCHAR(500),
    template TEXT,
    ai_prompt TEXT,
    status VARCHAR(50) DEFAULT 'active',
    daily_limit INTEGER DEFAULT 30,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE campaign_leads (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id) ON DELETE CASCADE,
    lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending', -- pending, sent, failed, bounced
    sent_at TIMESTAMP,
    opens INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    tracking_pixel_id VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(campaign_id, lead_id)
);

CREATE TABLE daily_stats (
    date DATE PRIMARY KEY,
    emails_sent INTEGER DEFAULT 0,
    emails_opened INTEGER DEFAULT 0,
    links_clicked INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tracking_events (
    id SERIAL PRIMARY KEY,
    campaign_lead_id INTEGER REFERENCES campaign_leads(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL, -- 'open', 'click'
    event_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_leads_email ON leads(email);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_campaign_leads_status ON campaign_leads(status);
CREATE INDEX idx_campaign_leads_sent_at ON campaign_leads(sent_at);
CREATE INDEX idx_tracking_events_type ON tracking_events(event_type);
CREATE INDEX idx_daily_stats_date ON daily_stats(date);
