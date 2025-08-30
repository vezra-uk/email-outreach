--
-- PostgreSQL database dump
--

\restrict YMz9PydSDM5C1XnVQmm72J0srODEqJgAIn7USnSAlkFOyB9WYW0wqMg2WKcsxdr

-- Dumped from database version 15.14
-- Dumped by pg_dump version 15.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: update_campaign_stats(); Type: FUNCTION; Schema: public; Owner: user
--

CREATE FUNCTION public.update_campaign_stats() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_campaign_stats() OWNER TO "user";

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.api_keys (
    id integer NOT NULL,
    key character varying NOT NULL,
    name character varying NOT NULL,
    user_id integer NOT NULL,
    is_active boolean,
    created_at timestamp with time zone DEFAULT now(),
    last_used_at timestamp with time zone
);


ALTER TABLE public.api_keys OWNER TO "user";

--
-- Name: api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.api_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.api_keys_id_seq OWNER TO "user";

--
-- Name: api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.api_keys_id_seq OWNED BY public.api_keys.id;


--
-- Name: campaign_leads; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.campaign_leads (
    id integer NOT NULL,
    campaign_id integer,
    lead_id integer,
    status character varying(50) DEFAULT 'pending'::character varying,
    sent_at timestamp without time zone,
    opens integer DEFAULT 0,
    clicks integer DEFAULT 0,
    tracking_pixel_id character varying(255),
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.campaign_leads OWNER TO "user";

--
-- Name: TABLE campaign_leads; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.campaign_leads IS 'Junction table tracking campaign progress per lead';


--
-- Name: campaign_leads_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.campaign_leads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.campaign_leads_id_seq OWNER TO "user";

--
-- Name: campaign_leads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.campaign_leads_id_seq OWNED BY public.campaign_leads.id;


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.campaigns (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    subject character varying(500),
    template text,
    ai_prompt text,
    status character varying(50) DEFAULT 'active'::character varying,
    daily_limit integer DEFAULT 30,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    total_leads integer DEFAULT 0,
    emails_sent integer DEFAULT 0,
    emails_opened integer DEFAULT 0,
    emails_clicked integer DEFAULT 0,
    completion_rate numeric(5,2) DEFAULT 0.00,
    last_sent_at timestamp without time zone,
    sending_profile_id integer
);


ALTER TABLE public.campaigns OWNER TO "user";

--
-- Name: TABLE campaigns; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.campaigns IS 'Email campaigns with templates and AI prompts';


--
-- Name: COLUMN campaigns.ai_prompt; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.campaigns.ai_prompt IS 'Instructions for AI to personalize emails';


--
-- Name: COLUMN campaigns.completion_rate; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.campaigns.completion_rate IS 'Percentage of leads that have been contacted';


--
-- Name: campaign_progress; Type: VIEW; Schema: public; Owner: user
--

CREATE VIEW public.campaign_progress AS
 SELECT c.id,
    c.name,
    c.subject,
    c.status,
    c.created_at,
    count(cl.id) AS total_leads,
    count(
        CASE
            WHEN ((cl.status)::text = 'sent'::text) THEN 1
            ELSE NULL::integer
        END) AS emails_sent,
    count(
        CASE
            WHEN (cl.opens > 0) THEN 1
            ELSE NULL::integer
        END) AS emails_opened,
    count(
        CASE
            WHEN (cl.clicks > 0) THEN 1
            ELSE NULL::integer
        END) AS emails_clicked,
        CASE
            WHEN (count(cl.id) > 0) THEN round((((count(
            CASE
                WHEN ((cl.status)::text = 'sent'::text) THEN 1
                ELSE NULL::integer
            END))::numeric * 100.0) / (count(cl.id))::numeric), 2)
            ELSE (0)::numeric
        END AS completion_rate,
        CASE
            WHEN (count(
            CASE
                WHEN ((cl.status)::text = 'sent'::text) THEN 1
                ELSE NULL::integer
            END) > 0) THEN round((((count(
            CASE
                WHEN (cl.opens > 0) THEN 1
                ELSE NULL::integer
            END))::numeric * 100.0) / (count(
            CASE
                WHEN ((cl.status)::text = 'sent'::text) THEN 1
                ELSE NULL::integer
            END))::numeric), 2)
            ELSE (0)::numeric
        END AS open_rate,
    max(cl.sent_at) AS last_sent_at
   FROM (public.campaigns c
     LEFT JOIN public.campaign_leads cl ON ((c.id = cl.campaign_id)))
  GROUP BY c.id, c.name, c.subject, c.status, c.created_at;


ALTER TABLE public.campaign_progress OWNER TO "user";

--
-- Name: campaigns_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.campaigns_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.campaigns_id_seq OWNER TO "user";

--
-- Name: campaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.campaigns_id_seq OWNED BY public.campaigns.id;


--
-- Name: daily_stats; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.daily_stats (
    date date NOT NULL,
    emails_sent integer DEFAULT 0,
    emails_opened integer DEFAULT 0,
    links_clicked integer DEFAULT 0,
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.daily_stats OWNER TO "user";

--
-- Name: email_open_analysis; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.email_open_analysis (
    id integer NOT NULL,
    tracking_id character varying(255) NOT NULL,
    campaign_lead_id integer,
    sequence_email_id integer,
    total_signals integer DEFAULT 0,
    confidence_score numeric(3,2) DEFAULT 0.0,
    is_opened boolean DEFAULT false,
    open_method character varying(50),
    first_open_at timestamp without time zone,
    last_activity_at timestamp without time zone,
    unique_ip_count integer DEFAULT 0,
    prefetch_signals integer DEFAULT 0,
    human_signals integer DEFAULT 0,
    analysis_data jsonb,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    lead_sequence_id integer
);


ALTER TABLE public.email_open_analysis OWNER TO "user";

--
-- Name: TABLE email_open_analysis; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.email_open_analysis IS 'Analysis results for email opens with confidence scores';


--
-- Name: email_open_analysis_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.email_open_analysis_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_open_analysis_id_seq OWNER TO "user";

--
-- Name: email_open_analysis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.email_open_analysis_id_seq OWNED BY public.email_open_analysis.id;


--
-- Name: email_replies; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.email_replies (
    id integer NOT NULL,
    lead_id integer,
    sequence_id integer,
    reply_email_id character varying(255),
    reply_content text,
    reply_date timestamp without time zone,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.email_replies OWNER TO "user";

--
-- Name: email_replies_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.email_replies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_replies_id_seq OWNER TO "user";

--
-- Name: email_replies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.email_replies_id_seq OWNED BY public.email_replies.id;


--
-- Name: email_sequences; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.email_sequences (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    status character varying(50) DEFAULT 'active'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    sending_profile_id integer
);


ALTER TABLE public.email_sequences OWNER TO "user";

--
-- Name: TABLE email_sequences; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.email_sequences IS 'Automated email sequence definitions';


--
-- Name: email_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.email_sequences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_sequences_id_seq OWNER TO "user";

--
-- Name: email_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.email_sequences_id_seq OWNED BY public.email_sequences.id;


--
-- Name: email_tracking_events; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.email_tracking_events (
    id integer NOT NULL,
    tracking_id character varying(255) NOT NULL,
    event_type character varying(50) NOT NULL,
    signal_type character varying(50) NOT NULL,
    ip_address inet,
    user_agent text,
    referer text,
    "timestamp" timestamp without time zone DEFAULT now(),
    delay_from_send integer,
    is_prefetch boolean DEFAULT false,
    confidence_score numeric(3,2) DEFAULT 0.0,
    event_metadata jsonb,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.email_tracking_events OWNER TO "user";

--
-- Name: TABLE email_tracking_events; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.email_tracking_events IS 'Modern multi-signal email tracking events';


--
-- Name: COLUMN email_tracking_events.confidence_score; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.email_tracking_events.confidence_score IS 'AI confidence that this is a real human interaction (0.0-1.0)';


--
-- Name: email_tracking_events_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.email_tracking_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_tracking_events_id_seq OWNER TO "user";

--
-- Name: email_tracking_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.email_tracking_events_id_seq OWNED BY public.email_tracking_events.id;


--
-- Name: lead_group_memberships; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.lead_group_memberships (
    id integer NOT NULL,
    lead_id integer NOT NULL,
    group_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.lead_group_memberships OWNER TO "user";

--
-- Name: TABLE lead_group_memberships; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.lead_group_memberships IS 'Many-to-many relationship between leads and groups';


--
-- Name: lead_group_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.lead_group_memberships_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lead_group_memberships_id_seq OWNER TO "user";

--
-- Name: lead_group_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.lead_group_memberships_id_seq OWNED BY public.lead_group_memberships.id;


--
-- Name: lead_groups; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.lead_groups (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    color character varying(50) DEFAULT '#3B82F6'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.lead_groups OWNER TO "user";

--
-- Name: TABLE lead_groups; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.lead_groups IS 'Groups for organizing leads by category';


--
-- Name: COLUMN lead_groups.color; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.lead_groups.color IS 'Hex color code for UI display (e.g., #FF0000)';


--
-- Name: lead_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.lead_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lead_groups_id_seq OWNER TO "user";

--
-- Name: lead_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.lead_groups_id_seq OWNED BY public.lead_groups.id;


--
-- Name: lead_sequences; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.lead_sequences (
    id integer NOT NULL,
    lead_id integer,
    sequence_id integer,
    current_step integer DEFAULT 1,
    status character varying(50) DEFAULT 'active'::character varying,
    started_at timestamp without time zone DEFAULT now(),
    last_sent_at timestamp without time zone,
    next_send_at timestamp without time zone,
    completed_at timestamp without time zone,
    stop_reason character varying(100),
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.lead_sequences OWNER TO "user";

--
-- Name: TABLE lead_sequences; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.lead_sequences IS 'Progress tracking for leads in sequences';


--
-- Name: lead_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.lead_sequences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lead_sequences_id_seq OWNER TO "user";

--
-- Name: lead_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.lead_sequences_id_seq OWNED BY public.lead_sequences.id;


--
-- Name: leads; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.leads (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    first_name character varying(100),
    last_name character varying(100),
    company character varying(255),
    title character varying(255),
    phone character varying(50),
    status character varying(50) DEFAULT 'active'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    website character varying(500),
    industry character varying(255)
);


ALTER TABLE public.leads OWNER TO "user";

--
-- Name: TABLE leads; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.leads IS 'Main table for storing lead contact information';


--
-- Name: COLUMN leads.website; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.leads.website IS 'Company website URL';


--
-- Name: COLUMN leads.industry; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.leads.industry IS 'Industry category for lead segmentation';


--
-- Name: leads_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.leads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.leads_id_seq OWNER TO "user";

--
-- Name: leads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.leads_id_seq OWNED BY public.leads.id;


--
-- Name: link_clicks; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.link_clicks (
    id integer NOT NULL,
    tracking_id character varying(255) NOT NULL,
    campaign_lead_id integer,
    sequence_email_id integer,
    original_url text NOT NULL,
    ip_address character varying(45),
    user_agent text,
    referer text,
    clicked_at timestamp without time zone DEFAULT now(),
    created_at timestamp without time zone DEFAULT now(),
    lead_sequence_id integer
);


ALTER TABLE public.link_clicks OWNER TO "user";

--
-- Name: TABLE link_clicks; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.link_clicks IS 'Detailed tracking of individual link clicks in emails';


--
-- Name: COLUMN link_clicks.tracking_id; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.link_clicks.tracking_id IS 'Links to campaign_leads or sequence_emails tracking pixel ID';


--
-- Name: COLUMN link_clicks.original_url; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.link_clicks.original_url IS 'The actual URL that was clicked (before tracking redirect)';


--
-- Name: COLUMN link_clicks.ip_address; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.link_clicks.ip_address IS 'IP address of the clicker';


--
-- Name: COLUMN link_clicks.user_agent; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.link_clicks.user_agent IS 'Browser/client user agent string';


--
-- Name: COLUMN link_clicks.referer; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.link_clicks.referer IS 'HTTP referer header from the click request';


--
-- Name: link_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.link_clicks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.link_clicks_id_seq OWNER TO "user";

--
-- Name: link_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.link_clicks_id_seq OWNED BY public.link_clicks.id;


--
-- Name: sending_profiles; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.sending_profiles (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    sender_name character varying(255) NOT NULL,
    sender_title character varying(255),
    sender_company character varying(255),
    sender_email character varying(255) NOT NULL,
    sender_phone character varying(50),
    sender_website character varying(255),
    signature text,
    is_default boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    schedule_enabled boolean DEFAULT true,
    schedule_days character varying DEFAULT '1,2,3,4,5'::character varying,
    schedule_time_from time without time zone DEFAULT '09:00:00'::time without time zone,
    schedule_time_to time without time zone DEFAULT '17:00:00'::time without time zone,
    schedule_timezone character varying DEFAULT 'UTC'::character varying
);


ALTER TABLE public.sending_profiles OWNER TO "user";

--
-- Name: sending_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.sending_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sending_profiles_id_seq OWNER TO "user";

--
-- Name: sending_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.sending_profiles_id_seq OWNED BY public.sending_profiles.id;


--
-- Name: sequence_emails; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.sequence_emails (
    id integer NOT NULL,
    lead_sequence_id integer,
    step_id integer,
    status character varying(50) DEFAULT 'pending'::character varying,
    sent_at timestamp without time zone,
    opens integer DEFAULT 0,
    clicks integer DEFAULT 0,
    tracking_pixel_id character varying(255),
    created_at timestamp without time zone DEFAULT now(),
    subject character varying(255),
    content text
);


ALTER TABLE public.sequence_emails OWNER TO "user";

--
-- Name: sequence_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.sequence_emails_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sequence_emails_id_seq OWNER TO "user";

--
-- Name: sequence_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.sequence_emails_id_seq OWNED BY public.sequence_emails.id;


--
-- Name: sequence_steps; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.sequence_steps (
    id integer NOT NULL,
    sequence_id integer,
    step_number integer NOT NULL,
    name character varying(255) NOT NULL,
    ai_prompt text NOT NULL,
    delay_days integer DEFAULT 0 NOT NULL,
    delay_hours integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    subject character varying(500) DEFAULT ''::character varying,
    template text DEFAULT ''::text,
    include_previous_emails boolean DEFAULT false
);


ALTER TABLE public.sequence_steps OWNER TO "user";

--
-- Name: TABLE sequence_steps; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON TABLE public.sequence_steps IS 'Individual steps within email sequences';


--
-- Name: COLUMN sequence_steps.is_active; Type: COMMENT; Schema: public; Owner: user
--

COMMENT ON COLUMN public.sequence_steps.is_active IS 'String boolean for SQLAlchemy compatibility';


--
-- Name: sequence_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.sequence_steps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sequence_steps_id_seq OWNER TO "user";

--
-- Name: sequence_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.sequence_steps_id_seq OWNED BY public.sequence_steps.id;


--
-- Name: tracking_events; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.tracking_events (
    id integer NOT NULL,
    campaign_lead_id integer,
    event_type character varying(50) NOT NULL,
    event_data jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.tracking_events OWNER TO "user";

--
-- Name: tracking_events_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.tracking_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tracking_events_id_seq OWNER TO "user";

--
-- Name: tracking_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.tracking_events_id_seq OWNED BY public.tracking_events.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying NOT NULL,
    username character varying NOT NULL,
    full_name character varying,
    hashed_password character varying NOT NULL,
    is_active boolean,
    is_superuser boolean,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);


ALTER TABLE public.users OWNER TO "user";

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: user
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO "user";

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: user
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: api_keys id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.api_keys ALTER COLUMN id SET DEFAULT nextval('public.api_keys_id_seq'::regclass);


--
-- Name: campaign_leads id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaign_leads ALTER COLUMN id SET DEFAULT nextval('public.campaign_leads_id_seq'::regclass);


--
-- Name: campaigns id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaigns ALTER COLUMN id SET DEFAULT nextval('public.campaigns_id_seq'::regclass);


--
-- Name: email_open_analysis id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_open_analysis ALTER COLUMN id SET DEFAULT nextval('public.email_open_analysis_id_seq'::regclass);


--
-- Name: email_replies id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_replies ALTER COLUMN id SET DEFAULT nextval('public.email_replies_id_seq'::regclass);


--
-- Name: email_sequences id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_sequences ALTER COLUMN id SET DEFAULT nextval('public.email_sequences_id_seq'::regclass);


--
-- Name: email_tracking_events id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_tracking_events ALTER COLUMN id SET DEFAULT nextval('public.email_tracking_events_id_seq'::regclass);


--
-- Name: lead_group_memberships id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_group_memberships ALTER COLUMN id SET DEFAULT nextval('public.lead_group_memberships_id_seq'::regclass);


--
-- Name: lead_groups id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_groups ALTER COLUMN id SET DEFAULT nextval('public.lead_groups_id_seq'::regclass);


--
-- Name: lead_sequences id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_sequences ALTER COLUMN id SET DEFAULT nextval('public.lead_sequences_id_seq'::regclass);


--
-- Name: leads id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.leads ALTER COLUMN id SET DEFAULT nextval('public.leads_id_seq'::regclass);


--
-- Name: link_clicks id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.link_clicks ALTER COLUMN id SET DEFAULT nextval('public.link_clicks_id_seq'::regclass);


--
-- Name: sending_profiles id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sending_profiles ALTER COLUMN id SET DEFAULT nextval('public.sending_profiles_id_seq'::regclass);


--
-- Name: sequence_emails id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_emails ALTER COLUMN id SET DEFAULT nextval('public.sequence_emails_id_seq'::regclass);


--
-- Name: sequence_steps id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_steps ALTER COLUMN id SET DEFAULT nextval('public.sequence_steps_id_seq'::regclass);


--
-- Name: tracking_events id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.tracking_events ALTER COLUMN id SET DEFAULT nextval('public.tracking_events_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: api_keys; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.api_keys (id, key, name, user_id, is_active, created_at, last_used_at) FROM stdin;
1	ema_OSwMiMUQ0xmeU49Kuua4XjbqsIUy1KfN	Test API Key	1	t	2025-08-13 20:24:01.723628+00	2025-08-18 14:43:43.521395+00
\.


--
-- Data for Name: campaign_leads; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.campaign_leads (id, campaign_id, lead_id, status, sent_at, opens, clicks, tracking_pixel_id, created_at) FROM stdin;
1	1	1	sent	2025-08-08 21:02:38.290851	0	0	pixel_1_1	2025-08-08 20:34:36.962909
3	3	1	sent	2025-08-08 22:17:54.662799	0	0	pixel_3_1	2025-08-08 22:17:29.375268
2	2	1	sent	2025-08-08 22:06:37.861094	2	0	pixel_2_1	2025-08-08 22:06:30.231016
4	4	1	sent	2025-08-10 20:58:20.900605	0	0	pixel_4_1	2025-08-10 20:32:41.733625
6	6	1	sent	2025-08-10 21:24:47.874681	0	0	pixel_6_1	2025-08-10 21:16:42.712476
7	7	1	sent	2025-08-11 07:24:03.946737	0	0	pixel_7_1	2025-08-11 07:23:47.266706
8	8	1	sent	2025-08-11 20:05:02.177859	0	0	pixel_8_1	2025-08-11 20:04:53.55256
9	9	1	sent	2025-08-11 20:36:17.783182	0	0	pixel_9_1	2025-08-11 20:36:10.057005
5	5	1	sent	2025-08-10 21:09:15.088609	2	0	pixel_5_1	2025-08-10 21:09:08.820339
10	9	2	sent	2025-08-11 20:36:21.04341	1	0	pixel_9_2	2025-08-11 20:36:10.057007
11	10	1	sent	2025-08-12 14:11:36.974159	1	0	pixel_10_1	2025-08-12 14:11:29.988407
12	11	1	sent	2025-08-12 20:34:59.895235	1	0	pixel_11_1	2025-08-12 20:34:45.356732
13	12	1	sent	2025-08-12 20:38:47.381817	0	0	pixel_12_1	2025-08-12 20:38:33.987927
17	16	2	pending	\N	0	0	pixel_16_2	2025-08-15 22:02:36.023339
\.


--
-- Data for Name: campaigns; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.campaigns (id, name, subject, template, ai_prompt, status, daily_limit, created_at, updated_at, total_leads, emails_sent, emails_opened, emails_clicked, completion_rate, last_sent_at, sending_profile_id) FROM stdin;
6	apples	tasty apples	Very tasty apples at discount price!	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-10 21:16:42.704343	2025-08-15 08:38:09.270087	1	1	0	0	0.00	\N	\N
5	oranges	buy my oranges please 	Hi please by my oranges	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-10 21:09:08.813476	2025-08-15 08:50:20.338496	1	1	1	0	100.00	2025-08-10 21:09:15.088609	\N
4	test again	just another test	No need to worry. Just trying things out	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-10 20:32:41.724834	2025-08-15 08:50:22.057317	1	1	0	0	0.00	\N	\N
3	tet3	let's go again	Why not hahahah	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-08 22:17:29.372524	2025-08-15 08:50:23.395018	1	1	0	0	0.00	\N	\N
2	another test	testy bedty	Let's do another test shall we?	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-08 22:06:30.225302	2025-08-15 08:50:24.509529	1	1	1	0	0.00	\N	\N
1	test campaign	test campaign 	This is a test. No need to respond 	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-08 20:34:36.959217	2025-08-15 08:50:25.650665	1	1	0	0	0.00	\N	\N
12	gogogo	buy email	Buy my email package!	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	archived	30	2025-08-12 20:38:33.9849	2025-08-15 08:37:48.604224	1	1	0	0	100.00	2025-08-12 20:38:47.381817	\N
11	another test	but my email	Hey, we sell email addresses. Please buy one	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-12 20:34:45.345704	2025-08-15 08:38:00.063729	1	1	1	0	100.00	2025-08-12 20:34:59.895235	\N
10	testing again	your free email is costing you customers	Hi we sell branded email like info@yourdomain.com Do you want yo buy it?	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-12 14:11:29.964751	2025-08-15 08:38:02.279614	1	1	1	0	100.00	2025-08-12 14:11:36.974159	\N
9	testing 123	testing testing 	Is this thing on	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-11 20:36:10.053744	2025-08-15 08:38:04.109007	2	2	1	0	100.00	2025-08-11 20:36:21.04341	\N
8	testing again	let's have a test	Hi. I'm just testing this again	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-11 20:04:53.543936	2025-08-15 08:38:05.940393	1	1	0	0	100.00	2025-08-11 20:05:02.177859	\N
7	Branded Email	Your Free Email is Costing You Customers	Hi There,\n\nI was browsing local services and came across {company}. I was very impressed by your workmanship and i can realy see the passion in your work.\n\nI notices however that you are currently using a free gmail email address. Have you considered upgrading to a more professioal email like info@yourcompany.com? A recent study discovered that 80% of people will decide to not engage with a contact channel like yourcompany@gmail.com! That is business running away!\n\nAt WeGetYou.Online we specialise in setting you up with  branded email. Even better is costs less than £5 a month!\n\nJust let me know if your interested and want to get started\n\nKindest Regards,\n\nRyan Ellis | CEO	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally.	completed	30	2025-08-11 07:23:47.25728	2025-08-15 08:38:06.733393	1	1	0	0	100.00	2025-08-11 07:24:03.946737	\N
16	track test			Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy.	active	30	2025-08-15 22:02:36.013371	2025-08-15 22:02:36.013374	1	0	0	0	0.00	\N	2
\.


--
-- Data for Name: daily_stats; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.daily_stats (date, emails_sent, emails_opened, links_clicked, updated_at) FROM stdin;
2025-08-08	3	1	0	2025-08-08 20:34:44.330036
2025-08-09	0	0	0	2025-08-09 08:24:09.652725
2025-08-18	51	28	0	2025-08-18 08:39:35.051443
2025-08-22	29	22	0	2025-08-22 00:01:10.915728
2025-08-10	3	1	0	2025-08-10 20:32:45.855287
2025-08-11	4	2	0	2025-08-11 07:23:59.517723
2025-08-21	29	8	0	2025-08-21 00:03:49.6632
2025-08-12	3	0	0	2025-08-12 06:09:08.726129
2025-08-24	27	2	0	2025-08-24 00:00:14.463101
2025-08-26	3	12	0	2025-08-26 00:00:42.424118
2025-08-19	3	14	0	2025-08-19 00:03:20.995419
2025-08-15	3	4	0	2025-08-15 14:18:14.881128
2025-08-28	28	6	0	2025-08-28 00:05:27.542409
2025-08-29	0	0	0	2025-08-29 00:04:05.971573
2025-08-20	30	19	0	2025-08-20 00:03:36.581817
2025-08-16	7	7	0	2025-08-16 07:08:46.142277
2025-08-17	0	0	0	2025-08-17 09:00:24.446748
2025-08-23	25	9	0	2025-08-23 00:04:22.003775
2025-08-27	22	2	0	2025-08-27 12:27:00.059645
2025-08-25	29	12	0	2025-08-25 00:04:25.320128
\.


--
-- Data for Name: email_open_analysis; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.email_open_analysis (id, tracking_id, campaign_lead_id, sequence_email_id, total_signals, confidence_score, is_opened, open_method, first_open_at, last_activity_at, unique_ip_count, prefetch_signals, human_signals, analysis_data, created_at, updated_at, lead_sequence_id) FROM stdin;
\.


--
-- Data for Name: email_replies; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.email_replies (id, lead_id, sequence_id, reply_email_id, reply_content, reply_date, created_at) FROM stdin;
\.


--
-- Data for Name: email_sequences; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.email_sequences (id, name, description, status, created_at, updated_at, sending_profile_id) FROM stdin;
2	Florist Free Email		inactive	2025-08-13 12:13:06.436029	2025-08-15 12:52:31.277249	2
4	email test		inactive	2025-08-15 11:04:11.901727	2025-08-15 12:52:36.807234	2
7	test 3		inactive	2025-08-16 12:43:41.957189	2025-08-17 20:53:58.071497	2
5	email test		inactive	2025-08-15 11:06:47.75301	2025-08-17 20:54:03.395893	2
8	Test 18-08		inactive	2025-08-18 08:37:48.506575	2025-08-18 09:58:32.957481	2
10	test		inactive	2025-08-18 10:47:27.257806	2025-08-18 11:26:45.978601	2
13	deliverabiity test		active	2025-08-18 14:08:52.997293	2025-08-18 14:08:52.997296	2
11	test		inactive	2025-08-18 11:27:04.682566	2025-08-18 20:07:02.983468	2
12	Free Email		inactive	2025-08-18 11:56:55.515958	2025-08-18 20:07:05.177391	2
14	plain text test		inactive	2025-08-18 14:49:44.553246	2025-08-18 20:07:14.220167	2
15	Free Email		inactive	2025-08-18 15:01:56.71146	2025-08-18 20:07:17.423404	2
16	florists email 		active	2025-08-18 20:23:16.20463	2025-08-18 20:23:16.204633	2
6	testing		inactive	2025-08-16 06:53:11.487398	2025-08-19 09:16:43.148466	2
17	spam test		inactive	2025-08-19 14:29:54.617229	2025-08-19 19:41:52.967025	2
18	personal trainer 		inactive	2025-08-20 05:53:21.519654	2025-08-20 07:37:37.183925	2
19	pt		inactive	2025-08-20 07:38:01.919988	2025-08-20 08:04:09.560679	2
21	Personal Trainers		active	2025-08-20 13:38:02.245432	2025-08-20 13:38:02.245434	2
20	pt		inactive	2025-08-20 08:20:24.222481	2025-08-20 18:53:06.583613	2
22	track test		inactive	2025-08-20 19:57:42.798666	2025-08-21 06:59:14.950992	2
9	placeholder test		inactive	2025-08-18 09:54:59.181132	2025-08-22 12:06:12.785697	2
23	Photographers		active	2025-08-22 12:10:55.603881	2025-08-22 12:10:55.603884	2
24	massage therapist 		active	2025-08-28 02:27:44.038993	2025-08-28 02:27:44.038996	2
25	test		active	2025-08-28 17:16:42.240753	2025-08-28 17:16:42.240755	2
\.


--
-- Data for Name: email_tracking_events; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.email_tracking_events (id, tracking_id, event_type, signal_type, ip_address, user_agent, referer, "timestamp", delay_from_send, is_prefetch, confidence_score, event_metadata, created_at) FROM stdin;
\.


--
-- Data for Name: lead_group_memberships; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.lead_group_memberships (id, lead_id, group_id, created_at) FROM stdin;
1	3	13	2025-08-12 21:18:13.491178
2	4	13	2025-08-12 21:18:13.491181
3	5	13	2025-08-12 21:18:13.491181
4	6	13	2025-08-12 21:18:13.491182
5	7	13	2025-08-12 21:18:13.491182
6	8	13	2025-08-12 21:18:13.491183
7	9	13	2025-08-12 21:18:13.491183
8	10	13	2025-08-12 21:18:13.491184
9	11	13	2025-08-12 21:18:13.491184
10	12	13	2025-08-12 21:18:13.491185
11	13	13	2025-08-12 21:18:13.491185
12	14	13	2025-08-12 21:18:13.491186
13	15	13	2025-08-12 21:18:13.491186
14	16	13	2025-08-12 21:18:13.491187
15	17	13	2025-08-12 21:18:13.491187
16	18	13	2025-08-12 21:18:13.491188
17	19	13	2025-08-12 21:18:13.491188
18	20	13	2025-08-12 21:18:13.491189
19	21	13	2025-08-12 21:18:13.491189
20	22	13	2025-08-12 21:18:13.49119
21	23	13	2025-08-12 21:18:13.49119
22	24	13	2025-08-12 21:18:13.491191
23	25	13	2025-08-12 21:18:13.491191
24	26	13	2025-08-12 21:18:13.491192
25	27	13	2025-08-12 21:18:13.491192
26	28	13	2025-08-12 21:18:13.491193
27	29	13	2025-08-12 21:18:13.491193
28	30	13	2025-08-12 21:18:13.491194
29	31	13	2025-08-12 21:18:13.491194
30	32	13	2025-08-12 21:18:13.491195
32	181	20	2025-08-20 13:34:15.692315
33	179	20	2025-08-20 13:34:15.692317
34	184	20	2025-08-20 13:34:15.692319
35	180	20	2025-08-20 13:34:15.69232
36	182	20	2025-08-20 13:34:15.69232
37	183	20	2025-08-20 13:34:15.692321
38	187	20	2025-08-20 13:34:15.692321
39	186	20	2025-08-20 13:34:15.692322
40	185	20	2025-08-20 13:34:15.692322
41	191	20	2025-08-20 13:34:15.692323
42	193	20	2025-08-20 13:34:15.692323
43	192	20	2025-08-20 13:34:15.692323
44	195	20	2025-08-20 13:34:15.692324
45	199	20	2025-08-20 13:34:15.692324
46	200	20	2025-08-20 13:34:15.692325
47	178	20	2025-08-20 13:34:15.692325
48	188	20	2025-08-20 13:34:15.692325
49	189	20	2025-08-20 13:34:15.692326
50	190	20	2025-08-20 13:34:15.692326
51	196	20	2025-08-20 13:34:15.692327
52	198	20	2025-08-20 13:34:15.692327
53	194	20	2025-08-20 13:34:15.692327
54	231	21	2025-08-20 18:56:35.909106
55	230	21	2025-08-20 18:56:35.909108
56	229	21	2025-08-20 18:56:35.909109
57	228	21	2025-08-20 18:56:35.909109
58	227	21	2025-08-20 18:56:35.90911
59	226	21	2025-08-20 18:56:35.90911
60	225	21	2025-08-20 18:56:35.909111
61	224	21	2025-08-20 18:56:35.909111
62	223	21	2025-08-20 18:56:35.909112
63	222	21	2025-08-20 18:56:35.909112
64	221	21	2025-08-20 18:56:35.909113
65	220	21	2025-08-20 18:56:35.909113
66	219	21	2025-08-20 18:56:35.909114
67	218	21	2025-08-20 18:56:35.909114
68	217	21	2025-08-20 18:56:35.909115
69	216	21	2025-08-20 18:56:35.909115
70	215	21	2025-08-20 18:56:35.909116
71	214	21	2025-08-20 18:56:35.909116
72	213	21	2025-08-20 18:56:35.909117
73	212	21	2025-08-20 18:56:35.909117
74	211	21	2025-08-20 18:56:35.909118
75	210	21	2025-08-20 18:56:35.909118
76	209	21	2025-08-20 18:56:35.909119
77	208	21	2025-08-20 18:56:35.909119
78	207	21	2025-08-20 18:56:35.90912
79	206	21	2025-08-20 18:56:35.90912
80	205	21	2025-08-20 18:56:35.909121
81	204	21	2025-08-20 18:56:35.909121
82	203	21	2025-08-20 18:56:35.909122
83	286	22	2025-08-28 02:08:01.043874
84	287	22	2025-08-28 02:08:01.043877
85	288	22	2025-08-28 02:08:01.043877
86	289	22	2025-08-28 02:08:01.043878
87	290	22	2025-08-28 02:08:01.043878
88	291	22	2025-08-28 02:08:01.043879
89	292	22	2025-08-28 02:08:01.043879
90	293	22	2025-08-28 02:08:01.04388
91	294	22	2025-08-28 02:08:01.04388
92	295	22	2025-08-28 02:08:01.043881
93	296	22	2025-08-28 02:08:01.043881
94	297	22	2025-08-28 02:08:01.043881
95	298	22	2025-08-28 02:08:01.043882
96	299	22	2025-08-28 02:08:01.043882
97	300	22	2025-08-28 02:08:01.043883
98	301	22	2025-08-28 02:08:01.043883
99	302	22	2025-08-28 02:08:01.043883
100	303	22	2025-08-28 02:08:01.043884
101	304	22	2025-08-28 02:08:01.043884
102	305	22	2025-08-28 02:08:01.043885
103	306	22	2025-08-28 02:08:01.043885
104	307	22	2025-08-28 02:08:01.043885
105	308	22	2025-08-28 02:08:01.043886
106	309	22	2025-08-28 02:08:01.043886
107	310	22	2025-08-28 02:08:01.043887
108	311	22	2025-08-28 02:08:01.043887
109	312	22	2025-08-28 02:08:01.043888
110	313	22	2025-08-28 02:08:01.043888
111	314	22	2025-08-28 02:08:01.043888
112	315	22	2025-08-28 02:08:01.043889
113	316	22	2025-08-28 02:08:01.043889
114	317	22	2025-08-28 02:08:01.04389
115	318	22	2025-08-28 02:08:01.04389
116	319	22	2025-08-28 02:08:01.043891
117	320	22	2025-08-28 02:08:01.043891
118	321	22	2025-08-28 02:08:01.043891
119	322	22	2025-08-28 02:08:01.043892
120	323	22	2025-08-28 02:08:01.043892
121	324	22	2025-08-28 02:08:01.043892
122	325	22	2025-08-28 02:08:01.043893
123	326	22	2025-08-28 02:08:01.043893
124	327	22	2025-08-28 02:08:01.043894
125	328	22	2025-08-28 02:08:01.043894
126	329	22	2025-08-28 02:08:01.043894
127	330	22	2025-08-28 02:08:01.043895
128	331	22	2025-08-28 02:08:01.043895
129	332	22	2025-08-28 02:08:01.043896
130	333	22	2025-08-28 02:08:01.043896
131	334	22	2025-08-28 02:08:01.043897
132	335	22	2025-08-28 02:08:01.043897
133	336	22	2025-08-28 02:08:01.043898
134	337	22	2025-08-28 02:08:01.043898
135	338	22	2025-08-28 02:08:01.043899
\.


--
-- Data for Name: lead_groups; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.lead_groups (id, name, description, color, created_at, updated_at) FROM stdin;
13	Florists		#10B981	2025-08-12 21:18:13.40537	2025-08-12 21:18:13.405372
20	Personal Trainers		#EC4899	2025-08-20 05:50:44.600061	2025-08-20 05:50:44.600063
21	Photographer		#06B6D4	2025-08-20 18:56:35.807352	2025-08-20 18:56:35.807354
22	massage therapist	\N	#3B82F6	2025-08-28 02:08:00.929719	2025-08-28 02:08:00.929722
\.


--
-- Data for Name: lead_sequences; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.lead_sequences (id, lead_id, sequence_id, current_step, status, started_at, last_sent_at, next_send_at, completed_at, stop_reason, created_at, updated_at) FROM stdin;
25	7	16	4	completed	2025-08-18 20:23:16.279044	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315908	2025-08-18 20:23:16.315908
33	15	16	4	completed	2025-08-18 20:23:16.290476	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315914	2025-08-18 20:23:16.315915
30	12	16	4	completed	2025-08-18 20:23:16.28617	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315912	2025-08-18 20:23:16.315912
28	10	16	4	completed	2025-08-18 20:23:16.283302	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315911	2025-08-18 20:23:16.315911
26	8	16	4	completed	2025-08-18 20:23:16.280459	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315909	2025-08-18 20:23:16.315909
27	9	16	4	completed	2025-08-18 20:23:16.281867	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.31591	2025-08-18 20:23:16.31591
1	1	5	3	completed	2025-08-15 11:06:47.870634	2025-08-15 22:05:26.532436	\N	2025-08-15 22:05:26.532436	\N	2025-08-15 11:06:47.87165	2025-08-15 11:06:47.871653
29	11	16	4	completed	2025-08-18 20:23:16.284731	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315911	2025-08-18 20:23:16.315912
24	6	16	4	completed	2025-08-18 20:23:16.277616	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315907	2025-08-18 20:23:16.315908
32	14	16	4	completed	2025-08-18 20:23:16.289081	2025-08-24 20:32:58.691497	\N	2025-08-24 20:32:58.691497	\N	2025-08-18 20:23:16.315913	2025-08-18 20:23:16.315914
2	2	5	3	completed	2025-08-15 22:03:03.424544	2025-08-16 07:08:38.007695	\N	2025-08-16 07:08:38.007695	\N	2025-08-15 22:03:03.425554	2025-08-15 22:03:03.425556
39	21	16	4	completed	2025-08-18 20:23:16.299197	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315919	2025-08-18 20:23:16.315919
81	1	22	2	completed	2025-08-20 19:57:42.868353	2025-08-20 19:57:51.109605	\N	2025-08-20 19:57:51.109605	\N	2025-08-20 19:57:42.871194	2025-08-20 19:57:42.871196
41	23	16	4	completed	2025-08-18 20:23:16.302095	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.31592	2025-08-18 20:23:16.31592
36	18	16	4	completed	2025-08-18 20:23:16.294875	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315916	2025-08-18 20:23:16.315917
42	24	16	4	completed	2025-08-18 20:23:16.303539	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315921	2025-08-18 20:23:16.315921
31	13	16	4	completed	2025-08-18 20:23:16.287613	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315913	2025-08-18 20:23:16.315913
5	1	7	3	completed	2025-08-16 12:43:42.076233	2025-08-16 13:44:07.257362	\N	2025-08-16 13:44:07.257362	\N	2025-08-16 12:43:42.078439	2025-08-16 12:43:42.078441
6	2	7	3	completed	2025-08-16 12:43:42.078019	2025-08-16 13:44:07.257362	\N	2025-08-16 13:44:07.257362	\N	2025-08-16 12:43:42.078442	2025-08-16 12:43:42.078442
43	25	16	4	completed	2025-08-18 20:23:16.304953	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315922	2025-08-18 20:23:16.315922
34	16	16	4	completed	2025-08-18 20:23:16.291944	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315915	2025-08-18 20:23:16.315915
37	19	16	4	completed	2025-08-18 20:23:16.29633	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315917	2025-08-18 20:23:16.315917
35	17	16	4	completed	2025-08-18 20:23:16.293396	2025-08-24 20:57:15.78522	\N	2025-08-24 20:57:15.78522	\N	2025-08-18 20:23:16.315916	2025-08-18 20:23:16.315916
7	1	8	3	completed	2025-08-18 08:37:48.57138	2025-08-18 09:39:41.802866	\N	2025-08-18 09:39:41.802866	\N	2025-08-18 08:37:48.573438	2025-08-18 08:37:48.57344
8	2	8	3	completed	2025-08-18 08:37:48.573071	2025-08-18 09:39:41.802866	\N	2025-08-18 09:39:41.802866	\N	2025-08-18 08:37:48.573441	2025-08-18 08:37:48.573441
40	22	16	4	completed	2025-08-18 20:23:16.300649	2025-08-24 21:18:27.245838	\N	2025-08-24 21:18:27.245838	\N	2025-08-18 20:23:16.315919	2025-08-18 20:23:16.31592
38	20	16	4	completed	2025-08-18 20:23:16.297746	2025-08-24 21:18:27.245838	\N	2025-08-24 21:18:27.245838	\N	2025-08-18 20:23:16.315918	2025-08-18 20:23:16.315918
23	5	16	4	completed	2025-08-18 20:23:16.276199	2025-08-24 21:25:35.985051	\N	2025-08-24 21:25:35.985051	\N	2025-08-18 20:23:16.315907	2025-08-18 20:23:16.315907
10	2	10	2	completed	2025-08-18 10:47:27.327598	2025-08-18 10:50:06.840355	\N	2025-08-18 10:50:06.840355	\N	2025-08-18 10:47:27.328692	2025-08-18 10:47:27.328694
22	4	16	4	completed	2025-08-18 20:23:16.274697	2025-08-24 21:25:35.985051	\N	2025-08-24 21:25:35.985051	\N	2025-08-18 20:23:16.315906	2025-08-18 20:23:16.315906
11	2	11	2	completed	2025-08-18 11:27:04.755416	2025-08-18 11:27:15.456568	\N	2025-08-18 11:27:15.456568	\N	2025-08-18 11:27:04.756457	2025-08-18 11:27:04.756459
45	27	16	4	completed	2025-08-18 20:23:16.308016	2025-08-24 21:25:35.985051	\N	2025-08-24 21:25:35.985051	\N	2025-08-18 20:23:16.315924	2025-08-18 20:23:16.315924
44	26	16	4	completed	2025-08-18 20:23:16.306486	2025-08-24 21:25:35.985051	\N	2025-08-24 21:25:35.985051	\N	2025-08-18 20:23:16.315923	2025-08-18 20:23:16.315923
21	3	16	4	completed	2025-08-18 20:23:16.273111	2025-08-24 21:25:35.985051	\N	2025-08-24 21:25:35.985051	\N	2025-08-18 20:23:16.315903	2025-08-18 20:23:16.315905
3	1	6	3	completed	2025-08-16 06:53:11.562745	2025-08-19 08:09:35.920837	\N	2025-08-19 08:09:35.920837	\N	2025-08-16 06:53:11.565741	2025-08-16 06:53:11.565743
4	2	6	3	completed	2025-08-16 06:53:11.564493	2025-08-19 08:09:35.920837	\N	2025-08-19 08:09:35.920837	\N	2025-08-16 06:53:11.565743	2025-08-16 06:53:11.565744
82	2	22	2	completed	2025-08-20 19:57:42.870081	2025-08-21 00:03:49.669854	\N	2025-08-21 00:03:49.669854	\N	2025-08-20 19:57:42.871197	2025-08-20 19:57:42.871197
12	1	12	3	completed	2025-08-18 11:56:55.578483	2025-08-18 13:00:14.409279	\N	2025-08-18 13:00:14.409279	\N	2025-08-18 11:56:55.582723	2025-08-18 11:56:55.582726
13	2	12	3	completed	2025-08-18 11:56:55.580176	2025-08-18 13:00:14.409279	\N	2025-08-18 13:00:14.409279	\N	2025-08-18 11:56:55.582726	2025-08-18 11:56:55.582727
51	1	17	2	completed	2025-08-19 14:29:54.715927	2025-08-19 14:30:20.553398	\N	2025-08-19 14:30:20.553398	\N	2025-08-19 14:29:54.716955	2025-08-19 14:29:54.716957
9	2	9	3	completed	2025-08-18 09:54:59.252752	2025-08-21 09:56:52.011099	\N	2025-08-21 09:56:52.011099	\N	2025-08-18 09:54:59.253937	2025-08-18 09:54:59.25394
52	1	18	2	completed	2025-08-20 05:53:21.589782	2025-08-20 05:55:11.390567	\N	2025-08-20 05:55:11.390567	\N	2025-08-20 05:53:21.590724	2025-08-20 05:53:21.590726
54	2	19	2	completed	2025-08-20 07:38:01.987672	2025-08-20 07:43:36.418043	\N	2025-08-20 07:43:36.418043	\N	2025-08-20 07:38:01.988806	2025-08-20 07:38:01.988808
15	176	12	2	stopped	2025-08-18 13:47:15.500746	2025-08-18 13:47:21.0123	2025-08-18 14:47:21.0123	\N	unsubscribed	2025-08-18 13:47:15.502044	2025-08-18 13:47:15.502046
16	176	13	1	active	2025-08-18 14:08:53.078062	\N	2025-08-18 14:08:53.078052	\N	\N	2025-08-18 14:08:53.07903	2025-08-18 14:08:53.079033
56	2	20	2	completed	2025-08-20 09:42:16.34459	2025-08-20 09:46:44.185623	\N	2025-08-20 09:46:44.185623	\N	2025-08-20 09:42:16.345006	2025-08-20 09:42:16.345008
17	177	13	2	completed	2025-08-18 14:24:34.565396	2025-08-18 14:24:56.400547	\N	2025-08-18 14:24:56.400547	\N	2025-08-18 14:24:34.566444	2025-08-18 14:24:34.566446
18	1	14	2	completed	2025-08-18 14:49:44.631282	2025-08-18 14:49:48.366791	\N	2025-08-18 14:49:48.366791	\N	2025-08-18 14:49:44.634401	2025-08-18 14:49:44.634403
19	2	14	2	completed	2025-08-18 14:49:44.633082	2025-08-18 14:49:48.366791	\N	2025-08-18 14:49:48.366791	\N	2025-08-18 14:49:44.634404	2025-08-18 14:49:44.634405
20	1	15	2	completed	2025-08-18 15:01:56.782612	2025-08-18 15:02:08.60117	\N	2025-08-18 15:02:08.60117	\N	2025-08-18 15:01:56.783425	2025-08-18 15:01:56.783427
85	211	23	3	active	2025-08-22 12:10:55.68678	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731703	2025-08-22 12:10:55.731703
86	213	23	3	active	2025-08-22 12:10:55.688617	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731704	2025-08-22 12:10:55.731704
125	299	24	2	active	2025-08-28 02:27:44.150332	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212096	2025-08-28 02:27:44.212097
123	297	24	2	active	2025-08-28 02:27:44.147325	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212095	2025-08-28 02:27:44.212095
127	301	24	2	active	2025-08-28 02:27:44.153322	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212098	2025-08-28 02:27:44.212098
124	298	24	2	active	2025-08-28 02:27:44.14882	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212096	2025-08-28 02:27:44.212096
126	300	24	2	active	2025-08-28 02:27:44.151823	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212097	2025-08-28 02:27:44.212097
121	295	24	2	active	2025-08-28 02:27:44.144245	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212082	2025-08-28 02:27:44.212093
122	296	24	2	active	2025-08-28 02:27:44.145765	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212094	2025-08-28 02:27:44.212094
84	205	23	3	active	2025-08-22 12:10:55.685154	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731702	2025-08-22 12:10:55.731702
87	214	23	3	active	2025-08-22 12:10:55.69019	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731704	2025-08-22 12:10:55.731705
91	220	23	3	active	2025-08-22 12:10:55.696178	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731708	2025-08-22 12:10:55.731708
88	215	23	3	active	2025-08-22 12:10:55.691708	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731705	2025-08-22 12:10:55.731706
90	217	23	3	active	2025-08-22 12:10:55.694652	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731707	2025-08-22 12:10:55.731707
83	204	23	3	active	2025-08-22 12:10:55.683436	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731699	2025-08-22 12:10:55.731701
89	216	23	3	active	2025-08-22 12:10:55.693187	2025-08-25 12:15:35.280366	2025-08-28 12:15:35.280366	\N	\N	2025-08-22 12:10:55.731706	2025-08-22 12:10:55.731706
94	210	23	3	active	2025-08-22 12:10:55.700657	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.73171	2025-08-22 12:10:55.73171
92	206	23	3	active	2025-08-22 12:10:55.697645	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.731708	2025-08-22 12:10:55.731709
93	208	23	3	active	2025-08-22 12:10:55.699192	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.731709	2025-08-22 12:10:55.731709
68	191	21	4	completed	2025-08-20 13:38:02.33432	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354082	2025-08-20 13:38:02.354082
74	178	21	4	completed	2025-08-20 13:38:02.343321	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354086	2025-08-20 13:38:02.354086
75	188	21	4	completed	2025-08-20 13:38:02.344813	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354087	2025-08-20 13:38:02.354087
73	200	21	4	completed	2025-08-20 13:38:02.341823	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354085	2025-08-20 13:38:02.354086
76	189	21	4	completed	2025-08-20 13:38:02.346298	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354087	2025-08-20 13:38:02.354088
53	2	18	2	completed	2025-08-20 06:03:59.807103	2025-08-20 06:07:38.770963	\N	2025-08-20 06:07:38.770963	\N	2025-08-20 06:03:59.808692	2025-08-20 06:03:59.808694
55	1	20	2	completed	2025-08-20 08:20:24.290567	2025-08-20 08:23:25.90034	\N	2025-08-20 08:23:25.90034	\N	2025-08-20 08:20:24.290887	2025-08-20 08:20:24.290889
47	29	16	4	completed	2025-08-18 20:23:16.310832	2025-08-24 21:25:35.985051	\N	2025-08-24 21:25:35.985051	\N	2025-08-18 20:23:16.315925	2025-08-18 20:23:16.315926
46	28	16	4	completed	2025-08-18 20:23:16.309393	2025-08-24 21:25:35.985051	\N	2025-08-24 21:25:35.985051	\N	2025-08-18 20:23:16.315925	2025-08-18 20:23:16.315925
50	32	16	4	completed	2025-08-18 20:23:16.315123	2025-08-25 00:04:25.324411	\N	2025-08-25 00:04:25.324411	\N	2025-08-18 20:23:16.315928	2025-08-18 20:23:16.315928
49	31	16	4	completed	2025-08-18 20:23:16.313714	2025-08-25 00:04:25.324411	\N	2025-08-25 00:04:25.324411	\N	2025-08-18 20:23:16.315927	2025-08-18 20:23:16.315928
48	30	16	4	completed	2025-08-18 20:23:16.31231	2025-08-25 00:04:25.324411	\N	2025-08-25 00:04:25.324411	\N	2025-08-18 20:23:16.315926	2025-08-18 20:23:16.315927
100	229	23	3	active	2025-08-22 12:10:55.710652	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.731714	2025-08-22 12:10:55.731714
99	224	23	3	active	2025-08-22 12:10:55.708888	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.731713	2025-08-22 12:10:55.731714
96	218	23	3	active	2025-08-22 12:10:55.703801	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.731711	2025-08-22 12:10:55.731711
95	212	23	3	active	2025-08-22 12:10:55.70213	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.73171	2025-08-22 12:10:55.731711
69	192	21	4	completed	2025-08-20 13:38:02.335825	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354082	2025-08-20 13:38:02.354083
71	195	21	4	completed	2025-08-20 13:38:02.338793	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354084	2025-08-20 13:38:02.354084
70	193	21	4	completed	2025-08-20 13:38:02.337337	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354083	2025-08-20 13:38:02.354083
72	199	21	4	completed	2025-08-20 13:38:02.340347	2025-08-27 12:27:00.065711	\N	2025-08-27 12:27:00.065711	\N	2025-08-20 13:38:02.354084	2025-08-20 13:38:02.354085
66	187	21	4	completed	2025-08-20 13:38:02.331205	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.35408	2025-08-20 13:38:02.35408
80	194	21	4	completed	2025-08-20 13:38:02.352461	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.354091	2025-08-20 13:38:02.354091
61	179	21	4	completed	2025-08-20 13:38:02.322825	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.354076	2025-08-20 13:38:02.354076
98	223	23	3	active	2025-08-22 12:10:55.70714	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.731713	2025-08-22 12:10:55.731713
97	219	23	3	active	2025-08-22 12:10:55.70548	2025-08-25 12:37:13.097528	2025-08-28 12:37:13.097528	\N	\N	2025-08-22 12:10:55.731712	2025-08-22 12:10:55.731712
107	209	23	3	active	2025-08-22 12:10:55.721807	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.731719	2025-08-22 12:10:55.73172
104	225	23	3	active	2025-08-22 12:10:55.717019	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.731717	2025-08-22 12:10:55.731717
108	207	23	3	active	2025-08-22 12:10:55.723434	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.73172	2025-08-22 12:10:55.73172
106	221	23	3	active	2025-08-22 12:10:55.720262	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.731719	2025-08-22 12:10:55.731719
101	230	23	3	active	2025-08-22 12:10:55.712287	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.731715	2025-08-22 12:10:55.731715
105	222	23	3	active	2025-08-22 12:10:55.718591	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.731718	2025-08-22 12:10:55.731718
103	227	23	3	active	2025-08-22 12:10:55.715459	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.731716	2025-08-22 12:10:55.731717
77	190	21	4	completed	2025-08-20 13:38:02.347759	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.354088	2025-08-20 13:38:02.354089
79	198	21	4	completed	2025-08-20 13:38:02.350917	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.35409	2025-08-20 13:38:02.35409
78	196	21	4	completed	2025-08-20 13:38:02.349262	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.354089	2025-08-20 13:38:02.354089
63	182	21	4	completed	2025-08-20 13:38:02.326549	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.354078	2025-08-20 13:38:02.354078
60	184	21	4	completed	2025-08-20 13:38:02.321197	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.354075	2025-08-20 13:38:02.354076
62	180	21	4	completed	2025-08-20 13:38:02.324936	2025-08-27 12:48:47.335385	\N	2025-08-27 12:48:47.335385	\N	2025-08-20 13:38:02.354077	2025-08-20 13:38:02.354077
59	181	21	4	completed	2025-08-20 13:38:02.319474	2025-08-27 13:10:39.304089	\N	2025-08-27 13:10:39.304089	\N	2025-08-20 13:38:02.354072	2025-08-20 13:38:02.354074
65	186	21	4	completed	2025-08-20 13:38:02.329668	2025-08-27 13:10:39.304089	\N	2025-08-27 13:10:39.304089	\N	2025-08-20 13:38:02.354079	2025-08-20 13:38:02.35408
64	183	21	4	completed	2025-08-20 13:38:02.328138	2025-08-27 13:10:39.304089	\N	2025-08-27 13:10:39.304089	\N	2025-08-20 13:38:02.354079	2025-08-20 13:38:02.354079
67	185	21	4	completed	2025-08-20 13:38:02.332752	2025-08-27 13:10:39.304089	\N	2025-08-27 13:10:39.304089	\N	2025-08-20 13:38:02.354081	2025-08-20 13:38:02.354081
128	302	24	2	active	2025-08-28 02:27:44.154939	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212098	2025-08-28 02:27:44.212099
102	231	23	3	active	2025-08-22 12:10:55.713841	2025-08-25 13:00:43.580014	2025-08-28 13:00:43.580014	\N	\N	2025-08-22 12:10:55.731716	2025-08-22 12:10:55.731716
111	226	23	3	active	2025-08-22 12:10:55.72812	2025-08-26 00:06:05.450637	2025-08-29 00:06:05.450637	\N	\N	2025-08-22 12:10:55.731722	2025-08-22 12:10:55.731723
110	228	23	3	active	2025-08-22 12:10:55.726562	2025-08-26 00:06:05.450637	2025-08-29 00:06:05.450637	\N	\N	2025-08-22 12:10:55.731722	2025-08-22 12:10:55.731722
109	203	23	3	active	2025-08-22 12:10:55.724955	2025-08-26 00:06:05.450637	2025-08-29 00:06:05.450637	\N	\N	2025-08-22 12:10:55.731721	2025-08-22 12:10:55.731721
129	303	24	2	active	2025-08-28 02:27:44.156599	2025-08-28 02:52:23.888118	2025-08-31 02:52:23.888118	\N	\N	2025-08-28 02:27:44.212099	2025-08-28 02:27:44.2121
133	307	24	2	active	2025-08-28 02:27:44.162817	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212102	2025-08-28 02:27:44.212102
138	312	24	2	active	2025-08-28 02:27:44.170716	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212105	2025-08-28 02:27:44.212106
134	308	24	2	active	2025-08-28 02:27:44.164384	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212103	2025-08-28 02:27:44.212103
130	304	24	2	active	2025-08-28 02:27:44.158122	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.2121	2025-08-28 02:27:44.2121
136	310	24	2	active	2025-08-28 02:27:44.167611	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212104	2025-08-28 02:27:44.212104
132	306	24	2	active	2025-08-28 02:27:44.161332	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212101	2025-08-28 02:27:44.212102
131	305	24	2	active	2025-08-28 02:27:44.159805	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212101	2025-08-28 02:27:44.212101
135	309	24	2	active	2025-08-28 02:27:44.165886	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212103	2025-08-28 02:27:44.212104
137	311	24	2	active	2025-08-28 02:27:44.169193	2025-08-28 03:16:26.629877	2025-08-31 03:16:26.629877	\N	\N	2025-08-28 02:27:44.212105	2025-08-28 02:27:44.212105
139	313	24	2	active	2025-08-28 02:27:44.172301	2025-08-28 03:39:21.476541	2025-08-31 03:39:21.476541	\N	\N	2025-08-28 02:27:44.212106	2025-08-28 02:27:44.212106
140	314	24	1	active	2025-08-28 02:27:44.173809	\N	2025-08-28 02:27:44.173801	\N	\N	2025-08-28 02:27:44.212107	2025-08-28 02:27:44.212107
141	315	24	1	active	2025-08-28 02:27:44.175445	\N	2025-08-28 02:27:44.175434	\N	\N	2025-08-28 02:27:44.212108	2025-08-28 02:27:44.212108
142	316	24	1	active	2025-08-28 02:27:44.17692	\N	2025-08-28 02:27:44.176912	\N	\N	2025-08-28 02:27:44.212108	2025-08-28 02:27:44.212109
143	317	24	1	active	2025-08-28 02:27:44.178594	\N	2025-08-28 02:27:44.178585	\N	\N	2025-08-28 02:27:44.212109	2025-08-28 02:27:44.212109
144	318	24	1	active	2025-08-28 02:27:44.180138	\N	2025-08-28 02:27:44.18013	\N	\N	2025-08-28 02:27:44.21211	2025-08-28 02:27:44.21211
145	319	24	1	active	2025-08-28 02:27:44.181577	\N	2025-08-28 02:27:44.181569	\N	\N	2025-08-28 02:27:44.21211	2025-08-28 02:27:44.212111
146	320	24	1	active	2025-08-28 02:27:44.183078	\N	2025-08-28 02:27:44.18307	\N	\N	2025-08-28 02:27:44.212111	2025-08-28 02:27:44.212111
147	321	24	1	active	2025-08-28 02:27:44.184626	\N	2025-08-28 02:27:44.184618	\N	\N	2025-08-28 02:27:44.212112	2025-08-28 02:27:44.212112
148	322	24	1	active	2025-08-28 02:27:44.186133	\N	2025-08-28 02:27:44.186125	\N	\N	2025-08-28 02:27:44.212112	2025-08-28 02:27:44.212113
149	323	24	1	active	2025-08-28 02:27:44.187677	\N	2025-08-28 02:27:44.187669	\N	\N	2025-08-28 02:27:44.212113	2025-08-28 02:27:44.212113
150	324	24	1	active	2025-08-28 02:27:44.189169	\N	2025-08-28 02:27:44.18916	\N	\N	2025-08-28 02:27:44.212114	2025-08-28 02:27:44.212114
151	325	24	1	active	2025-08-28 02:27:44.190655	\N	2025-08-28 02:27:44.190647	\N	\N	2025-08-28 02:27:44.212114	2025-08-28 02:27:44.212115
152	326	24	1	active	2025-08-28 02:27:44.19217	\N	2025-08-28 02:27:44.192162	\N	\N	2025-08-28 02:27:44.212115	2025-08-28 02:27:44.212116
153	327	24	1	active	2025-08-28 02:27:44.193656	\N	2025-08-28 02:27:44.193647	\N	\N	2025-08-28 02:27:44.212116	2025-08-28 02:27:44.212116
154	328	24	1	active	2025-08-28 02:27:44.195204	\N	2025-08-28 02:27:44.195194	\N	\N	2025-08-28 02:27:44.212117	2025-08-28 02:27:44.212117
155	329	24	1	active	2025-08-28 02:27:44.196745	\N	2025-08-28 02:27:44.196736	\N	\N	2025-08-28 02:27:44.212117	2025-08-28 02:27:44.212118
156	330	24	1	active	2025-08-28 02:27:44.198306	\N	2025-08-28 02:27:44.198298	\N	\N	2025-08-28 02:27:44.212118	2025-08-28 02:27:44.212118
157	331	24	1	active	2025-08-28 02:27:44.199821	\N	2025-08-28 02:27:44.199813	\N	\N	2025-08-28 02:27:44.212119	2025-08-28 02:27:44.212119
158	332	24	1	active	2025-08-28 02:27:44.201301	\N	2025-08-28 02:27:44.201293	\N	\N	2025-08-28 02:27:44.21212	2025-08-28 02:27:44.21212
159	333	24	1	active	2025-08-28 02:27:44.202736	\N	2025-08-28 02:27:44.202729	\N	\N	2025-08-28 02:27:44.21212	2025-08-28 02:27:44.212121
160	334	24	1	active	2025-08-28 02:27:44.204237	\N	2025-08-28 02:27:44.204229	\N	\N	2025-08-28 02:27:44.212121	2025-08-28 02:27:44.212121
161	335	24	1	active	2025-08-28 02:27:44.205683	\N	2025-08-28 02:27:44.205675	\N	\N	2025-08-28 02:27:44.212122	2025-08-28 02:27:44.212122
162	336	24	1	active	2025-08-28 02:27:44.207171	\N	2025-08-28 02:27:44.207162	\N	\N	2025-08-28 02:27:44.212122	2025-08-28 02:27:44.212123
163	337	24	1	active	2025-08-28 02:27:44.208634	\N	2025-08-28 02:27:44.208627	\N	\N	2025-08-28 02:27:44.212123	2025-08-28 02:27:44.212123
164	338	24	1	active	2025-08-28 02:27:44.210167	\N	2025-08-28 02:27:44.210159	\N	\N	2025-08-28 02:27:44.212125	2025-08-28 02:27:44.212126
120	294	24	2	active	2025-08-28 02:27:44.142686	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.212081	2025-08-28 02:27:44.212081
114	288	24	2	active	2025-08-28 02:27:44.133651	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.212077	2025-08-28 02:27:44.212077
119	293	24	2	active	2025-08-28 02:27:44.141166	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.21208	2025-08-28 02:27:44.212081
112	286	24	2	active	2025-08-28 02:27:44.130439	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.212073	2025-08-28 02:27:44.212075
117	291	24	2	active	2025-08-28 02:27:44.138146	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.212079	2025-08-28 02:27:44.212079
118	292	24	2	active	2025-08-28 02:27:44.139679	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.21208	2025-08-28 02:27:44.21208
116	290	24	2	active	2025-08-28 02:27:44.136649	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.212078	2025-08-28 02:27:44.212078
113	287	24	2	active	2025-08-28 02:27:44.132121	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.212076	2025-08-28 02:27:44.212076
115	289	24	2	active	2025-08-28 02:27:44.13517	2025-08-28 02:29:44.162783	2025-08-31 02:29:44.162783	\N	\N	2025-08-28 02:27:44.212077	2025-08-28 02:27:44.212078
165	339	25	1	active	2025-08-28 17:16:42.309907	\N	2025-08-28 17:16:42.309897	\N	\N	2025-08-28 17:16:42.310823	2025-08-28 17:16:42.310825
\.


--
-- Data for Name: leads; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.leads (id, email, first_name, last_name, company, title, phone, status, created_at, updated_at, website, industry) FROM stdin;
286	siamtherapy2022@gmail.com	\N	\N	Siam Therapy Cardiff	\N	029 2047 0063	active	2025-08-28 02:08:00.93646	2025-08-28 02:08:00.936462	https://www.siamtherapy-cardiff.co.uk/	\N
2	ryan@vezra.co.uk						active	2025-08-11 20:35:30.814544	2025-08-11 20:35:30.814549		
1	ellislad@yahoo.co.uk	Ryan	Ellis	Vezra UK LTD	CEO		active	2025-08-08 20:27:57.783748	2025-08-12 09:15:25.700205	https://wegetyou.online	\N
3	belperfleurflorist@yahoo.com	\N	\N	Fleur Florists	\N	01773 825772	active	2025-08-12 21:16:56.839492	2025-08-12 21:16:56.839495	http://www.fleurfloristbelper.co.uk/	florist
4	melbourneflorists@hotmail.com	\N	\N	Melbourne Florist and Gifts	\N	01332 865645	active	2025-08-12 21:16:56.849329	2025-08-12 21:16:56.849332	https://www.melbourneflorist.co.uk/	florist
5	theflowershopbeeston@hotmail.com	\N	\N	The Flower Shop Beeston	\N	0115 837 5800	active	2025-08-12 21:16:56.850904	2025-08-12 21:16:56.850905	https://www.theflowershopbeeston.co.uk/	florist
6	mapperley.blooms@gmail.com	\N	\N	Mapperley Blooms	\N	0115 784 8251	active	2025-08-12 21:16:56.852497	2025-08-12 21:16:56.852498	https://mapperley-blooms.square.site/	florist
7	thefloristnottingham@outlook.com	\N	\N	The Florist Nottingham	\N	07720 874464	active	2025-08-12 21:16:56.854272	2025-08-12 21:16:56.854274	https://www.thefloristnottingham.co.uk/	florist
8	artofflowers18@hotmail.com	\N	\N	Art of Flowers	\N	0115 947 3009	active	2025-08-12 21:16:56.855739	2025-08-12 21:16:56.85574	http://artofflowersnottingham.co.uk/	florist
9	garlandsofllandaff9@gmail.com	\N	\N	Garlands	\N	029 2056 3121	active	2025-08-12 21:16:56.85732	2025-08-12 21:16:56.857321	https://garlandsofllandaff.co.uk/	florist
10	blodautlws@gmail.com	\N	\N	Blodau Tlws	\N	029 2069 2999	active	2025-08-12 21:16:56.858812	2025-08-12 21:16:56.858814	http://www.blodau-tlws.co.uk/	florist
11	aboutflowers2021@outlook.com	\N	\N	About Flowers	\N	029 2076 5775	active	2025-08-12 21:16:56.860369	2025-08-12 21:16:56.860371	http://www.aboutflowers.co.uk/	florist
12	wildmeadowfloral@hotmail.com	\N	\N	Wild Meadow Floral	\N	07815 057987	active	2025-08-12 21:16:56.861831	2025-08-12 21:16:56.861832	http://www.wildmeadowfloral.co.uk/	florist
13	afscustomersrv@gmail.com	\N	\N	AFS Artificial Floral Supplies	\N	029 2081 4088	active	2025-08-12 21:16:56.863293	2025-08-12 21:16:56.863295	https://www.artificialfloralsupplies.co.uk/	florist
14	sweetpeonyfloral@gmail.com	\N	\N	Sweet Peony Florist	\N	029 2070 7935	active	2025-08-12 21:16:56.864787	2025-08-12 21:16:56.864789	https://www.sweetpeonyfloral.co.uk/	florist
15	jasandfloral@hotmail.com	\N	\N	Jas and Floral	\N	07341 283564	active	2025-08-12 21:16:56.866338	2025-08-12 21:16:56.866341	https://www.jasandfloral.co.uk/	florist
16	impallari@gmail.com	\N	\N	Poppies Florist Bournemouth.	\N	01202 593959	active	2025-08-12 21:16:56.867809	2025-08-12 21:16:56.867811	http://www.poppiesfloristbournemouth.co.uk/	florist
17	littleandbloom@gmail.com	\N	\N	Little & Bloom	\N	07958 041579	active	2025-08-12 21:16:56.869365	2025-08-12 21:16:56.869367	http://littleandbloom.com/	florist
18	newleaf.floristry@yahoo.com	\N	\N	New leaf floristry	\N	07507 577923	active	2025-08-12 21:16:56.870816	2025-08-12 21:16:56.870817	http://www.newleaffloristry.net/	florist
19	anita.blushingbloom@gmail.com	\N	\N	Blushing Bloom and OceanFlora	\N	07818 436894	active	2025-08-12 21:16:56.872283	2025-08-12 21:16:56.872285	http://www.blushingbloom.co.uk/	florist
20	fullbloomhayling@gmail.com	\N	\N	Full Bloom Hayling	\N	023 9200 7462	active	2025-08-12 21:16:56.873707	2025-08-12 21:16:56.873709	https://tillyangel.wixsite.com/fullbloom	florist
21	sherwoodfloristhavant@outlook.com	\N	\N	Sherwood Florist	\N	023 9247 7182	active	2025-08-12 21:16:56.875182	2025-08-12 21:16:56.875183	https://www.sherwood-florist.com/	florist
22	lullabellesfloristry@yahoo.com	\N	\N	Lullabelles Floristry	\N	07510 206812	active	2025-08-12 21:16:56.876625	2025-08-12 21:16:56.876627	http://lullabellesfloristry.me/	florist
23	clairesfloristry@gmail.com	\N	\N	Claire’s Floristry and Tea Room	\N	07801 579000	active	2025-08-12 21:16:56.878063	2025-08-12 21:16:56.878065	https://clairesfloristry.co.uk/	florist
24	annatnkn@gmail.com	\N	\N	Blooms The Florist Emsworth	\N	01243 278122	active	2025-08-12 21:16:56.879454	2025-08-12 21:16:56.879456	http://www.bloomstheflorist.co.uk/	florist
287	microgen@gmail.com	\N	\N	Massage & Hot Stone	\N	07984 137038	active	2025-08-28 02:08:00.938277	2025-08-28 02:08:00.938279	https://massageinwales.com/	\N
26	lilyvioletmayflowers@gmail.com	\N	\N	Lily Violet May Florist	\N	07809 484735	active	2025-08-12 21:16:56.882339	2025-08-12 21:16:56.882341	http://www.lilyvioletmay.co.uk/	florist
27	theflowershopbristol@gmail.com	\N	\N	The Flower Shop	\N	0117 942 0050	active	2025-08-12 21:16:56.883676	2025-08-12 21:16:56.883677	http://www.theflowershopbristol.com/	florist
28	tigerlilyflowersbristol@gmail.com	\N	\N	Tiger Lily	\N	01454 856737	active	2025-08-12 21:16:56.885066	2025-08-12 21:16:56.885067	https://www.tigerlilyflowers.co.uk/	florist
29	amiegara_fleurtationsflorist@hotmail.com	\N	\N	Fleurtations Florist Bristol	\N	0117 967 0367	active	2025-08-12 21:16:56.886364	2025-08-12 21:16:56.886366	http://www.fleurtations-bristol.co.uk/	florist
30	flowersbyallauk@gmail.com	\N	\N	Flowers By Alla	\N	07931 355657	active	2025-08-12 21:16:56.887711	2025-08-12 21:16:56.887713	http://flowersbyalla.com/	florist
31	edithwilmotflorist@gmail.com	\N	\N	Edith Wilmot Bristol Florist	\N	0117 950 8589	active	2025-08-12 21:16:56.889082	2025-08-12 21:16:56.889083	http://www.edithwilmot.co.uk/	florist
32	rebeccapaddick1@gmail.com, dongaysflorist@gmail.com	\N	\N	Don Gay’s Florist Bristol	\N	0117 977 6964	active	2025-08-12 21:16:56.890459	2025-08-12 21:16:56.890461	https://www.dongaysflorist.co.uk/	florist
176	test-2e5aae@test.mailgenius.com	James	Jones	Grade 92 Barbering Southbourne	Director		unsubscribed	2025-08-18 13:47:02.095553	2025-08-18 14:07:41.390498	http://www.grade92.co.uk/	Healthcare
177	test-30a6dd@test.mailgenius.com	Brian	Jones	BJ Guitars			active	2025-08-18 14:24:23.297349	2025-08-18 14:24:23.297352		
181	oceanfitnesspoole@gmail.com	\N	\N	Ocean Fitness	\N	07919 286623	active	2025-08-20 05:34:40.491908	2025-08-20 05:34:40.49191	http://www.oceanfitnesspoole.co.uk/	personal trainer
184	nperformance14@gmail.com	\N	\N	NPerformance Personal Training Poole	\N	07557 258440	active	2025-08-20 05:34:40.496543	2025-08-20 05:34:40.496545	http://www.nperformance.co.uk/	personal trainer
179	cordellwilsonpt@hotmail.com	Cordell	Wilson	Cordell Wilson Personal Training		07533 762344	active	2025-08-20 05:34:40.488589	2025-08-20 05:36:22.147708	http://www.cordellwilsonpersonaltraining.com/	personal trainer
180	fitnfreshpt@gmail.com	Dan		Fit N Fresh Coaching			active	2025-08-20 05:34:40.490274	2025-08-20 05:37:24.363567	http://www.fitnfreshcoaching.com/	personal trainer
182	boxing.223rocfitness@outlook.com			223ROC Boxing		07500 345331	active	2025-08-20 05:34:40.493503	2025-08-20 05:38:01.172863	http://www.223rocboxing.co.uk/	personal trainer
183	philiplea.pt@gmail.com	Phil	Lea	Phil Lea Personal Training		07450 217065	active	2025-08-20 05:34:40.495068	2025-08-20 05:38:23.610835	http://www.philleafitness.com/	personal trainer
186	janecoxfitness@gmail.com	Jane	Cox	Jane Cox Personal Trainer/Gym		07930 219022	active	2025-08-20 05:34:40.499635	2025-08-20 05:38:44.651747	https://www.janecoxfitness.co.uk/	personal trainer
187	kardosanaszt@gmail.com	Anastazia	Kardos	ZiaFitLife		07491 782358	active	2025-08-20 05:34:40.501152	2025-08-20 05:40:08.675026	http://www.ziafitlife.com/	personal trainer
185	james.addis15@gmail.com	James	Addis	Addis Lifestyle & Fitness		07888 804575	active	2025-08-20 05:34:40.498134	2025-08-20 05:47:43.65002	https://addislifestylefitness.co.uk/	personal trainer
25	christmastreesportsmouth@gmail.com			Christmas trees Portsmouth		07720 244954	active	2025-08-12 21:16:56.880916	2025-08-20 15:14:19.113431	http://www.nichelocal.co.uk/services/Portsmouth/Christmas-Trees/Christmas-Trees-Portsmoutn.html	florist
191	enbfitness@hotmail.com	\N	\N	ENB Fitness	\N	07711 049232	active	2025-08-20 05:34:40.506873	2025-08-20 05:34:40.506875	https://www.enbfitness.co.uk/	personal trainer
192	motivationfitnesspt@hotmail.com	\N	\N	motivationfitnesspt	\N	07577 566920	active	2025-08-20 05:34:40.508334	2025-08-20 05:34:40.508336	https://motivationfitnesspt.co.uk/	personal trainer
193	carolpatrick52@hotmail.com	\N	\N	The Cabin Personal Training	\N	07957 728829	active	2025-08-20 05:34:40.509736	2025-08-20 05:34:40.509738	http://www.personaltrainerhavant.com/	personal trainer
195	fjk.fitness@gmail.com	\N	\N	FJK Fitness	\N	07796 267314	active	2025-08-20 05:34:40.512689	2025-08-20 05:34:40.512691	http://www.fjkfitness.co.uk/	personal trainer
199	snlfitness@outlook.com	\N	\N	SNL Fitness	\N	07775 941215	active	2025-08-20 05:34:40.518671	2025-08-20 05:34:40.518673	http://snlfitness.com/	personal trainer
200	newphysique@outlook.com	\N	\N	New Physique Personal Training	\N	07704 325934	active	2025-08-20 05:34:40.520122	2025-08-20 05:34:40.520124	http://newphysique.wixsite.com/newphysique	personal trainer
178	jesswilsonpersonaltraining@gmail.com	Jess	Wilson	Jess Wilson PT		07555 564292	active	2025-08-20 05:34:40.480427	2025-08-20 05:35:25.344395	https://www.jesswilsonpt.com/	personal trainer
188	markfieldfitness@gmail.com	Mark	Field	Mark Field Fitness - Mobile Personal Trainers		07889 734755	active	2025-08-20 05:34:40.502531	2025-08-20 05:40:34.418479	http://www.markfieldfitness.com/	personal trainer
189	lbart88@gmail.com	Leon		LeonBFitness		07868 215097	active	2025-08-20 05:34:40.504119	2025-08-20 05:40:56.535055	https://leonbfitness.com/	personal trainer
190	jackwilliamsonpt@outlook.com	Jack	Williamson	Jack Williamson PT		07540 397422	active	2025-08-20 05:34:40.50547	2025-08-20 05:41:16.490131	https://www.jackwilliamsonpt.com/	personal trainer
196	stu_seymour@hotmail.com	Stuart	Seymour	Motiv8 Personal Training		07929 593598	active	2025-08-20 05:34:40.514152	2025-08-20 05:43:27.796061	http://www.motiv8personaltraining.co.uk/	personal trainer
198	getfitwithkimmy@outlook.com	Kimmy		Get fit with Kimmy personal trainer		07402 583746	active	2025-08-20 05:34:40.517246	2025-08-20 05:44:26.101081	https://www.getfitwithkimmy.com/	personal trainer
194	lmgadams.lmga@gmail.com	Lee	Adams	Dedicated Coaching		07890 918674	active	2025-08-20 05:34:40.511194	2025-08-20 05:45:57.981665	http://www.dedicatedcoaching.co.uk/	personal trainer
204	gem_photography_@hotmail.com	\N	\N	Gem Photography	\N	07775 437240	active	2025-08-20 18:55:46.663311	2025-08-20 18:55:46.663315	https://www.gem-photography.uk/	photographer
205	elen.studio@gmail.com	\N	\N	Elen Studio Photography	\N	07733 158177	active	2025-08-20 18:55:46.664889	2025-08-20 18:55:46.664891	http://elenstudiophotography.com/	photographer
211	75hudsonphotography@gmail.com	\N	\N	75Hudson Photographer	\N	07481 256164	active	2025-08-20 18:55:46.673528	2025-08-20 18:55:46.67353	http://75hudsonphotography.com/	photographer
213	memoryboxmedia@gmail.com	\N	\N	Memory Box Weddings	\N	07450 693924	active	2025-08-20 18:55:46.676763	2025-08-20 18:55:46.676765	http://www.memoryboxweddings.co.uk/	photographer
214	kerilovell@outlook.com	\N	\N	Lovell Photography	\N	07517 089483	active	2025-08-20 18:55:46.678239	2025-08-20 18:55:46.678241	http://www.lovellpictures.com/	photographer
215	nuriasernaphotography@gmail.com	\N	\N	Nuria Serna Photography	\N	07918 023068	active	2025-08-20 18:55:46.679626	2025-08-20 18:55:46.679628	http://nuriasernaphotography.com/	photographer
216	balancephotographycardiff@gmail.com	\N	\N	Balance Photography Studio	\N	07918 031214	active	2025-08-20 18:55:46.681078	2025-08-20 18:55:46.68108	https://www.balancephotographystudio.com/	photographer
217	frontrowphotographycardiff@gmail.com	\N	\N	Front Row Photography Cardiff	\N	07904 783334	active	2025-08-20 18:55:46.68242	2025-08-20 18:55:46.682422	https://frontrowphotographyuk.com/	photographer
220	mustardfoxphotography@gmail.com	\N	\N	Mustard Fox Photography	\N	07852 000677	active	2025-08-20 18:55:46.686668	2025-08-20 18:55:46.68667	http://mustardfoxphotography.co.uk/	photographer
206	clivestapleton.photography@gmail.com	Clive	Stapleton	Clive Stapleton Photography		07944 665086	active	2025-08-20 18:55:46.666351	2025-08-22 00:49:19.246571	http://clivestapleton-photography.co.uk/	photographer
208	kamila.malitka.photography@gmail.com	Kamila	Malitka	Kamila Malitka Photography		07508 015300	active	2025-08-20 18:55:46.669333	2025-08-22 00:49:52.704625	https://kamilamalitkaphotography.com/	photographer
210	gemmapoyzerphoto@gmail.com	Gemma	Poyzer	Gemma Poyzer Photography		07519 223542	active	2025-08-20 18:55:46.672184	2025-08-22 00:50:27.960838	http://www.gemmapoyzer.co.uk/	photographer
212	RYHALLPHOTO@GMAIL.COM	Ryan	Hall	Ryan Hall Studios – Beauty Product & Personal Branding Photography		0115 779 9712	active	2025-08-20 18:55:46.674936	2025-08-22 00:50:50.336658	http://www.ryanhallstudios.com/	photographer
218	alexmillsphotographic@gmail.com	Alex	Mills	Alex Mills Photographic		07949 712813	active	2025-08-20 18:55:46.683858	2025-08-22 00:51:18.784852	https://www.alexmillsphotographic.com/	photographer
219	katedaveyphotography@gmail.com	Kate	Davey	Kate Davey Photography		07916 311582	active	2025-08-20 18:55:46.68527	2025-08-22 00:51:46.706195	http://www.katedaveyphotography.com/	photographer
223	mariecarden72@yahoo.com	Marie	Carden	Marie carden photography		07805 133169	active	2025-08-20 18:55:46.690804	2025-08-22 00:52:21.756746	https://is.gd/mariecardenphotography	photographer
224	harveymillsphoto@gmail.com	Harvey	Mills	Harvey Mills Photography		07591 966288	active	2025-08-20 18:55:46.692218	2025-08-22 00:52:40.564852	https://harveymills.com/home	photographer
229	marekbomba@gmail.com	Marek	Bomba	Marek Bomba Photography		07843 877969	active	2025-08-20 18:55:46.699121	2025-08-22 00:53:22.251406	https://www.mbomba.com/	photographer
230	shaunhenry_60@hotmail.com	Shaun	Henrt	Shaun Henry Photography		07544 199844	active	2025-08-20 18:55:46.700454	2025-08-22 00:53:40.268817	http://shaunhenryphotography.uk/	photographer
231	mattjgutteridge@gmail.com	Matt	Gutteridge	Matt Gutteridge Photography		07896 961479	active	2025-08-20 18:55:46.702249	2025-08-22 00:54:06.378843	http://www.mattgutteridge.co.uk/	photographer
227	daniellemsteward@gmail.com	Danielle	Steward	D&J Photography		07760 318823	active	2025-08-20 18:55:46.696403	2025-08-22 00:54:37.239349	http://www.dandjphotography.co.uk/	photographer
232	deenathaimassageandreiki.uk@gmail.com	\N	\N	Deena Thai Massage & Reiki Healing Centre	\N	07577 858319	active	2025-08-27 20:52:10.133279	2025-08-27 20:52:10.133281	https://www.thaimassageandreikihealingcentre.co.uk/	\N
225	irinagsphoto@gmail.com	Irina	Gaveika-Subashov	Irina GS Photography		07939 147313	active	2025-08-20 18:55:46.693558	2025-08-22 01:06:23.385336	http://www.irinagsphoto.co.uk/	photographer
222	rozpikephoto@gmail.com	Roz 	Pike	Roz Pike Photography		07808 084876	active	2025-08-20 18:55:46.689439	2025-08-22 00:55:27.875846	http://www.rozpike.com/	photographer
221	rosalynjayphotography@gmail.com	Rosalyn	Jay	Rosalyn Jay photography		07772 909412	active	2025-08-20 18:55:46.688109	2025-08-22 00:55:49.200588	http://www.rosalynjayphotography.co.uk/	photographer
209	lucyelizwarner@gmail.com	Lucy	Warner	Lucyewarner Photography		07515 052086	active	2025-08-20 18:55:46.670717	2025-08-22 00:58:50.006129	http://www.lucyewarner.com/	photographer
207	beaulouisephotography@gmail.com	Jane		Beau-Louise Photography			active	2025-08-20 18:55:46.667743	2025-08-22 00:59:38.841413	https://www.beau-louisephotography.co.uk/	photographer
203	ian.irphoto@gmail.com	Ian	Richardson	Ian Richardson Photography		07469 253580	active	2025-08-20 18:55:46.659264	2025-08-22 01:00:50.877932	https://www.irphoto.co.uk/	photographer
228	mo.photography.film@gmail.com	Mo	Mahmoud	Mo Photography & Film		07722 956343	active	2025-08-20 18:55:46.697766	2025-08-22 01:04:42.519009	https://www.moweddingphotographyuk.com/	photographer
226	amkryukov@gmail.com	Anna	Martin	Anna Martin Photography		07512 823737	active	2025-08-20 18:55:46.69502	2025-08-22 01:05:51.054859	https://annamartinphotography.com/	photographer
288	sarahdaviestherapies@gmail.com	\N	\N	Sarah Davies Therapies	\N	07983 806042	active	2025-08-28 02:08:00.939954	2025-08-28 02:08:00.939956	http://www.sarahdaviestherapies.com/	\N
289	soultreetherapies@gmail.com	\N	\N	SoulTree Therapies	\N	07864 179859	active	2025-08-28 02:08:00.94151	2025-08-28 02:08:00.941512	http://soultreetherapies.co.uk/	\N
290	dakotatherapies@gmail.com	\N	\N	Dakota Therapies	\N	07986 316398	active	2025-08-28 02:08:00.942852	2025-08-28 02:08:00.942854	http://dakotatherapies.com/	\N
291	prawannathaitherapy@gmail.com	\N	\N	Prawanna Thai Therapy	\N	01446 679874	active	2025-08-28 02:08:00.944294	2025-08-28 02:08:00.944296	http://www.prawannathaitherapy.co.uk/	\N
292	toeishaw@gmail.com	\N	\N	7 sunny thai massage	\N	07720 782274	active	2025-08-28 02:08:00.945667	2025-08-28 02:08:00.945669	https://www.7sunnythaimassage.com/	\N
293	yurtinthecitycollective@gmail.com	\N	\N	Yurt in the City	\N	07733 047336	active	2025-08-28 02:08:00.947085	2025-08-28 02:08:00.947087	http://www.yurtinthecity.co.uk/	\N
294	masagetherapycymru@gmail.com, massagetherapycymru@gmail.com	\N	\N	Sport Massage Therapy Cymru	\N	07735 177801	active	2025-08-28 02:08:00.948477	2025-08-28 02:08:00.948479	http://www.sporttherapycymru.com/	\N
295	thicha.thaibeautymassage@outlook.com	\N	\N	Thicha Thai Beauty Massage Cardiff	\N	029 2297 2031	active	2025-08-28 02:08:00.949895	2025-08-28 02:08:00.949897	https://www.thichathai.co.uk/	\N
296	divathaimassageandbeauty@gmail.com	\N	\N	Diva Thai Massage & Beauty	\N	07984 601122	active	2025-08-28 02:08:00.951325	2025-08-28 02:08:00.951326	https://divathaimassage.co.uk/	\N
297	cardiffsportsclinic@gmail.com	\N	\N	Sports Massage Cardiff	\N	029 2021 5762	active	2025-08-28 02:08:00.952775	2025-08-28 02:08:00.952777	https://www.cardiffsportsclinic.com/	\N
298	attivamassagetherapy@outlook.com	\N	\N	Attiva Massage Therapy	\N	07960 755165	active	2025-08-28 02:08:00.954222	2025-08-28 02:08:00.954223	https://www.fresha.com/a/attiva-massage-therapy-cardiff-18-norbury-road-sui5iayt	\N
299	massagetherapywinchester@gmail.com	\N	\N	Massage Therapy Winchester	\N	07752 623234	active	2025-08-28 02:08:00.955602	2025-08-28 02:08:00.955603	http://www.massagetherapywinchester.com/	\N
300	zoepeaholisticmassage@gmail.com	\N	\N	Zoe Holistic Massage	\N	\N	active	2025-08-28 02:08:00.956956	2025-08-28 02:08:00.956958	https://www.zoe-holisticmassage.co.uk/	\N
301	bodybestchiropractic@gmail.com	\N	\N	BodyBest Chiropractic Winchester	\N	07483 829798	active	2025-08-28 02:08:00.958441	2025-08-28 02:08:00.958443	https://bodybestchiropractic.co.uk/	\N
302	angela.kendall.work@gmail.com	\N	\N	Yew Hill Therapy - Bowen and Soft Tissue Therapy	\N	07789 790703	active	2025-08-28 02:08:00.95982	2025-08-28 02:08:00.959822	http://www.yewhilltherapy.co.uk/	\N
303	calmpalms7@gmail.com	\N	\N	calmpalms infant massage	\N	07979 193569	active	2025-08-28 02:08:00.961205	2025-08-28 02:08:00.961206	http://www.calmpalms.co.uk/	\N
304	kimhaydentherapies@gmail.com	\N	\N	Hayden Therapies	\N	07881 850758	active	2025-08-28 02:08:00.962506	2025-08-28 02:08:00.962508	http://haydentherapies.com/	\N
305	revive.clinicalmassage@outlook.com	\N	\N	Revive Clinical Massage and Sports Massage Therapy	\N	\N	active	2025-08-28 02:08:00.963951	2025-08-28 02:08:00.963953	http://www.reviveclinicalmassage.co.uk/	\N
306	thaimassagebygussanova@gmail.com	\N	\N	Thaimassagebygussanova	\N	07514 791179	active	2025-08-28 02:08:00.965469	2025-08-28 02:08:00.965471	http://thaimassagebygussanova.co.uk/	\N
307	jamie.a.gough1@gmail.com	\N	\N	Jamie Gough Soft Tissue Massage	\N	07747 002413	active	2025-08-28 02:08:00.966834	2025-08-28 02:08:00.966836	http://www.jamiegoughsportsmassage.co.uk/	\N
308	winchesterreception@gmail.com	\N	\N	Winchester Spine Centre	\N	01962 843242	active	2025-08-28 02:08:00.968231	2025-08-28 02:08:00.968232	http://www.winchesterchiropractor.com/	\N
309	sportsmassagecf@gmail.com	\N	\N	PB Sports Therapy	\N	07900 926393	active	2025-08-28 02:08:00.969574	2025-08-28 02:08:00.969575	http://pb-sportsmassage.co.uk/	\N
310	nwintonlakemassage@gmail.com, wintonlakemassage@gmail.com	\N	\N	WintonLake Massage Therapy Bournemouth	\N	07951 823899	active	2025-08-28 02:08:00.970902	2025-08-28 02:08:00.970904	http://www.wintonlakemassage.co.uk/?utm_source=google&utm_medium=wix_google_business_profile&utm_campaign=15155778044247500781	\N
311	touchofthai.uk@gmail.com	\N	\N	Touch Of Thai Massage	\N	07471 766592	active	2025-08-28 02:08:00.972324	2025-08-28 02:08:00.972326	https://www.touchofthai.co.uk/	\N
312	massagechom2099@gmail.com	\N	\N	Chom Traditional Thai Massage Therapy	\N	07478 686399	active	2025-08-28 02:08:00.974312	2025-08-28 02:08:00.974314	http://www.chommassage.co.uk/	\N
313	soulserenityspa11@gmail.com	\N	\N	Soul Serenity the Crystal Spa (holistic therapies, crystal shop and training centre)	\N	07899 876886	active	2025-08-28 02:08:00.975678	2025-08-28 02:08:00.975679	http://soulserenityspa.co.uk/	\N
314	preeratimassage@gmail.com, ​preeratimassage@gmail.com	\N	\N	Preerati Massage	\N	07481 626566	active	2025-08-28 02:08:00.977056	2025-08-28 02:08:00.977058	https://www.preeratimassage.com/	\N
315	shoresoothe@outlook.com	\N	\N	Shore Soothe Massage & Reflexology	\N	\N	active	2025-08-28 02:08:00.978321	2025-08-28 02:08:00.978322	http://www.shoresoothemassage.com/	\N
316	dorsetjuniortriathlonhub@gmail.com	\N	\N	Tracy Cook Sports Therapy	\N	07834 194872	active	2025-08-28 02:08:00.979658	2025-08-28 02:08:00.97966	http://tracycooksportstherapy.co.uk/	\N
317	themassageman0@gmail.com	\N	\N	The Massage Man	\N	07814 611923	active	2025-08-28 02:08:00.981027	2025-08-28 02:08:00.981028	http://www.themassageman.co.uk/	\N
318	mcmullanmt@gmail.com	\N	\N	McMullan Massage Therapy Fareham	\N	07793 535643	active	2025-08-28 02:08:00.982295	2025-08-28 02:08:00.982296	http://www.mcmullanmt.com/	\N
319	fitnesswithsharna@gmail.com	\N	\N	Recovery and Relaxation	\N	07488 710248	active	2025-08-28 02:08:00.98364	2025-08-28 02:08:00.983642	http://www.recoveryandrelaxation.com/	\N
320	peace.harmony.studio@gmail.com	\N	\N	Peace & Harmony	\N	07442 824385	active	2025-08-28 02:08:00.984947	2025-08-28 02:08:00.984948	http://www.peaceharmonystudio.co.uk/	\N
321	mindfulmomentsw@gmail.com	\N	\N	Mindful Moments Wellbeing	\N	07419 299993	active	2025-08-28 02:08:00.986273	2025-08-28 02:08:00.986275	https://mindfulmomentswellbeing.com/	\N
322	leahbethfitness@hotmail.com	\N	\N	Leah Beth Fitness	\N	\N	active	2025-08-28 02:08:00.987621	2025-08-28 02:08:00.987623	http://leahbethfitness.square.site/	\N
323	makana.massagetherapy@gmail.com	\N	\N	Makana Massage Therapy	\N	07561 027554	active	2025-08-28 02:08:00.989035	2025-08-28 02:08:00.989037	https://www.makanamassagetherapy.co.uk/	\N
324	freethespiritmassagehealing@gmail.com	\N	\N	Free the spirit massage and healing	\N	07809 437017	active	2025-08-28 02:08:00.990312	2025-08-28 02:08:00.990314	http://www.freethespiritmassagehealing.com/	\N
325	danparham2@gmail.com	\N	\N	DP Health and Fitness	\N	07585 508611	active	2025-08-28 02:08:00.991664	2025-08-28 02:08:00.991666	http://www.dphealthandfitness.co.uk/	\N
326	bristolmassageandreflexology@gmail.com	\N	\N	Bristol Massage and Reflexology	\N	07951 567174	active	2025-08-28 02:08:00.993033	2025-08-28 02:08:00.993035	https://www.bristolmassageandreflexology.co.uk/	\N
327	lloydmassagetreatments@gmail.com	\N	\N	Lloyd Massage Treatments	\N	07482 973634	active	2025-08-28 02:08:00.994313	2025-08-28 02:08:00.994315	https://lloydmassagetreatm.wixsite.com/my-site	\N
328	bristolcitymassagetherapy@gmail.com	\N	\N	Bristol City Massage Therapy	\N	07748 719714	active	2025-08-28 02:08:00.995686	2025-08-28 02:08:00.995688	https://www.bristolcitymassagetherapy.com/	\N
329	deeptissuemassagebristol@gmail.com	\N	\N	Deep Tissue Massage Bristol	\N	07866 127919	active	2025-08-28 02:08:00.997042	2025-08-28 02:08:00.997044	http://www.deeptissuemassagebristol.com/	\N
330	thaismilesspa@gmail.com	\N	\N	Thai Smiles Spa - Bristol - Patchway	\N	07492 296556	active	2025-08-28 02:08:00.998383	2025-08-28 02:08:00.998385	https://www.thaismilesspa.co.uk/	\N
331	info.driftawaytherapies@gmail.com	\N	\N	Drift Away Wellness	\N	07875 406582	active	2025-08-28 02:08:01.000064	2025-08-28 02:08:01.000065	https://driftawaywellness.mytreatwell.co.uk/	\N
332	swaymassage@gmail.com, lauramidgley@gmail.com	\N	\N	Sway Massage	\N	\N	active	2025-08-28 02:08:01.001315	2025-08-28 02:08:01.001317	http://www.swaymassage.co.uk/	\N
333	massagepainawayfeelbetter@gmail.com	\N	\N	Massage Pain Away	\N	07980 804650	active	2025-08-28 02:08:01.002603	2025-08-28 02:08:01.002605	https://www.massagepainaway.co.uk/?utm_source=google&utm_medium=wix_google_business_profile&utm_campaign=8449177952114589724	\N
334	tessarosemassage@gmail.com	\N	\N	Tessa Rose Massage	\N	07466 028165	active	2025-08-28 02:08:01.003926	2025-08-28 02:08:01.003928	http://tessarosemassage.co.uk/	\N
335	gillonmassage@gmail.com	\N	\N	Callum Gillon Massage and Mobile Massage	\N	07946 427826	active	2025-08-28 02:08:01.005261	2025-08-28 02:08:01.005262	http://www.gillonmassage.com/	\N
336	massagemanbrs@gmail.com	\N	\N	Massage Man Bristol	\N	07795 663620	active	2025-08-28 02:08:01.006553	2025-08-28 02:08:01.006555	http://www.massagemanbristol.com/	\N
337	edwinapereiramassage@gmail.com	\N	\N	Embody Restore Massage	\N	07752 334197	active	2025-08-28 02:08:01.007916	2025-08-28 02:08:01.007918	http://embodyrestore.com/	\N
338	flowmotiontherapies@gmail.com	\N	\N	Flow Motion Wellbeing - Emilie Bailey	\N	07928 675721	active	2025-08-28 02:08:01.009255	2025-08-28 02:08:01.009257	https://flowmotionwellbeing.com/	\N
339	test-2b7a27@test.mailgenius.com			Siam therapy			active	2025-08-28 17:15:35.895425	2025-08-28 17:15:35.895427	https://www.siamtherapy-cardiff.co.uk/	
\.


--
-- Data for Name: link_clicks; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.link_clicks (id, tracking_id, campaign_lead_id, sequence_email_id, original_url, ip_address, user_agent, referer, clicked_at, created_at, lead_sequence_id) FROM stdin;
1	seq_1_6_bf7d6838	\N	1	https://wegetyou.online/domain-email	192.168.128.1	Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0		2025-08-15 14:20:17.094769	2025-08-15 14:20:17.094772	\N
\.


--
-- Data for Name: sending_profiles; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.sending_profiles (id, name, sender_name, sender_title, sender_company, sender_email, sender_phone, sender_website, signature, is_default, created_at, updated_at, schedule_enabled, schedule_days, schedule_time_from, schedule_time_to, schedule_timezone) FROM stdin;
2	Ryan Ellis	Ryan	Founder	We Get You Online	ryan@wegetyouonline.co.uk		https://wegetyouonline.co.uk	Best Regards,\nRyan\nFounder | WeGetYouOnline.co.uk\nHttps://wegetyouonline.co.uk	t	2025-08-12 08:37:57.202666	2025-08-12 08:37:57.20267	t	1,2,3,4,5	09:00:00	17:00:00	Europe/London
\.


--
-- Data for Name: sequence_emails; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.sequence_emails (id, lead_sequence_id, step_id, status, sent_at, opens, clicks, tracking_pixel_id, created_at, subject, content) FROM stdin;
12	6	10	sent	2025-08-16 12:43:57.171464	0	0	seq_6_10_11e77822	2025-08-16 12:44:02.450122	Boosting [their company]s Online Presence	<p>Dear [Name],<br>\n</p><p><br>\nI was browsing [their company]'s website and noticed how innovative your business is. I’m Ryan, the founder of WeGetYou.Online, and I believe we can collaborate to grow your online presence even further.<br>\n</p><p><br>\nOur team specializes in enhancing businesses' digital reach, ensuring that your unique offerings are effectively communicated to your target audience. We can help elevate [their company]'s online image with our customized strategies.<br>\n</p><p><br>\nI'd love to have a brief chat to discuss how we can specifically support [their company]. When would be a convenient time for you?<br>\n</p><p><br>\nLooking forward to your response.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online <br>\nHttps://wegetyou.online</p>
1	1	6	sent	2025-08-15 14:18:04.766054	1	1	seq_1_6_bf7d6838	2025-08-15 14:18:04.802447	\N	\N
75	25	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:30:21.5972	Enhancing The Florist Nottinghams Digital Presence	Good morning,\n\nI was captivated by the vibrant floral arrangements displayed on The Florist Nottingham's website. The attention to detail in each design is truly remarkable. \n\nI'm Ryan, the founder of WeGetYou.Online, and I believe we can help elevate your digital presence. Our professional domain branded email service can provide a more streamlined and professional image for your brand, matching the elegance of your floral designs.\n\nI'm sure you receive numerous emails daily from clients and suppliers, and having a branded email can ensure your communications stand out in their inboxes. It adds a layer of credibility that generic email addresses might not offer.\n\nHow about exploring how a branded email could strengthen The Florist Nottingham’s online presence and business communications? \n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
386	140	37	failed	\N	0	0	\N	2025-08-28 09:31:01.434559	\N	\N
387	140	37	failed	\N	0	0	\N	2025-08-28 09:36:55.342724	\N	\N
3	1	7	sent	2025-08-15 22:05:23.880396	0	0	seq_1_7_8ad232b1	2025-08-15 22:05:23.898336	\N	\N
6	2	6	sent	2025-08-15 22:05:23.880396	0	0	seq_2_6_82867deb	2025-08-15 22:05:36.406782	\N	\N
4	1	7	sent	2025-08-15 22:05:26.532436	0	0	seq_1_7_008277df	2025-08-15 22:05:26.550448	\N	\N
388	140	37	failed	\N	0	0	\N	2025-08-28 09:42:54.631894	\N	\N
389	140	37	failed	\N	0	0	\N	2025-08-28 09:49:02.129846	\N	\N
5	2	6	sent	2025-08-15 22:05:22.815337	1	0	seq_2_6_c0d7b6d2	2025-08-15 22:05:28.826498	\N	\N
2	1	7	sent	2025-08-15 22:05:22.815337	1	0	seq_1_7_a44d5e93	2025-08-15 22:05:22.849425	\N	\N
390	140	37	failed	\N	0	0	\N	2025-08-28 09:55:07.630896	\N	\N
8	2	7	sent	2025-08-16 07:08:38.007695	0	0	seq_2_7_2fce20c0	2025-08-16 07:08:38.056715	Boost Their Companys Online Presence - A Different Approach	<p>Dear [Name],<br>\n</p><p><br>\nI hope this email finds you well. I recently reached out about how WeGetYou.Online could enhance their company's digital footprint, but I didn't hear back from you.<br>\n</p><p><br>\nI understand that you have a lot on your plate, so I'll keep this brief. Our tailored solutions can make a significant difference to your online visibility, driving more traffic to your website and creating growth opportunities.<br>\n</p><p><br>\nIf you have 15 minutes to spare this week, I'd be delighted to provide a free personalized online strategy for their company. It's a no-obligation offer, just some insights that might be helpful for your business.<br>\n</p><p><br>\nLooking forward to your response.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
391	140	37	failed	\N	0	0	\N	2025-08-28 10:01:12.123191	\N	\N
10	4	8	sent	2025-08-16 07:08:38.007695	0	0	seq_4_8_ae03d097	2025-08-16 07:08:50.885083	Boosting Their Companys Online Presence Just Got Easier!	<p>Dear [Name],<br>\n</p><p><br>\nI hope this email finds you well. I came across "Their Company" and was impressed by the work you do. I believe we could help you amplify your online presence further to reach more potential clients. <br>\n</p><p><br>\nAt WeGetYou.Online, we specialize in creating dynamic digital strategies that not only heighten visibility but also drive engagement and conversions. We'd love to offer you a free consultation to demonstrate how we can tailor our services to fit your specific needs.<br>\n</p><p><br>\nPlease reply if you're interested in exploring this further or visit us directly at <a href="https://wegetyou.online.">https://wegetyou.online.</a><br>\n</p><p><br>\nLooking forward to the possibility of working together.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
9	3	8	sent	2025-08-16 07:08:38.007695	1	0	seq_3_8_e9972cad	2025-08-16 07:08:46.140831	Boost Vezra UK LTDs online presence with WeGetYou.Online	<p>Dear Ryan,<br>\n</p><p><br>\nI hope this message finds you well. I came across Vezra UK LTD and was intrigued by your business model. <br>\n</p><p><br>\nAt WeGetYou.Online, we specialize in strengthening the online presence of companies just like yours. Our team of experts can help Vezra UK LTD reach its full potential in the digital space, increasing visibility and customer engagement. <br>\n</p><p><br>\nI would love the opportunity to discuss how we can customize our solutions for you. Can we schedule a call next week?<br>\n</p><p><br>\nLooking forward to hearing from you soon.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
14	6	11	sent	2025-08-16 13:44:07.257362	1	0	seq_6_11_b3f71952	2025-08-16 13:44:13.447169	Enhancing [their company]s Digital Impact - Lets Discuss	<p>Dear [Name],</p>\n\n<p>I hope this message finds you well. I recently reached out to discuss how WeGetYou.Online can help amplify [their company]'s online presence. I understand how busy schedules can get and perhaps my previous email might have slipped through the cracks.</p>\n\n<p>We have recently achieved great results for businesses similar to yours in your industry, with our tailored digital strategies. Our approach could be just the right fit for [their company], ensuring your innovative solutions reach a broader, more targeted audience. I'd love to share some insights and explore possibilities that could benefit your online growth.</p>\n\n<p>Could we possibly arrange a brief call at a time that suits you? I'm confident that our discussion will be worth your time.</p>\n\n<p>Looking forward to your response.</p>\n\n<p>Best Regards,</p>\n<p>Ryan</p>\n<p>Founder | WeGetYou.Online</p>\n<p>Https://wegetyou.online</p>
7	2	6	sent	2025-08-15 22:05:26.532436	1	0	seq_2_6_8b7d2e77	2025-08-15 22:05:41.964119	\N	\N
15	7	12	sent	2025-08-18 08:39:29.222786	1	0	seq_7_12_d200c6a6	2025-08-18 08:39:29.229695	Boosting Vezras Online Visibility: Lets Make it Happen!	<p>Dear Ryan,<br>\n</p><p><br>\nI hope this email finds you well. My name is Ryan too, and I'm the founder of WeGetYou.Online. We're a team of digital marketing professionals dedicated to helping businesses like Vezra UK LTD to amplify their online presence.<br>\n</p><p><br>\nWe've visited your website and believe that with our tailored SEO strategies and web designs, we can significantly increase your site's traffic and conversion rates.<br>\n</p><p><br>\nI'd love to discuss how we can work together to achieve this. Would you be available for a quick call next week?<br>\n</p><p><br>\nLooking forward to hearing from you.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
18	8	13	sent	2025-08-18 09:39:41.802866	0	0	seq_8_13_c832c7ad	2025-08-18 09:39:49.51981	Boost [their company]s Online Growth Potential	<p>Dear [their name],</p>\n\n<p>I hope this message finds you well. I understand that you might be busy, so I will keep this brief. I had reached out earlier about how WeGetYou.Online could help enhance [their company]'s online presence and I believe there is significant potential for growth.</p>\n\n<p>Our team has done some preliminary research and we've identified a few areas on your website that, with some minor tweaks, could greatly increase your visibility, customer engagement, and sales. We'd love to share these insights with you and discuss how we might be able to help you fully realize your company's online potential.</p>\n\n<p>Could we set up a short call to discuss this further? I am convinced that these insights will prove valuable for your business.</p>\n\n<p>Looking forward to your response.</p>\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
13	5	11	sent	2025-08-16 13:44:07.257362	1	0	seq_5_11_3a82371c	2025-08-16 13:44:07.263211	Enhancing Vezras Digital Footprint - Lets Discuss The Way Forward	<p>Dear Ryan,</p>\n\n<p>Hope this message finds you well. A few days ago, I reached out regarding the opportunity to collaborate and maximize Vezra UK LTD's online visibility. I hope you had some time to consider our offer.</p>\n\n<p>Our team at WeGetYou.Online is passionate about helping successful businesses such as yours establish a stronger digital presence. With our in-depth understanding of the digital landscape, we can tailor digital strategies that align with Vezra's vision and goals.</p>\n\n<p>I believe a brief discussion about your current online strategy could be beneficial. Let me know of a convenient time for you, and we can further discuss how we can help Vezra reach its online potential.</p>\n\n<p>Looking forward to your positive response.</p>\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
11	5	10	sent	2025-08-16 12:43:57.171464	1	0	seq_5_10_7523c007	2025-08-16 12:43:57.17788	Unleashing Vezras Online Potential with WeGetYou.Online	<p>Dear Ryan,<br>\n</p><p><br>\nAs a fellow CEO, I understand the need for a robust online presence. At Vezra UK LTD, you've built a fantastic business. Let's ensure it's portrayed that way online. <br>\n</p><p><br>\nWeGetYou.Online specializes in taking businesses like yours and transforming their online profiles. We offer a comprehensive package from website design, SEO optimization to social media management. You focus on running Vezra, and we'll focus on getting you online.<br>\n</p><p><br>\nInterested? Let's schedule a call to discuss how we can help Vezra reach its online potential.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
76	26	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:30:40.308651	Enhancing the Art of Flowers Digital Presence	Hello,\n\nI recently visited the Art of Flowers website and was truly taken by the magnificent floral arrangements you offer. Your dedication to crafting stunning designs for weddings, funerals, and special occasions is evident.\n\nI am Ryan, the founder of WeGetYou.Online. We specialize in creating professional domain branded emails that can help businesses like yours further cultivate their online identity. \n\nConsidering the elegant and professional aesthetic of your website, I believe that having a domain branded email could further enhance your online presence. It's a simple yet effective way to communicate your brand's commitment to professionalism and quality in every interaction with your customers.\n\nIf you are interested in learning more about how a domain-branded email could benefit Art of Flowers, I would love to chat with you. \n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
16	8	12	sent	2025-08-18 08:39:29.222786	1	0	seq_8_12_5926c92a	2025-08-18 08:39:35.050772	Lets ignite your online presence, [their company]!	<p>Dear [their name],<br>\n</p><p><br>\nI hope this email finds you well. I was exploring [their company]'s website and I am impressed with what you've built. <br>\n</p><p><br>\nMy name is Ryan, the founder of WeGetYou.Online. We specialize in enhancing online visibility for businesses like yours, helping you reach more potential customers and increase sales. <br>\n</p><p><br>\nI am confident that our strategies can bring value to [their company]. Could we schedule a short call this week to discuss how we can tailor our services to your specific needs?<br>\n</p><p><br>\nLooking forward to hearing from you soon.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
77	27	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:30:56.649743	Elevating Garlands: A Fresh Approach for Your Online Presence	Hello,\n\nAs I was admiring the stunning floral arrangements on your website, I couldn't help but notice the passion and creativity that goes into each of your designs at Garlands. The way you've combined tradition with innovation is truly inspiring.\n\nBeing in the digital age, it's important for businesses like yours to maintain a consistent and professional online image. That's why I'm reaching out today. At WeGetYou.Online, we offer a service that can help you maintain that image by providing you with a professional domain-branded email.\n\nImagine sending and receiving emails from an address that ends in '@garlandsofllandaff.co.uk'. Not only would it look more professional, but it would also reinforce your brand every time you send an email. \n\nIf you're interested in learning more about this, or if you’re looking for other ways to enhance your online presence, I’d love to chat further. \n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
19	9	14	sent	2025-08-18 09:54:59.33936	0	0	seq_9_14_b595a82b	2025-08-18 09:54:59.346163	Transforming Their Companys Digital Presence - Lets Talk!	<p>Dear [Name],<br>\n</p><p><br>\nI hope this message finds you well. I recently came across your company, Their Company, and was impressed by your work in the [Industry]. However, I noticed there is potential to enhance your online visibility.<br>\n</p><p><br>\nMy name is Ryan and I'm the Founder of WeGetYou.Online. We specialize in boosting digital presence and have helped countless businesses in your industry amplify their online reach.<br>\n</p><p><br>\nI'd love to share insights on how we could do the same for Their Company. Would you be open to a brief call next week to discuss this further?<br>\n</p><p><br>\nLooking forward to hearing from you.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
392	140	37	failed	\N	0	0	\N	2025-08-28 10:06:39.491073	\N	\N
17	7	13	sent	2025-08-18 09:39:41.802866	1	0	seq_7_13_f0947810	2025-08-18 09:39:41.817446	Unleashing Vezras Potential: Lets Get You Noticed Online!	<p>Dear Ryan,</p>\n\n<p>I hope this message finds you in good health. I'm reaching out again from WeGetYou.Online, hoping to connect about our previous discussion on enhancing Vezra's online visibility.</p>\n\n<p>We understand the digital landscape can be overwhelming, yet it holds immense potential for businesses like Vezra UK LTD. Our team has helped many companies navigate this terrain and we believe we can do the same for you. We've been studying some top-performing sites in your industry and I'd love to share some insights that could be beneficial for Vezra.</p>\n\n<p>How about we schedule a call sometime next week to delve into this? I'm confident that our expertise can provide a significant boost to your online presence.</p>\n\n<p>Looking forward to your response.</p>\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
20	10	16	sent	2025-08-18 10:50:06.840355	1	0	seq_10_16_b4047073	2025-08-18 10:50:06.870624	Boost Your Online Presence with WeGetYou.Online, there!	<p>Dear there,<br>\n</p><p><br>\nI hope this email finds you well. I came across their company recently, and I was quite impressed by what you have achieved in your industry.<br>\n</p><p><br>\nHowever, I noticed that there is still a vast opportunity for their company to enhance its online presence and attract more visitors.<br>\n</p><p><br>\nAt WeGetYou.Online, we specialize in doing exactly that. With our state-of-the-art tools and experienced team, we can help your business make the most out of the digital world.<br>\n</p><p><br>\nI’d love to share more about how we can tailor our services to fit your specific needs. If this interests you, please let me know a good time for a brief chat.<br>\n</p><p><br>\nLooking forward to potentially working with you.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
78	28	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:31:12.224919	Enhance Blodau Tlwss Digital Presence with a Professional Domain Email	Hello,\n\nI recently visited your website and was thoroughly impressed by the beautiful floral arrangements offered by Blodau Tlws. The passion behind your work is quite evident and it's clear that your unique designs bring a lot of joy to your customers.\n\nAs the Founder of WeGetYou.Online, I believe a professional domain email could further elevate Blodau Tlws's online presence. Such an email address adds credibility to your business, enhances your brand image, and can help build trust with your clientele.\n\nWould you be interested in exploring this opportunity and learning how a professional domain email can contribute to the growth of Blodau Tlws? Our service is easy to use, secure, and designed to meet your business needs.\n\nIf you'd like to learn more, just reply and I'd be happy to provide further information.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
21	11	17	sent	2025-08-18 11:27:15.456568	1	0	seq_11_17_11a05d8f	2025-08-18 11:27:15.472631	Boost Your Online Presence with WeGetYou.Online	<p>Good Morning,<br>\n</p><p><br>\nI hope this email finds you well. I recently came across your business and noticed you're doing a fantastic job. But I believe there's a significant opportunity to amplify your online presence and reach more potential customers.<br>\n</p><p><br>\nI'm Ryan, founder of WeGetYou.Online. Our specialty is helping businesses like yours improve their online visibility, drive more traffic, and ultimately increase revenue. We achieve this by offering personalized digital strategies that align perfectly with your business goals.<br>\n</p><p><br>\nI'd love to discuss how we could potentially collaborate and take your online presence to the next level. If you’re interested, I’d be glad to arrange a no-obligation consultation at your earliest convenience.<br>\n</p><p><br>\nLooking forward to your response.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
102	4	9	sent	2025-08-19 08:09:35.920837	1	0	seq_4_9_84d1f219	2025-08-19 08:09:39.599034	Following up on our conversation	<p>Hi there,</p><p>I wanted to follow up on my previous message.</p><p>Best regards,<br>Ryan</p>
22	12	18	sent	2025-08-18 11:57:05.096823	0	0	seq_12_18_05c8b4db	2025-08-18 11:57:05.102611	Boost Vezra’s Credibility with a Professional Email Address	<p>Dear Ryan,<br>\n</p><p><br>\nI came across your company Vezra UK LTD while looking for businesses that are making a significant impact in their respective fields. I must say, I was impressed with your commitment to enabling businesses to establish their online presence.<br>\n</p><p><br>\nHowever, I noticed that, like many businesses, you might be using a free email account. While this seems like a cost-effective solution at the start, studies show that 80% of people are less likely to contact a business with a free email address, perceiving it as less professional.<br>\n</p><p><br>\nThat's where we come in. At WeGetYou.Online, we provide businesses with professional email accounts that enhance their credibility. Unlike Google, we don't charge per user but for the storage used, allowing for unlimited accounts.<br>\n</p><p><br>\nI invite you to explore how we can help Vezra UK LTD make an even greater impression online. Simply click here: <a href="https://wegetyou.online/domain-email">https://wegetyou.online/domain-email</a><br>\n</p><p><br>\nLooking forward to potentially working with you.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
393	140	37	failed	\N	0	0	\N	2025-08-28 10:12:49.963953	\N	\N
23	12	18	sent	2025-08-18 11:57:07.202668	0	0	seq_12_18_8ee70732	2025-08-18 11:57:07.211642	Keep Vezra UK LTDs Professional Image Intact with a Custom Email	<p>Dear Ryan,<br>\n</p><p><br>\nHope this message finds you well. I recently had the opportunity to visit your website and was thoroughly impressed by Vezra UK LTD's commitment to providing quality services.<br>\n</p><p><br>\nAs the CEO of a thriving business, I'm sure you understand the importance of first impressions. Imagine your potential clients' reactions when they see 'VezraUKLTD@gmail.com'. A recent study found that 80% of people perceive businesses with free email addresses as less trustworthy. The same people are more likely to engage with a business that uses a professional email address.<br>\n</p><p><br>\nAt WeGetYou.Online, we offer custom email plans tailored to your business needs. Unlike Google and others, we charge for storage used, not per user, allowing you to have unlimited accounts. This is particularly beneficial for a budget-conscious business like yours.<br>\n</p><p><br>\nI invite you to explore our services and see how a custom email address can enhance your business image and trustworthiness. Please click here to find out more: <a href="https://wegetyou.online/domain-email">https://wegetyou.online/domain-email</a><br>\n</p><p><br>\nLooking forward to hearing from you.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
25	13	18	sent	2025-08-18 11:57:07.202668	1	0	seq_13_18_0afdbab4	2025-08-18 11:57:18.138144	Elevate Your Businesss Online Presence with WeGetYou.Online	<p>Good Morning,<br>\n</p><p><br>\nI hope this message finds you well. I noticed that you've been doing an excellent job building your business’s online presence. However, I believe there's an area where we can help you take it a step further.<br>\n</p><p><br>\nAt WeGetYou.Online, we've discovered that many small businesses unknowingly hurt their image with free email accounts such as Gmail or Yahoo. A recent study found that 80% of potential customers deem businesses with free email addresses as unprofessional. <br>\n</p><p><br>\nWe offer a solution by providing professional domain emails that are charged by storage, not by user. This means that you can have unlimited accounts, a cost-effective approach for budget-conscious businesses like yours. <br>\n</p><p><br>\nTo see how this can benefit your business, I invite you to visit <a href="https://wegetyou.online/domain-email.">https://wegetyou.online/domain-email.</a> I believe that with our help, your business can make a stronger first impression and gain the trust of more potential customers. <br>\n</p><p><br>\nLooking forward to hearing from you soon.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
394	140	37	failed	\N	0	0	\N	2025-08-28 10:18:28.429666	\N	\N
395	140	37	failed	\N	0	0	\N	2025-08-28 10:23:52.989386	\N	\N
396	140	37	failed	\N	0	0	\N	2025-08-28 10:30:10.041457	\N	\N
397	140	37	failed	\N	0	0	\N	2025-08-28 10:36:14.720744	\N	\N
24	13	18	sent	2025-08-18 11:57:05.096823	1	0	seq_13_18_50740da7	2025-08-18 11:57:15.505827	Boost Your Business Credibility with a Professional Email Address	<p>Hello,<br>\n</p><p><br>\nAs a business owner, you're likely aware of the importance of first impressions. Did you know your email address plays a significant role in how customers perceive your business? A recent study found that 80% of people are less likely to contact a company with a free email address, such as Gmail, Yahoo, or Outlook. They perceive such businesses as less professional and trustworthy.<br>\n</p><p><br>\nAt WeGetYou.Online, we understand the competitive nature of the online market and the need for small businesses like yours to make a strong first impression. We offer a solution that not only boosts your professional image but is also budget-friendly. Unlike Google and others that charge per user, we offer unlimited accounts and only charge for the storage used.<br>\n</p><p><br>\nTake the first step towards enhancing your business's online presence by clicking here: <a href="https://wegetyou.online/domain-email.">https://wegetyou.online/domain-email.</a> Start enjoying the benefits of a professional email address today.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
79	29	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:31:31.541322	Enhancing About Flowers Online Presence with Branded Email	Hello,\n\nI recently visited your beautiful website, About Flowers, and was impressed by the wide variety of stunning floral arrangements you offer for every occasion.\n\nWhile exploring your site, I noticed that you have not yet leveraged the power of a professional domain branded email. As an expert in this area, I believe that this could contribute significantly to your online presence and credibility. \n\nAt WeGetYou.Online, we specialize in setting up professional domain branded email addresses that match your business domain, http://www.aboutflowers.co.uk/. This can not only enhance your brand's image but also make your communication more memorable and trustworthy to your customers.\n\nWould you be interested in discussing how a professional domain branded email could benefit About Flowers? \n\nJust reply to this email if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
26	12	19	sent	2025-08-18 13:00:14.409279	0	0	seq_12_19_eb07d555	2025-08-18 13:00:14.420207	Enhancing Vezra UK LTDs Online Trustworthiness, One Email at a Time	<p>Dear Ryan,</p>\n\n<p>I hope this email finds you in good health. I am writing to you again in the context of our previous conversation about the importance of a professional email address for Vezra UK LTD. The right email address can significantly influence a potential client's trustworthiness perception, as I'm sure you're aware.</p>\n\n<p>Our services at WeGetYou.Online go beyond just providing a professional email address. We also offer an array of features like premium spam protection, advanced email forwarding, and multi-device compatibility. All these features come without any per-user cost, keeping your budget in check while enhancing your online presence.</p>\n\n<p>If you have a moment, I invite you to find out more about how we can help you build a stronger online reputation: <a href="https://wegetyou.online/domain-email"><a href="https://wegetyou.online/domain-email">https://wegetyou.online/domain-email</a></a></p>\n\n<p>Looking forward to your response.</p>\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
27	13	19	sent	2025-08-18 13:00:14.409279	0	0	seq_13_19_b04e0752	2025-08-18 13:00:25.646233	Secure Your Business’s Reputation with a Professional Email	<p>Dear [Lead's Name],</p>\n\n<p>I trust this email finds you well. I've reached out a couple times recently regarding the potential benefits of a professional email address for your business, and I wanted to provide additional perspective that might resonate with you.</p>\n\n<p>An email address is more than just a communication tool — it's an extension of your brand. A professional email address using your company's domain not only instills trust, but also enhances your credibility. Furthermore, a professional email address helps in SEO ranking which can drive more traffic to your website and ultimately result in more sales.</p>\n\n<p>I encourage you to take a look at more details here: <a href="https://wegetyou.online/domain-email."><a href="https://wegetyou.online/domain-email.">https://wegetyou.online/domain-email.</a></a> I'm confident that a professional email address can help elevate your business in the eyes of your customers.</p>\n\n<p>Looking forward to hearing from you soon.</p>\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
101	3	9	sent	2025-08-19 08:09:35.920837	1	0	seq_3_9_9421c1a9	2025-08-19 08:09:35.93425	Following up on Vezra UK LTD	<p>Hi Ryan,</p><p>I wanted to follow up on my previous message.</p><p>Best regards,<br>Ryan</p>
398	140	37	failed	\N	0	0	\N	2025-08-28 10:41:48.865557	\N	\N
176	86	34	sent	2025-08-22 12:12:39.966876	0	0	1b82d212-d6f2-4681-a95f-288d6a8b3e2c	2025-08-22 12:29:44.928093	Boost client trust with a branded email	Hi there,\n\nMemory Box Weddings caught my eye because your name suggests preserved memories and your photography speaks to authentic moments couples will cherish. I explored memoryboxweddings.co.uk and was impressed by your storytelling approach and the care you bring to albums and keepsakes.\n\nPhotographers are trusted with life’s most meaningful moments, and every touchpoint matters. A branded email strengthens that trust at onboarding, inquiries, and delivery by presenting a consistent, professional image from hello@memoryboxweddings.co.uk rather than a generic address.\n\nAt We Get You Online, we help photographers like you adopt domain-branded emails that align with your site and brand. Beyond aesthetics, it improves clarity, inbox deliverability, and client confidence—often translating into smoother bookings and fewer miscommunications.\n\nIf this sounds useful, you can explore the solution at wegetyouonline.co.uk/domain-email. I’d love to hear what would make this easiest for Memory Box Weddings.\n\nWould you be open to a brief, no-pressure chat? I’m happy to fit around your schedule.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
399	140	37	failed	\N	0	0	\N	2025-08-28 10:47:52.425848	\N	\N
400	140	37	failed	\N	0	0	\N	2025-08-28 10:53:54.547175	\N	\N
401	140	37	failed	\N	0	0	\N	2025-08-28 10:59:55.349697	\N	\N
402	140	37	failed	\N	0	0	\N	2025-08-28 11:05:47.963957	\N	\N
403	140	37	failed	\N	0	0	\N	2025-08-28 11:11:38.349449	\N	\N
404	140	37	failed	\N	0	0	\N	2025-08-28 11:17:14.560958	\N	\N
405	140	37	failed	\N	0	0	\N	2025-08-28 11:23:09.038106	\N	\N
406	140	37	failed	\N	0	0	\N	2025-08-28 11:28:52.047205	\N	\N
407	140	37	failed	\N	0	0	\N	2025-08-28 11:34:29.644488	\N	\N
408	140	37	failed	\N	0	0	\N	2025-08-28 11:40:21.58135	\N	\N
409	140	37	failed	\N	0	0	\N	2025-08-28 11:45:54.507119	\N	\N
410	140	37	failed	\N	0	0	\N	2025-08-28 11:51:46.52368	\N	\N
411	140	37	failed	\N	0	0	\N	2025-08-28 11:57:38.134882	\N	\N
412	140	37	failed	\N	0	0	\N	2025-08-28 12:03:36.03095	\N	\N
413	140	37	failed	\N	0	0	\N	2025-08-28 12:09:40.635374	\N	\N
414	140	37	failed	\N	0	0	\N	2025-08-28 12:15:19.702126	\N	\N
415	140	37	failed	\N	0	0	\N	2025-08-28 12:21:14.752714	\N	\N
416	140	37	failed	\N	0	0	\N	2025-08-28 12:27:23.559193	\N	\N
417	140	37	failed	\N	0	0	\N	2025-08-28 12:32:59.571683	\N	\N
31	15	18	sent	2025-08-18 13:47:21.0123	1	0	seq_15_18_3605b9cb	2025-08-18 13:47:21.026833	Enhance Grade 92 Barberings Online Presence with Professional Email	Hello James,<br><br>I hope this message finds you well. I recently visited your website and was really impressed with the high-quality services your team at Grade 92 Barbering Southbourne provides. You've truly built a commendable brand.<br><br>While exploring your site, I couldn't help but think about the potential benefits a professional email could bring to your thriving business. As you might know, many customers perceive businesses with a professional email as more trustworthy and reliable.<br><br>At WeGetYou.Online, we offer a unique email service tailored to the needs of small businesses like yours. Unlike other providers, we don't charge per user, but for the storage used, allowing you to have unlimited email addresses. This could significantly enhance your online reputation and customer trust.<br><br>I invite you to check out our flexible plans at <a href="https://wegetyou.online/domain-email.">https://wegetyou.online/domain-email.</a> I'd be more than happy to discuss how we can help strengthen your online presence and ensure Grade 92 Barbering Southbourne continues to make an impressive mark.<br><br>Please reply if you'd like to learn more.<br><br>Best Regards,<br>Ryan<br>Founder | WeGetYou.Online<br>Https://wegetyou.online
30	15	18	sent	2025-08-18 13:47:18.302866	1	0	seq_15_18_df8e3a9f	2025-08-18 13:47:18.346561	Elevating Grade 92 Barberings Digital Presence	Hello James,<br><br>I had the pleasure of exploring the Grade 92 Barbering Southbourne website and was quite impressed by the unique services you offer - particularly your signature hot towel shaves. It's clear you're dedicated to providing the best possible experience for your customers.<br><br>However, have you considered the impression your current email address might be leaving with potential clients? Research indicates that 80% of people may hesitate to contact a business using a free email service like Gmail or Yahoo, as it can appear less professional. <br><br>At WeGetYou.Online, we believe your email address should reflect the excellence of your services. That's why we offer domain-specific email addresses that not only enhance your business's professional image but are also budget-friendly.<br><br>If you're interested in learning more about how we can help Grade 92 Barbering Southbourne stand out even more in the digital world, I'd love to chat. You can find more information here: <a href="https://wegetyou.online/domain-email">https://wegetyou.online/domain-email</a> <br><br>Looking forward to hearing from you.<br><br>Best Regards,<br>Ryan<br>Founder | WeGetYou.Online<br>Https://wegetyou.online
47	27	23	sent	2025-08-18 20:25:50.528397	1	0	seq_27_23_537e80fa	2025-08-18 20:26:36.84127	Empower Garlands with a Blooming Online Presence	<p>Dear Garlands Team,<br>\n</p><p><br>\nAs a florist, you bring color and beauty to people's lives every day. At WeGetYou.Online, we strive to do the same - but for your business's online presence. <br>\n</p><p><br>\nWe've admired your work at Garlands, and we think a professional domain-branded email could help your digital growth flourish just like your beautiful arrangements.<br>\n</p><p><br>\nTo learn more about how we can help enhance your brand, please visit wegetyou.online/domain-email. Let's start planting the seeds for your online success.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
103	51	26	sent	2025-08-19 14:30:20.553398	0	0	\N	2025-08-19 14:30:44.569699	Partnership opportunity with Vezra UK LTD	<p>Hi Ryan,</p>\n<p>I hope this message finds you well. I noticed your work at Vezra UK LTD and wanted to reach out about a potential partnership opportunity.</p>\n<p>Would you be open to a brief conversation about how we might be able to help you achieve your business goals?</p>\n<p>Best regards,<br>Ryan<br>Founder<br>WeGetYou.Online</p>
418	140	37	failed	\N	0	0	\N	2025-08-28 12:38:58.620436	\N	\N
419	140	37	failed	\N	0	0	\N	2025-08-28 12:44:43.854618	\N	\N
420	140	37	failed	\N	0	0	\N	2025-08-28 12:50:49.22837	\N	\N
48	28	23	sent	2025-08-18 20:25:50.528397	0	0	seq_28_23_9b54af0e	2025-08-18 20:26:42.766002	Enhancing Blodau Tlws Digital Presence with Branded Emails	<p>Dear Blodau Tlws Team,<br>\n</p><p><br>\nI hope this email finds you well. My name is Ryan, founder of WeGetYou.Online, and I was enamoured by the beautiful floral creations on your website.<br>\n</p><p><br>\nI noticed your business is blooming in the florist industry and I'm reaching out to offer a service that could elevate your digital presence - a professional domain branded email. This not only enhances your brand image but also builds trust with your clients.<br>\n</p><p><br>\nTo learn more about this service and how it can benefit Blodau Tlws, I invite you to visit [wegetyou.online/domain-email](<a href="https://wegetyou.online/domain-email)">https://wegetyou.online/domain-email)</a><br>\n</p><p><br>\nLooking forward to the possibility of helping your beautiful business grow.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\n[Https://wegetyou.online](<a href="https://wegetyou.online)">https://wegetyou.online)</a></p>
421	140	37	failed	\N	0	0	\N	2025-08-28 12:56:24.237091	\N	\N
49	29	23	sent	2025-08-18 20:25:50.528397	0	0	seq_29_23_9ba86683	2025-08-18 20:26:50.451083	Blossom Your Brand with AboutFlowers@YourDomain	<p>Dear About Flowers Team,<br>\n</p><p><br>\nJust as a unique bouquet makes an impression, a personalized domain branded email can do the same for your business. I've been admiring your stunning floral arrangements on your website, and I can't help but imagine the impact of an email address that reflects the same attention to detail.<br>\n</p><p><br>\nAt WeGetYou.Online, we offer professional domain branded emails that enhance your brand's credibility and visibility. Imagine sending emails from YourName@AboutFlowers.co.uk - it's a subtle but effective way to reinforce your brand with every communication.<br>\n</p><p><br>\nTo learn more about how we can help your business make a lasting impression, visit <a href="https://wegetyou.online/domain-email.">https://wegetyou.online/domain-email.</a> I look forward to helping About Flowers bloom online.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
50	30	23	sent	2025-08-18 20:25:50.528397	0	0	seq_30_23_144a7ad4	2025-08-18 20:26:56.074613	Boost Wild Meadow Florals Brand with a Custom Domain Email	<p>Dear Wild Meadow Floral Team,<br>\n</p><p><br>\nI hope this email finds you well. I was fascinated by the stunning floral arrangements on your website and the unique style that sets you apart in the florist industry.<br>\n</p><p><br>\nAs the founder of WeGetYou.Online, I work with companies like yours to strengthen their online presence. A professional, domain-branded email can significantly boost your brand image and credibility. <br>\n</p><p><br>\nWhy not take a moment to explore how a custom email (like info@wildmeadowfloral.co.uk) can enhance your brand? You can learn more about our domain email service at wegetyou.online/domain-email.<br>\n</p><p><br>\nLet's grow your digital footprint together. <br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
422	140	37	failed	\N	0	0	\N	2025-08-28 13:01:53.826868	\N	\N
423	140	37	failed	\N	0	0	\N	2025-08-28 13:07:41.34622	\N	\N
424	140	37	failed	\N	0	0	\N	2025-08-28 13:13:39.644519	\N	\N
425	140	37	failed	\N	0	0	\N	2025-08-28 13:19:07.04231	\N	\N
426	140	37	failed	\N	0	0	\N	2025-08-28 13:25:02.169525	\N	\N
186	103	34	sent	2025-08-22 12:57:45.306676	0	0	bf5138e6-42ff-4346-87a1-22cfb088601e	2025-08-22 12:58:09.313193	Elevate D&J Photography's client trust	Hi Danielle,\n\nI visited D&J Photography's site and was impressed by how your portfolio centers on storytelling and capturing the moments that matter most to clients. In photography, the trust between you and your clients is everything—from the initial inquiry to the final gallery. A branded email address can reinforce that trust from the very first hello.\n\nWe Get You Online helps photographers adopt a professional domain email, so D&J Photography can present a consistent, credible identity (yourname@dandjphotography.co.uk) rather than a generic inbox. That small shift can improve response rates, reassure clients pre-shoot, and strengthen the overall client experience across inquiries, contracts, and galleries.\n\nIf you’re curious, you can explore options at wegetyouonline.co.uk/domain-email. I’d be glad to share a quick, no-pressure overview of how this could fit D&J Photography and boost client confidence. Would you have 15 minutes this week for a brief chat?\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
36	17	20	sent	2025-08-18 14:24:56.400547	0	0	seq_17_20_6870d267	2025-08-18 14:24:56.420958	Enhancing BJ Guitars Online Presence	Hi Brian,\n\nI hope this email finds you well. As a fellow music lover, I've been very impressed with BJ Guitars' commitment to providing quality instruments for your customers.\n\nIn today's digital world, a professional online presence is key to thriving. Unfortunately, many businesses, even successful ones like yours, unknowingly hurt their reputation by using common email addresses from providers like Gmail or Yahoo. \n\nA recent study showed that 80% of customers perceived businesses using these email addresses as less trustworthy. In such a competitive industry, first impressions can make or break a potential customer's decision.\n\nWe at WeGetYou.Online aspire to empower businesses like yours with the tools to compete online. We provide email solutions that allow you to have unlimited email addresses under your own domain, making your business look more professional and trustworthy. Our pricing is based on storage used, not per user, making it an appealing option for budget-conscious businesses like yours.\n\nConsider giving it a shot. You can find more details here: https://wegetyou.online/domain-email.\n\nLet me know if you'd like to learn more. I believe this could be a real game-changer for BJ Guitars.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
104	52	27	sent	2025-08-20 05:55:11.390567	0	0	29e2fba1-afdd-442d-8a10-01827e344fb7	2025-08-20 05:55:20.402246	Elevate Your Personal Training Business with Professional Domain Emails	Hi Ryan,\n\nI hope this email finds you well at Vezra UK LTD. As a CEO, you understand the importance of building trust with your clients. That's why having a professional domain email like info@vezrauk.com can enhance your brand credibility and strengthen your client relationships.\n\nAt WeGetYou.Online, we specialize in providing personalized domain email solutions for businesses like yours. Visit our site at wegetyou.online/domain-email to learn more about how a professional email address can benefit your business success.\n\nTake the first step towards elevating your personal training business by investing in a professional domain email. Click here to explore our services: wegetyou.online/domain-email\n\nLooking forward to helping you establish trust and credibility with your clients through a professional email address.\n\nRyan\nFounder\nWeGetYou.Online\nryan@wegetyou.online
37	18	21	sent	2025-08-18 14:49:48.366791	0	0	\N	2025-08-18 14:49:48.385196	Boost Your Online Presence with WeGetYou.Online	Hello Ryan,\n\nI hope this message finds you well. I recently had the opportunity to visit your website, and I must say, I'm impressed with Vezra UK LTD's online presence.\n\nAt WeGetYou.Online, we recognize the importance of an engaging website in today's digital era. However, we believe there's always room for improvement. We've identified opportunities in your site's SEO and mobile responsiveness that could potentially boost your website's performance.\n\nYour website is already doing a great job showcasing your services, but imagine the results if it could reach a wider audience? I'd love to give you a brief overview of how we can enhance your online visibility and improve your website's overall performance.\n\nDoes this sound like something Vezra UK LTD would be interested in?\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
427	140	37	failed	\N	0	0	\N	2025-08-28 13:31:19.669065	\N	\N
38	19	21	sent	2025-08-18 14:49:48.366791	0	0	\N	2025-08-18 14:50:05.753441	Boosting Your Digital Presence - A Customized Approach	Hello,\n\nI hope this message finds you well. \n\nI understand that in today's digital age, the success of your business largely depends on its online visibility. I run a company called WeGetYou.Online, and we specialize in exactly that - enhancing the digital presence of businesses.\n\nWe offer personalized solutions tailored to each organization's unique needs. Whether it's SEO, website design, or social media management, we've got the skills and experience to take your online reputation to the next level.\n\nThe question is, are you ready to explore new opportunities to grow and establish your business online? \n\nLooking forward to hearing from you. \n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
428	140	37	failed	\N	0	0	\N	2025-08-28 13:36:48.909618	\N	\N
39	20	22	sent	2025-08-18 15:01:59.161529	0	0	\N	2025-08-18 15:01:59.170498	Elevate Vezra UK LTDs Brand with a Custom Email Domain	Hello Ryan,\n\nI hope this message finds you well. I recently had the opportunity to explore your website, https://wegetyou.online, and was impressed with your comprehensive range of services.\n\nAt WeGetYou.Online, we believe in the power of personalized domain names in promoting your brand. We specialize in providing custom domain-branded email addresses, like info@vezra.co.uk, which can contribute to establishing a stronger brand identity. We've found that this can lead to increased customer trust and engagement, as it demonstrates a higher level of professionalism and commitment to your brand.\n\nI'm curious, have you considered the potential impact of a domain-branded email on Vezra UK LTD's overall brand recognition and customer perception?\n\nJust reply if you'd like to learn more about how we can help elevate your brand.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
40	20	22	sent	2025-08-18 15:02:08.60117	0	0	\N	2025-08-18 15:02:08.613711	Enhance Vezra UK LTDs Digital Presence with Domain Branded Email	Hello Ryan,\n\nI hope this message finds you well. I recently came across Vezra UK LTD and was impressed by your comprehensive suite of services. Your commitment to delivering quality and efficiency is clear, and I believe I can support your mission.\n\nAs the founder of WeGetYou.Online, I help businesses like yours strengthen their brand identity with domain branded email addresses. I see that Vezra UK LTD has already established a strong digital presence, and a personalised email address like hello@vezraukltd.co.uk could further enhance your professional image.\n\nOur service is straightforward and hassle-free, allowing you to maintain focus on what you do best: ensuring client satisfaction and delivering top-notch services. A domain branded email could be the little extra touch that sets Vezra UK LTD apart in a crowded market.\n\nWould you be interested in discussing how we can tailor our services to benefit Vezra UK LTD? I would be more than happy to provide further information or answer any queries you may have.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nhttps://wegetyou.online
41	21	23	sent	2025-08-18 20:25:50.528397	0	0	seq_21_23_2c975e54	2025-08-18 20:25:50.538931	Let’s Blossom Your Brand with a Professional Email, Fleur Florists!	<p>Dear Team at Fleur Florists,<br>\n</p><p><br>\nI hope this email finds you well. My name is Ryan, founder of WeGetYou.Online. I was browsing your beautiful website and I couldn't help but notice the amazing selection of flowers you offer.<br>\n</p><p><br>\nAs a business, your online presence is equally important as your physical one. That's why I thought it might be beneficial for your brand to have a professional domain branded email. It not only makes your communication more official, it also helps in branding and maintaining a consistent image.<br>\n</p><p><br>\nI'd love to show you how we can make this happen for Fleur Florists. Please visit <a href="https://wegetyou.online/domain-email">our website</a> to see how we can enhance your digital presence and keep your brand blooming.<br>\n</p><p><br>\nLooking forward to possibly working with you!<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
80	30	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:31:46.243309	Enhance Your Floral Brand with a Professional Email Address	Hello,\n\nI hope this message finds you well. I recently visited your website and I must say, I'm truly impressed by your floral creations at Wild Meadow Floral. The passion and creativity you put into your work is truly captivating.\n\nWhile your website beautifully showcases your craft, I noticed there's potential to strengthen your brand identity further with a professional domain branded email. We at WeGetYou.Online understand how important it is for businesses like yours to present a consistent, professional image to customers.\n\nDid you know that having an email address that matches your domain name can significantly enhance your brand's credibility? It not only makes your business stand out but also fosters trust with your customers.\n\nI would love to show you how easy and beneficial it can be to have a domain-branded email. It's a simple yet powerful tool to elevate the branding of your business.\n\nJust reply if you'd like to learn more and I'd be more than happy to discuss how we can help you strengthen your brand's online presence.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
42	22	23	sent	2025-08-18 20:25:50.528397	0	0	seq_22_23_2179d016	2025-08-18 20:25:59.67775	Blossoming Your Online Presence With A Branded Email	<p>Dear Melbourne Florist and Gifts Team,<br>\n</p><p><br>\nI hope this email finds you well. I’ve been admiring your stunning arrangements on your website and it’s clear you have a knack for creating beauty.<br>\n</p><p><br>\nSpeaking of creating, my company, WeGetYou.Online, specializes in helping businesses, like yours, cultivate a stronger online presence. One way we do this is through a professional domain-branded email. Imagine the impact of having your business name in every email you send, like orders@melbourneflorist.co.uk. It’s a simple yet effective way to boost credibility and brand recognition.<br>\n</p><p><br>\nWhy not take a look at our offering at wegetyou.online/domain-email and see how we can help your online presence bloom just like your flowers? <br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
45	25	23	sent	2025-08-18 20:25:50.528397	1	0	seq_25_23_16a0a39e	2025-08-18 20:26:21.710073	Boost The Florist Nottinghams Brand with a Custom Email Domain!	<p>Dear [Name],<br>\n</p><p><br>\nI hope this email finds you well. I came across The Florist Nottingham and was truly captivated by the beautiful bouquets showcased on your website. <br>\n</p><p><br>\nAs a business owner myself, I understand the importance of creating a strong, consistent brand. That's why at WeGetYou.Online, we offer professional domain branded emails, helping businesses like yours stand out in every customer interaction. <br>\n</p><p><br>\nImagine, instead of "thefloristnottingham@gmail.com," your email could be "yourname@thefloristnottingham.co.uk." Impressive, right?<br>\n</p><p><br>\nLet's enhance your brand's professionalism together. Visit [WeGetYou.Online/Domain-Email](<a href="https://wegetyou.online/domain-email)">https://wegetyou.online/domain-email)</a> to explore how a personalized email domain can boost your business.<br>\n</p><p><br>\nLooking forward to hearing from you soon.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\n[Https://wegetyou.online](<a href="https://wegetyou.online)">https://wegetyou.online)</a></p>
43	23	23	sent	2025-08-18 20:25:50.528397	0	0	seq_23_23_bc225e5c	2025-08-18 20:26:06.330721	Blossom Your Online Presence with a Professional Domain Email	<p>Dear The Flower Shop Beeston team,<br>\n</p><p><br>\nI hope this email finds you amidst a bouquet of beautiful blooms. I've been admiring your flower arrangements and the unique charm of The Flower Shop Beeston online.<br>\n</p><p><br>\nI’m Ryan, the founder of WeGetYou.Online, and I believe we can offer a service that'll help your digital presence bloom just as beautifully as your roses.<br>\n</p><p><br>\nWe offer professional domain branded emails, adding a touch of credibility and professionalism to your business communication. Imagine sending your customers an email from 'you@theflowershopbeeston.co.uk' - sounds good, doesn't it?<br>\n</p><p><br>\nI invite you to learn more about how our service can benefit your business at wegetyou.online/domain-email.<br>\n</p><p><br>\nLooking forward to hearing from you soon.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
122	76	30	sent	2025-08-20 14:05:53.767683	0	0	a1697614-406d-4103-822c-9cf7807ccb4c	2025-08-20 14:06:36.774137	Boost client trust with a branded email	Hi Leon,\n\nI took a look at LeonBFitness and really admire your emphasis on tailored training and accountability—it's the kind of service that builds lasting client trust.\n\nOne area where you can strengthen that trust even more is your email presence. Clients often gauge professionalism from the tone and consistency of your messages. A branded domain email (for example, yourname@leonbfitness.com) signals you’re serious about your coaching relationship and makes it easier for clients to recognize and respond.\n\nWe Get You Online helps personal trainers like you move to a professional domain email without hassles. Benefits include: consistent branding across messages, improved perceived credibility, easier scheduling and progress updates, and a smoother onboarding experience for new clients.\n\nIf you’d like, I can outline a simple setup plan tailored to LeonBFitness and demonstrate how this can fit your workflow. You can explore more here: wegetyouonline.co.uk/domain-email.\n\nWould you be open to a quick 15-minute chat this week?\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
46	26	23	sent	2025-08-18 20:25:50.528397	0	0	seq_26_23_79d50021	2025-08-18 20:26:30.485834	Blossom Your Brand with a Professional Domain Email	<p>Dear Art of Flowers Team,<br>\n</p><p><br>\nI hope this email finds you well. My name is Ryan, the founder of WeGetYou.Online, and I couldn't help but notice your unique floral arrangements at <a href="http://artofflowersnottingham.co.uk/">http://artofflowersnottingham.co.uk/</a><br>\n</p><p><br>\nOur professional, domain-branded email service can help your business grow just like the beautiful blooms you create. Imagine the impact of having a professional, domain-branded email that perfectly represents the Art of Flowers brand!<br>\n</p><p><br>\nVisit us at WeGetYou.Online/domain-email and explore how we can make your online presence as vibrant as your bouquets.<br>\n</p><p><br>\nLooking forward to hearing from you soon.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
123	70	30	sent	2025-08-20 14:05:53.767683	0	0	0776131b-35c0-46d9-8f2d-314c35ee8578	2025-08-20 14:08:22.58712	A simple email upgrade for The Cabin	Hi there,\n\nI recently came across The Cabin Personal Training in Havant and was struck by your focus on personalized coaching and the trust you build with clients. In personal training, the strongest relationships are earned through clear, consistent communication—before, during, and after sessions.\n\nOne small, powerful step to reinforce that trust is using a branded domain email. A professional address like yourname@yourdomain.com signals credibility, reduces confusion, and makes clients feel they’re in a dedicated program rather than contacting a generic inbox. It also helps you stay consistent across client follow-ups, progress reminders, and appointment bookings.\n\nAt We Get You Online, we help fitness professionals like you implement domain-branded emails that align with your website and brand. It’s a quick win that protects your reputation and can improve reply rates.\n\nIf you’d like, I can share a quick 15-minute audit of how a branded domain email could fit The Cabin Personal Training. You can see details at wegetyouonline.co.uk/domain-email.\n\nWarm regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
52	32	23	sent	2025-08-18 20:25:50.528397	0	0	seq_32_23_4dc5c032	2025-08-18 20:27:11.299128	Boosting Sweet Peony Florists Brand with a Custom Email Domain	<p>Dear Sweet Peony Florist team,<br>\n</p><p><br>\nI hope this email finds you well. I am Ryan, founder of WeGetYou.Online, a company dedicated to helping businesses like yours strengthen their online presence.<br>\n</p><p><br>\nI was browsing through your lovely website (<a href="https://www.sweetpeonyfloral.co.uk/)">https://www.sweetpeonyfloral.co.uk/)</a> and I couldn't help but notice that there's room for amplifying your brand with a professional domain branded email.<br>\n</p><p><br>\nBy having an email address that ends with @sweetpeonyfloral.co.uk, not only do you boost your brand, but also build trust with your customers. It's a small change that can make a big difference. <br>\n</p><p><br>\nTo get started, simply visit <a href="https://wegetyou.online/domain-email">our website</a> and see how we can help you bloom online.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
51	31	23	sent	2025-08-18 20:25:50.528397	1	0	seq_31_23_c224ed23	2025-08-18 20:27:02.709791	Blossom your brand with a professional email domain	<p>Dear Team at AFS Artificial Floral Supplies,<br>\n</p><p><br>\nI hope this message finds you in full bloom. I came across your beautifully designed website and was quite impressed by the extensive range of artificial floral supplies you offer. <br>\n</p><p><br>\nAs the founder of WeGetYou.Online, I believe we could help you further cultivate your brand's online presence with our professional domain branded email service. A branded email can be the difference between appearing like a small seedling and a fully blossoming business. <br>\n</p><p><br>\nPlease visit wegetyou.online/domain-email to see how we can help you continue to grow in the digital world. I'm confident that our services would be a perfect fit for your thriving business.<br>\n</p><p><br>\nLooking forward to the opportunity to work together.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
53	33	23	sent	2025-08-18 20:25:50.528397	0	0	seq_33_23_98e7be00	2025-08-18 20:27:19.003245	Spruce up Jas and Florals Online Presence	<p>Dear there,<br>\n</p><p><br>\nAs a florist, you create beautiful arrangements that brighten people’s days. At WeGetYou.Online, we believe your online presence should reflect the beauty of your work. I'm Ryan, founder of WeGetYou.Online, and we specialize in transforming standard email addresses into professional domain branded emails.<br>\n</p><p><br>\nImagine the impact of an email from "there@jasandfloral.co.uk" versus a generic one. It's professional, memorable, and reinforces your brand every time you send a mail. Plus, it's simple to set up and manage.<br>\n</p><p><br>\nLet's help Jas and Floral bloom online. Visit <a href="https://wegetyou.online/domain-email">https://wegetyou.online/domain-email</a> to see how we can tailor our services to your needs.<br>\n</p><p><br>\nLooking forward to helping your online presence flourish.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
54	34	23	sent	2025-08-18 20:25:50.528397	0	0	seq_34_23_97c52605	2025-08-18 20:27:26.664844	Blooming Online Presence with Branded Domain Email for Poppies Florist	<p>Dear Poppies Florist Bournemouth,<br>\n</p><p><br>\nI recently visited your website and was impressed with the beautiful floral arrangements you offer. As the founder of WeGetYou.Online, I can't help but notice the potential of further enhancing your online presence.<br>\n</p><p><br>\nWe specialize in providing professional domain branded emails, a small change that can significantly boost your brand's credibility and visibility. Imagine your emails coming from @poppiesfloristbournemouth.co.uk rather than a generic email service.<br>\n</p><p><br>\nOur service is simple, cost-effective, and designed especially for businesses like yours. I invite you to visit our website at wegetyou.online/domain-email to learn more.<br>\n</p><p><br>\nLet's give your email communications the same elegance as your floral arrangements!<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
429	140	37	failed	\N	0	0	\N	2025-08-28 13:42:25.1692	\N	\N
430	140	37	failed	\N	0	0	\N	2025-08-28 13:47:56.129151	\N	\N
57	36	23	sent	2025-08-18 20:25:50.528397	0	0	seq_36_23_a0467fd7	2025-08-18 20:27:41.118878	Blossoming Your Digital Presence with New leaf floristry	<p>Dear Team at New leaf floristry,<br>\n</p><p><br>\nI’ve been admiring your stunning floral arrangements on your website, and it got me thinking about how we could enhance your online presence even further.<br>\n</p><p><br>\nI’m Ryan, the founder of WeGetYou.Online. We specialize in creating professional domain-branded emails that not only increase credibility but also drive customer engagement. <br>\n</p><p><br>\nA branded email like 'contact@newleaffloristry.net' would seamlessly integrate with your online brand, promoting a cohesive and trustworthy image. <br>\n</p><p><br>\nFor more information, visit our website at wegetyou.online/domain-email to discover how we can help your business bloom online. <br>\n</p><p><br>\nLooking forward to helping your digital garden grow.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
59	37	23	sent	2025-08-18 20:25:50.528397	0	0	seq_37_23_a9815bb3	2025-08-18 20:27:48.176683	Blossom Your Email Game with Blushing Bloom and OceanFlora	<p>Dear [Name],<br>\n</p><p><br>\nI hope this message finds you in high spirits as you continue to beautify the world with your artistic floral arrangements at Blushing Bloom and OceanFlora.<br>\n</p><p><br>\nI'm Ryan, the founder of WeGetYou.Online and we specialize in providing professional domain branded emails that add a touch of elegance and credibility to your business. <br>\n</p><p><br>\nI believe that a professional email address like [name]@blushingbloom.co.uk can greatly enhance your brand's image while ensuring your correspondence stands out in your customer's inbox.<br>\n</p><p><br>\nI invite you to explore more about our branded email service at wegetyou.online/domain-email and see how we can help your business bloom online. <br>\n</p><p><br>\nLooking forward to helping you grow,<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
431	140	37	failed	\N	0	0	\N	2025-08-28 13:53:38.250364	\N	\N
55	21	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:27:30.606286	Enhancing Fleur Florists online identity with domain email	Good Morning,\n\nI recently had the pleasure of browsing through your beautiful website, Fleur Florists, and was particularly impressed by the vast array of fresh and vibrant flower arrangements that you offer. What you've accomplished with your business is quite remarkable.\n\nWhile appreciating your floral expertise, I couldn't help but notice there might be room to elevate your online presence. My company, WeGetYou.Online, specializes in setting up domain-branded emails that resonate with your brand name.\n\nA branded email not only appears more professional but also increases brand recognition every time you send an email. It's a smart way to subtly remind your customers of who you are and what you do - just like your superb 'Florist Choice' bouquet does, but in the digital world.\n\nWould you be interested in exploring how a domain-branded email could benefit Fleur Florists? Let's chat about how we can further bloom your online identity.\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
58	22	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:27:45.829466	Enhancing Melbourne Florists Online Presence with a Branded Domain Email	Hello,\n\nI recently had the pleasure of visiting your website, Melbourne Florist and Gifts, and was thoroughly impressed by the extensive range of floral arrangements and gift options you offer. Your commitment to providing customers with a stunning selection of flowers is quite evident.\n\nAs the founder of WeGetYou.Online, I specialize in helping businesses like yours establish a stronger online presence. One way to do this is through a professional domain branded email, which can further solidify your brand image and credibility amongst your clientele.\n\nI'm curious, have you considered the impact a '@melbourneflorist.co.uk' email address could have on your brand? It can enhance your professional image, provide a unified brand experience and could even boost customer trust.\n\nI would be delighted to discuss how a branded domain email could add value to your business. Just reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
432	140	37	failed	\N	0	0	\N	2025-08-28 13:59:31.707918	\N	\N
73	23	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:29:50.043715	Boost Your Floral Brand with A Personalised Domain Email	Good morning,\n\nI had the pleasure of visiting your website recently and was truly captivated by your stunning floral arrangements. The Flower Shop Beeston’s attention to detail and commitment to quality is quite evident in each bouquet displayed on your site. \n\nI noticed that you've been serving the Beeston area with your beautiful flowers for years. That's quite an achievement! To help you further distinguish your brand and cultivate a more professional image, I would like to recommend our personalised domain email service at WeGetYou.Online.\n\nOur service is designed to help businesses like yours create a stronger online presence and stand out from the competition. With a domain email personalised for The Flower Shop Beeston, you’re not only enhancing your brand’s professional image but also building trust among your customers.\n\nIf you're interested in learning how a personalised domain email can benefit The Flower Shop Beeston, I would be more than happy to share more details. \n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
74	24	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:30:06.17374	Boost Your Blooms with a Professional Domain Email	Hello,\n\nI recently visited your website, Mapperley Blooms, and was truly charmed by your assortment of unique and stunning flower arrangements. Your dedication to providing the community with beautiful, hand-crafted bouquets is clearly evident.\n\nAs someone who appreciates the importance of a strong online presence, I noticed you're using a square.site domain. While this works, a professional domain-branded email could offer a more polished and credible image for your business.\n\nAt WeGetYou.Online, we specialize in supplying professional domain-branded emails that can help businesses like Mapperley Blooms stand out in every customer interaction.\n\nWould you be interested in discussing how a custom email domain could enhance your brand's online presence and potentially increase customer trust?\n\nLet me know if this is something you'd like to explore further.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nhttps://wegetyou.online
81	31	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:32:05.885893	Enhancing AFS Artificial Floral Supplies with a Professional Domain Email	Hello,\n\nI hope this email finds you well. I recently visited your website, AFS Artificial Floral Supplies, and was impressed by the wide range of exquisite artificial floral designs you offer. Your commitment to providing high-quality faux flowers and floral supplies is truly admirable.\n\nAs you continue to grow and expand your online presence, have you considered the benefits of a professional domain branded email? At WeGetYou.Online, we specialize in developing domain emails that not only enhance your business's professionalism but also make it easier for customers and suppliers to connect with you.\n\nConsider this - an email from sales@artificialfloralsupplies.co.uk is instantly recognizable and trustworthy. It not only represents your brand but also shows your dedication to providing seamless customer service.\n\nI believe this small change could have a significant impact on your online brand presence and customer relations. If you're interested, I'd love to share more about how we could tailor this service for AFS Artificial Floral Supplies.\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
433	140	37	failed	\N	0	0	\N	2025-08-28 14:05:28.360414	\N	\N
82	32	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:32:20.253091	Boost Your Blooming Business with a Professional Domain Email	Good Morning,\n\nI couldn't help but admire your magnificent floral arrangements at Sweet Peony Florist. The dedication you put into crafting your beautiful bouquets and wedding arrangements is simply amazing.\n\nI'm Ryan, the founder of WeGetYou.Online, and I believe we can help you further enhance your brand identity with a professional domain email. We've noticed that businesses like yours often benefit from the added credibility and increased customer trust that comes with professional email addresses.\n\nImagine your customers receiving their order confirmations from an email that perfectly matches your brand like contact@sweetpeonyfloral.co.uk. It's all about those small details that make a big difference.\n\nWould you be interested in learning more about how we can help Sweet Peony Florist bloom even more online?\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
434	140	37	failed	\N	0	0	\N	2025-08-28 14:11:20.200728	\N	\N
435	140	37	failed	\N	0	0	\N	2025-08-28 14:17:55.498872	\N	\N
436	140	37	failed	\N	0	0	\N	2025-08-28 14:23:52.241916	\N	\N
61	39	23	sent	2025-08-18 20:25:50.528397	0	0	seq_39_23_18666d11	2025-08-18 20:28:05.864451	Blossom with a Brand-New Email for Sherwood Florist	<p>Dear there,<br>\n</p><p><br>\nYour floral arrangements at Sherwood Florist are truly breathtaking, and your website <a href="https://www.sherwood-florist.com/">https://www.sherwood-florist.com/</a> does a fantastic job showcasing them. But imagine if you could elevate your online presence even further?<br>\n</p><p><br>\nWeGetYou.Online specializes in creating professional, domain-branded email addresses that instill trust and credibility. Our service will allow you to engage with your customers using a customized email address that reflects Sherwood Florist's brand (e.g., there@sherwood-florist.com).<br>\n</p><p><br>\nThis simple yet effective tool can increase your customer engagement and add a layer of professionalism to your communications. <br>\n</p><p><br>\nTo learn more about how we can help Sherwood Florist bloom online, please visit wegetyou.online/domain-email. <br>\n</p><p><br>\nLooking forward to helping you blossom online!<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
187	102	34	sent	2025-08-22 12:57:45.306676	0	0	37a213e8-aac6-42e3-aaf1-b7a690547206	2025-08-22 12:59:12.761019	Matt, elevate trust with a branded email	Hi Matt,\n\nI took a quick look at Matt Gutteridge Photography and was struck by how your portfolio emphasizes genuine moments and a calm, natural storytelling style. That focus on trust is exactly what clients lean on when they hire a photographer to capture life’s most important moments.\n\nOne small but powerful touch I’ve seen successful photographers adopt is using a professional domain email. A branded address (for example, you@yourdomain) mirrors the care you bring to shoots, helps reassure clients during inquiry and scheduling, and reduces friction in getting bookings confirmed quickly. It also ties neatly into the rest of your brand, from the website to your contracts and galleries, reinforcing consistency and reliability.\n\nIf you’re curious, we offer domain-branded email that integrates with your existing setup and can help you present a cohesive client experience from first contact to gallery delivery. I’d be happy to share a quick, practical plan tailored for your workflow.\n\nIf you’d like to learn more, you can check out wegetyouonline.co.uk/domain-email and see how it could fit with your brand.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
62	40	23	sent	2025-08-18 20:25:50.528397	0	0	seq_40_23_1d606548	2025-08-18 20:28:12.892927	Blossom Your Brand with Lullabelles Floristrys Personalized Email Domain	<p>Dear Lullabelles Floristry team,<br>\n</p><p><br>\nI've been admiring your beautiful floral work at Lullabelles Floristry. Your dedication to crafting stunning arrangements truly sets you apart.<br>\n</p><p><br>\nAs the founder of WeGetYou.Online, I can see the potential your brand has for further growth. Our professional domain-branded email could help to elevate your brand's online presence. Imagine having an email like "bouquets@lullabellesfloristry.com" representing your business to your clients and partners. It has quite a ring to it, doesn't it?<br>\n</p><p><br>\nI invite you to explore more about our service at <a href="https://wegetyou.online/domain-email.">https://wegetyou.online/domain-email.</a> <br>\n</p><p><br>\nLet's help your brand blossom online as beautifully as your floral arrangements do in real life. <br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
113	64	30	sent	2025-08-20 13:43:11.990249	0	0	79656732-b0c5-47dd-b3a1-bd197785d9fa	2025-08-20 13:43:49.002736	Boost client trust with branded emails	Hi Phil,\n\nI've been checking out Phil Lea Personal Training and your approach to tailored workouts and steady client progress stands out. People hire trainers for results—and you deliver with accountability and clear progress tracking. That trust begins with consistent, professional communication.\n\nAn insight I share with trainers: branded domain emails reinforce trust more than a generic address. When clients see your messages come from phil@philleafitness.com, it signals professionalism and reliability, reducing hesitation and increasing engagement with check-ins, program updates, and reminders.\n\nPractical tip: migrate to a branded email that matches your site, use it for onboarding, appointment confirmations, and weekly progress notes. Keep signatures clean with your name, title, and a direct calendar link.\n\nIf you'd like to explore how a branded domain email can fit Phil Lea Personal Training, please check wegetyouonline.co.uk/domain-email. It’s a quick way to boost your client trust without changing your coaching.\n\nWould you be open to a 15-minute chat?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
63	41	23	sent	2025-08-18 20:25:50.528397	0	0	seq_41_23_81067992	2025-08-18 20:28:20.704392	Blooming Your Brand with a Custom Email Domain	<p>Dear Claire,<br>\n</p><p><br>\nI recently had the pleasure of visiting your website, Claire’s Floristry and Tea Room. The beautiful floral arrangements, combined with the inviting ambiance of the tea room, certainly left a lasting impression.<br>\n</p><p><br>\nHowever, I also noticed an opportunity for you to grow your brand even further. I'm Ryan, the founder of WeGetYou.Online, and we specialize in creating professional domain branded emails.<br>\n</p><p><br>\nHaving a custom email (like claire@clairesfloristry.co.uk) not only strengthens your brand, but also adds credibility and professionalism. <br>\n</p><p><br>\nDiscover how this small change can make a big difference at wegetyou.online/domain-email. I'm certain you'll find it as beneficial as our other floristry clients have.<br>\n</p><p><br>\nLooking forward to hearing from you.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
66	44	23	sent	2025-08-18 20:25:50.528397	0	0	seq_44_23_3b8c4046	2025-08-18 20:28:43.019438	Blossom Online with a Branded Email for Lily Violet May Florist	<p>Dear There,<br>\n</p><p><br>\nAs the bustling business behind Lily Violet May Florist, you clearly have a knack for creating beautiful arrangements. At WeGetYou.Online, we believe your email should be just as unique and professional as the bouquets you design.<br>\n</p><p><br>\nOur branded domain email service enhances your online presence and credibility. It’s like a custom business card, but for your inbox. Imagine sending your quotes and updates from there@lilyvioletmay.co.uk, instead of a generic email address.<br>\n</p><p><br>\nLet's sprout your digital potential together. Click here to discover how we can help you flourish online (wegetyou.online/domain-email).<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
67	45	23	sent	2025-08-18 20:25:50.528397	0	0	seq_45_23_13d48bfa	2025-08-18 20:28:49.668243	Give The Flower Shops Emails a Blooming Makeover	<p>Dear There,<br>\n</p><p><br>\nAllow me to introduce myself - I'm Ryan, the founder of WeGetYou.Online. As a fan of beautiful things, I've always admired the stunning floral creations that The Flower Shop brings to Bristol.<br>\n</p><p><br>\nJust as you carefully arrange each petal in your bouquets, we believe in crafting email experiences that reflect the unique charm of a business. That's why I'd love to introduce you to our professional domain-branded email service, designed to help your digital presence flourish just like your floral arrangements.<br>\n</p><p><br>\nPlease visit wegetyou.online/domain-email to see how we can transform your emails into something as special and memorable as a hand-tied bouquet.<br>\n</p><p><br>\nLooking forward to helping The Flower Shop blossom online.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
68	46	23	sent	2025-08-18 20:25:50.528397	0	0	seq_46_23_86f5635a	2025-08-18 20:28:55.750623	Grow Tiger Lilys Online Presence With Professional Domain Email	<p>Dear Tiger Lily team,<br>\n</p><p><br>\nI've been admiring your floral creations on <a href="https://www.tigerlilyflowers.co.uk/">https://www.tigerlilyflowers.co.uk/</a> - they're truly a breath of fresh air. As the founder of WeGetYou.Online, I can't help but see a world of opportunity for Tiger Lily to bloom even more brightly online.<br>\n</p><p><br>\nWith our professional domain branded email service, you can enhance your business identity and increase customer trust - a critical factor in the online florist industry. <br>\n</p><p><br>\nI invite you to learn more about how we can help Tiger Lily flourish in the digital landscape. Visit wegetyou.online/domain-email to see how our service can benefit you.<br>\n</p><p><br>\nLooking forward to potentially working with you.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
124	75	30	sent	2025-08-20 14:05:53.767683	0	0	bf6c2e08-277a-4583-98c5-e67d22ce8b9c	2025-08-20 14:09:40.863503	Build client trust with a branded email	Hi Mark,\n\nI recently visited Mark Field Fitness and was impressed by your mobile personal training approach—meeting clients where they are and delivering personalized programs. At We Get You Online, we help coaches like you project the same level of professionalism in every message with a domain-branded email.\n\nOne quick insight: in fitness, trust is earned in seconds. A branded email from your domain signals consistency, accountability, and safety, making clients feel more confident about their plan, reminders, and follow-ups. It helps reinforce the trust you’ve built in person and reduces hesitation when replying or booking sessions.\n\nIf you’re curious, we offer a simple setup that aligns with your brand and budget, and you can learn more here: wegetyouonline.co.uk/domain-email.\n\nWould you be open to a brief 10-minute chat this week to explore how a branded domain could strengthen communication, boost client confidence, and support Mark Field Fitness growth?\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
69	47	23	sent	2025-08-18 20:25:50.528397	0	0	seq_47_23_8f90cd32	2025-08-18 20:29:03.673354	Blossom Online with a Branded Email Domain for Fleurtations Florist Bristol	<p>Dear Fleurtations Florist Bristol Team,<br>\n</p><p><br>\nAs someone who appreciates the beauty of the work you do at Fleurtations Florist Bristol, I wanted to introduce a service that could further enhance your online presence.<br>\n</p><p><br>\nI'm Ryan, the founder of WeGetYou.Online, and we specialize in creating professional, domain-branded emails. Having a branded email, like hello@fleurtations-bristol.co.uk, can make your digital communication as unique and memorable as your stunning floral arrangements.<br>\n</p><p><br>\nI invite you to discover how our domain email service can benefit Fleurtations Florist Bristol by visiting <a href="https://wegetyou.online/domain-email">wegetyou.online/domain-email</a>. <br>\n</p><p><br>\nLooking forward to helping your online presence bloom.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
70	48	23	sent	2025-08-18 20:25:50.528397	0	0	seq_48_23_22d4fe13	2025-08-18 20:29:11.969659	Boost Flowers By Allas Online Presence with a Branded Domain Email	<p>Dear [Name],<br>\n</p><p><br>\nI hope this message finds you well. I recently visited your website, <a href="http://flowersbyalla.com/,">http://flowersbyalla.com/,</a> and was truly captivated by the stunning floral arrangements.<br>\n</p><p><br>\nAt WeGetYou.Online, we're passionate about helping businesses like Flowers By Alla bloom online. I believe our professional domain branded email service can give your online presence that extra boost. <br>\n</p><p><br>\nBy having your own domain email, your business will look more professional and credible to your customers. It's a simple yet powerful tool that can greatly impact your brand.<br>\n</p><p><br>\nI'd love to discuss how we can help. Learn more by visiting us at wegetyou.online/domain-email and let's start making your online presence as vibrant as your flowers.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
125	74	30	sent	2025-08-20 14:05:53.767683	0	0	7632aaac-7ebc-4ef8-bbff-918a1e3485a2	2025-08-20 14:11:58.643161	Boost client trust with a branded email	Hi Jess,\n\nI spent a few minutes exploring Jess Wilson PT and was impressed by your client-first approach to training and the emphasis you place on accountability and results. Your site clearly communicates practical, science-backed coaching and accessible programs for clients at every level.\n\nIn personal training, trust is built through reliable, clear communication. A professional, domain-branded email signals credibility the moment a client sees it, eliminates confusion, and makes your messages feel like part of a cohesive coaching plan. This small detail can strengthen the trust that turns inquiries into clients and clients into long-term advocates.\n\nHere's how a branded email helps you as a trainer: consistent sender address, easier recall for referrals, and a polished, professional image across bookings, reminders, and check-ins. We help you set up a domain-based email that matches Jess Wilson PT and stays aligned with your current website.\n\nIf you'd like to see how it could look for you, check out wegetyouonline.co.uk/domain-email. Would you be open to a quick 10-minute chat to explore options?\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
71	49	23	sent	2025-08-18 20:25:50.528397	0	0	seq_49_23_37d70442	2025-08-18 20:29:18.142845	Bloom Online with a Professional Domain Email	<p>Dear Edith Wilmot Bristol Florist Team,<br>\n</p><p><br>\nI recently visited your website and was impressed by the beautiful arrangements you create. However, I noticed that your email address could use a touch of that same elegance. <br>\n</p><p><br>\nAt WeGetYou.Online, we specialize in providing professional domain branded email services. We can help you transform your email address into something like 'enquiries@edithwilmot.co.uk', which will not only look professional but also enhance your brand's credibility.<br>\n</p><p><br>\nI would love to discuss how we can make this happen. You can learn more about our service at [wegetyou.online/domain-email](<a href="http://wegetyou.online/domain-email).">http://wegetyou.online/domain-email).</a><br>\n</p><p><br>\nLooking forward to hearing from you soon.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
437	140	37	failed	\N	0	0	\N	2025-08-28 14:29:22.241048	\N	\N
83	33	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:32:37.619239	Enhance Jas and Florals Online Presence with a Branded Domain Email	Hello,\n\nI hope this email finds you well. I recently had the pleasure of visiting your website, Jas and Floral. Your unique floral arrangements and personalised bouquet services truly caught my eye - the quality of your work is outstanding.\n\nI'm Ryan, Founder of WeGetYou.Online. We specialize in professional domain branded email services, which can help enhance your online presence and credibility. A domain email can give your digital correspondence a more polished look, aligning with the professionalism I saw reflected in your business.\n\nConsidering the attention to detail and personalized touch you offer at Jas and Floral, I believe a professional domain email could provide an opportunity to further elevate your brand.\n\nIf you're interested, I'd love to discuss how a domain email could be a valuable asset to your online identity.\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
84	34	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:32:52.429637	Boost Your Blooms with Professional Domain Branded Email	Hello,\n\nI recently visited your wonderful website, Poppies Florist Bournemouth, and was captivated by the assortment of floral arrangements you offer for various occasions. The passion for your craft is evident in every bouquet, and I admire that.\n\nI am reaching out because I believe I can help enhance the online presence of your business. I am Ryan, the founder of WeGetYou.Online, and we specialize in professional domain branded email services.\n\nCreating a professional email address for your business can provide a more polished image, helping to build trust with potential customers. In today's digital age where a significant number of customers are online, a domain-branded email can offer an edge over competitors, further bolstering your brand's credibility.\n\nI am confident that our service will be beneficial for Poppies Florist Bournemouth. I would love to discuss this further and answer any questions you may have.\n\nJust reply if you would like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
126	71	30	sent	2025-08-20 14:05:53.767683	0	0	a16c6cab-ddb1-459c-9428-51b353284c61	2025-08-20 14:13:49.914954	FJK Fitness: Build trust with a branded email	Hi there,\n\nI’m Ryan, founder of We Get You Online. I help personal trainers and fitness businesses like FJK Fitness establish trust with clients through professional domain email.\n\nFrom what I saw on fjkfitness.co.uk, you’re focused on personalised coaching and helping clients hit real-world goals. In this space, trust is built not just with great training but with clear, reliable communication. A branded email that matches your website signals professionalism, privacy, and consistency—three keys to turning inquiries into loyal clients.\n\nThink about client check-ins, program updates, or nutrition notes arriving from you@fjkfitness.co.uk instead of a generic service mailbox. It reduces hesitation, supports your brand, and makes follow-ups feel personal rather than transactional. We can set up a professional domain inbox, plus simple templates and calendar integration, so every message reinforces the relationship you’ve built in the gym or online.\n\nIf you’re curious, you can explore how this works at wegetyouonline.co.uk/domain-email. Happy to share a quick, no-pressure plan tailored to FJK Fitness.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
85	35	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:33:07.901111	Enhancing Little & Blooms Online Presence, Petal by Petal	Hello,\n\nI recently had the pleasure of visiting your website, Little & Bloom. Your floral designs are not only aesthetically pleasing but also show a keen attention to detail. It's clear that you have a passion for creating beautiful things and helping people celebrate life's special moments.\n\nI am reaching out because I believe I can help make your online presence as unique and vibrant as your floral arrangements. My company, WeGetYou.Online, specializes in creating professional domain branded emails. This would not only lend your business an additional layer of credibility, but also help you stand out in a crowded digital marketplace.\n\nImagine having a personalized email address that reflects your unique brand, rather than a generic one. It's a small detail, but in a business where details matter, it could make a significant difference.\n\nIf this sounds like something that could benefit Little & Bloom, I'd love to chat more about how we can cultivate your online presence together. Just reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
86	36	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:33:24.023231	Enhance New Leaf Floristrys online presence with a branded domain email	Hello,\n\nI recently came across your beautiful website, http://www.newleaffloristry.net/, and was impressed by your exquisite floral arrangements and attention to detail. Your commitment to creating custom, handcrafted designs for every occasion truly stands out.\n\nAs a fellow business owner, I understand the importance of maintaining a professional image. One way to achieve this is through a professional domain branded email. It not only strengthens brand recognition but also builds credibility with your customers.\n\nAt WeGetYou.Online, we specialize in providing businesses like New Leaf Floristry with professional domain branded emails. We believe that your email address should be as unique and personalized as the stunning flower arrangements you create.\n\nIf you're interested in enhancing your online presence with a branded domain email, I'd be more than happy to provide more information. \n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
438	140	37	failed	\N	0	0	\N	2025-08-28 14:34:53.052941	\N	\N
87	37	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:33:41.669635	Enhance Your Floral Creations with a Branded Domain Email	Hello,\n\nI recently had the pleasure to visit your enchanting website, Blushing Bloom and OceanFlora. I must say, the passion and creativity that goes into each of your floral arrangements is truly awe-inspiring.\n\nWhile admiring your work, I couldn't help but notice the opportunity to elevate your brand's digital presence. Having a professional domain branded email could strengthen your brand identity and instill an even greater sense of trust and professionalism in your clients.\n\nAt WeGetYou.Online, we've helped numerous businesses like yours establish a strong online identity with our domain email services. Imagine the impact of sending your client updates from an email address that proudly features your brand — instead of a generic one.\n\nI'm confident that our services could be a great addition to your stunning floral artistry. I invite you to explore how we can make this possible at https://wegetyou.online/domain-email.\n\nJust reply if you'd like to learn more or have any questions. I look forward to hearing from you.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
88	38	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:34:00.189818	Enhancing Full Bloom Haylings Online Presence with Professional Email	Hello,\n\nI recently had the pleasure of visiting your website and admiring the beautiful floral arrangements at Full Bloom Hayling. The passion and creativity you put into each creation is evident, and it made me wonder how we could work together to enhance your digital presence.\n\nAt WeGetYou.Online, we specialize in providing professional domain branded email services. Imagine, instead of using a generic email address, you could be reaching your clients from an address like 'yourname@fullbloomhayling.com'. This not only adds a level of professionalism but also improves your brand visibility.\n\nI believe such a service could play a pivotal role in helping Full Bloom Hayling stand out in the competitive florist industry, creating a seamless online identity that mirrors the quality and dedication you put into your floral arrangements.\n\nI'd love to discuss this further if you're interested. Just reply to this email and we can set up a time to talk about how a professional email domain can benefit your business.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
439	140	37	failed	\N	0	0	\N	2025-08-28 14:40:53.317584	\N	\N
440	140	37	failed	\N	0	0	\N	2025-08-28 14:46:48.749069	\N	\N
441	140	37	failed	\N	0	0	\N	2025-08-28 14:52:49.79728	\N	\N
442	140	37	failed	\N	0	0	\N	2025-08-28 14:58:21.88672	\N	\N
443	140	37	failed	\N	0	0	\N	2025-08-28 15:04:08.707792	\N	\N
444	140	37	failed	\N	0	0	\N	2025-08-28 15:10:06.930762	\N	\N
89	39	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:34:17.102492	Enhance Sherwood Florists Online Presence with a Professional Email Domain	Good morning,\n\nI recently stumbled upon Sherwood Florist's stunning website and was thoroughly impressed by the exquisite floral arrangements you provide, not to mention your admirable commitment to delivering happiness through your services.\n\nAs someone who appreciates businesses that are passionate about their craft, I thought it would be worth discussing how to further elevate your digital presence. I'm Ryan, the founder of WeGetYou.Online, where we specialize in providing professional domain-branded email addresses.\n\nHaving a professional email domain can significantly increase the credibility of your online communications with customers. It can also help to highlight your brand's identity, making it even more recognizable and trusted in the eyes of your clientele.\n\nI'd love to discuss how a branded email domain from WeGetYou.Online can help Sherwood Florist bloom even more online. Would you be interested in exploring this further?\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
90	40	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:34:35.117569	Boost Your Blooms with a Custom Domain Email	Hello,\n\nI recently visited your charming web page, Lullabelles Floristry, and I must say, your exquisite range of floral arrangements caught my eye. Your dedication to creating beautiful bouquets is truly admirable.\n\nHowever, I noticed that your business, despite its high-quality service, could benefit from a more professional online presence. As the Founder of WeGetYou.Online, I specialize in providing businesses like yours with professional domain branded email addresses.\n\nImplementing this small change could significantly elevate your brand's credibility, making it easier for clients to remember and recognize your business. Plus, it'll seamlessly integrate with your existing email provider.\n\nCould I interest you in further discussing this opportunity to enhance your digital presence and, in turn, potentially increase your customer engagement?\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
445	140	37	failed	\N	0	0	\N	2025-08-28 15:15:46.142401	\N	\N
91	41	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:34:54.858504	Enhance Claire’s Floristry and Tea Room with a Branded Email	Hello,\n\nI was recently browsing through your charming website, Claire's Floristry and Tea Room, and I found myself immersed in the world of tea and beautiful flora. The unique combination of floristry and tea service truly sets your business apart.\n\nAs the founder of WeGetYou.Online, I couldn't help but notice an opportunity to enhance your online presence further and strengthen your brand identity. We specialize in providing professional domain branded email addresses, which could give a more cohesive, professional image to your digital communications.\n\nI'm curious, have you considered the impact a branded email could have on your brand perception, especially given the distinct and memorable nature of your business?\n\nIf you'd like to explore this, I would be more than happy to share how we can seamlessly integrate a domain email into your current setup without disrupting your operations.\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
92	42	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:35:10.379738	Enhance Blooms The Florist Emsworths Digital Presence with a Professional Domain Email	Hello,\n\nI couldn't help but admire the vibrant and delightful floral arrangements presented on your website, Blooms The Florist Emsworth. Your commitment to sourcing the finest flowers and creating stunning bouquets for every occasion is truly impressive.\n\nWhile browsing your site, I noticed an opportunity to elevate your digital presence even further. As the founder of WeGetYou.Online, I specialise in providing professional domain branded emails that can enhance your brand's credibility and increase customer trust.\n\nWith a professional email address that matches your domain, you can further establish Blooms The Florist Emsworth as a premium, trustworthy business in the floral industry. It's a small change, but one that can make a significant difference in how your customers perceive your brand.\n\nIf you'd like to learn more about how a branded domain email can benefit your business, just reply to this email.\n\nLooking forward to hearing from you.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
446	140	37	failed	\N	0	0	\N	2025-08-28 15:21:49.427692	\N	\N
93	43	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:35:27.29641	Enhance Your Christmas Tree Business with a Professional Email Address	Hello,\n\nI recently came across your business, Christmas Trees Portsmouth, while browsing through niche local services. Your collection of Christmas trees truly caught my eye with their lush greenery and perfect shapes!\n\nAs the founder of WeGetYou.Online, I work with unique businesses like yours to make a stronger online presence. One way to do this is through a professional, domain-branded email address. It not only gives your business a more polished look, but also helps build trust with your customers - a crucial factor in the festive season when everyone's hunting for the perfect Christmas tree!\n\nI believe a Christmas Trees Portsmouth-branded email could significantly contribute to the already excellent customer service you provide. How about a chat on how this could work for your business?\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
94	44	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:35:39.198587	Enhance Lily Violet Mays Online Presence with Custom Email Domains	Hello,\n\nI recently visited http://www.lilyvioletmay.co.uk/ and admired your beautiful floral arrangements and bouquets. The passion you put into your work is evident and it's clear you’ve earned your reputation in the florist industry. \n\nI noticed while browsing your website that you might not be maximizing your online presence. That's where I believe my company, WeGetYou.Online, could offer assistance. \n\nWe specialize in professional domain branded emails that not only help businesses like Lily Violet May Florist stand out in the digital world, but also add an extra layer of credibility and professionalism to your client communications. \n\nImagine having an email address like flowers@lilyvioletmay.co.uk rather than a generic Gmail or Yahoo address. It's a small change that can make a big difference in how clients perceive your brand.\n\nIf you're interested in learning more about how a professional domain branded email can enhance your online presence, I'd love to chat further. \n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
447	140	37	failed	\N	0	0	\N	2025-08-28 15:27:42.184083	\N	\N
448	140	37	failed	\N	0	0	\N	2025-08-28 15:33:25.487374	\N	\N
449	140	37	failed	\N	0	0	\N	2025-08-28 15:39:35.10157	\N	\N
450	140	37	failed	\N	0	0	\N	2025-08-28 15:45:33.15785	\N	\N
451	140	37	failed	\N	0	0	\N	2025-08-28 15:51:35.242675	\N	\N
452	140	37	failed	\N	0	0	\N	2025-08-28 15:57:29.674564	\N	\N
95	45	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:35:54.956582	Boost Your Blooms with a Branded Email Domain	Good morning,\n\nI recently visited your vibrant website at The Flower Shop Bristol and was very impressed by the wide array of beautiful bouquets and arrangements you've put together. The passion for floristry is clearly evident in your creations and the services you offer, making you stand out in the industry.\n\nHowever, I noticed that your email address doesn't reflect the unique branding of your business. As the Founder of WeGetYou.Online, I believe a professional domain-branded email could enhance your online presence and make your communication more consistent with your branding.\n\nWith a custom email domain, you can elevate your business correspondence and further establish your brand's credibility. It's a simple change that can make a significant difference, allowing you to continue growing your floral empire.\n\nI invite you to explore how we can help at wegetyou.online/domain-email. \n\nI look forward to hearing from you and discussing how we can make the online representation of your business as unique as the bouquets you create.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
96	46	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:36:09.240245	Enhancing Tiger Lilys Online Presence with a Professional Domain Email	Hello,\n\nI hope this message finds you well. I recently had the pleasure of visiting https://www.tigerlilyflowers.co.uk/ and was truly captivated by your exquisite flower arrangements and the elegant simplicity of your website.\n\nAs someone who understands the importance of a strong online presence for businesses like Tiger Lily, I couldn't help but notice a potential opportunity for you to further enhance your digital footprint. A professional domain-branded email can provide a more cohesive and polished image to your customers, which aligns perfectly with the quality and professionalism your floral designs represent.\n\nMy company, WeGetYou.Online, specializes in providing businesses with professional domain-branded emails. I am confident that our service can add value to Tiger Lily by establishing a more uniform online identity.\n\nIf you're interested in possibly exploring this further, I would love to hear from you. You can also learn more by visiting https://wegetyou.online/domain-email.\n\nLooking forward to potentially working with you!\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
97	47	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:36:24.507961	Enhancing Fleurtations Florist Bristol Online Presence	Good morning,\n\nI hope this email finds you well. I came across your website, Fleurtations Florist Bristol, and was truly captivated by the wonderful selection of floral arrangements and plants you offer. Your commitment to quality and customer service is evident and it's clear why your business is a favourite among Bristol locals.\n\nAs the founder of WeGetYou.Online, I help businesses like yours enhance their online presence and professional image. One way we do this is by providing professional domain-branded email addresses, which add an extra layer of credibility and uniqueness to your business. \n\nImagine how much more professional it would look if your email address matched your business domain, like orders@fleurtations-bristol.co.uk. This small tweak can make a big difference in how your business is perceived.\n\nWould you be interested in learning more about how a domain-branded email can benefit Fleurtations Florist Bristol? If so, I'd be more than happy to provide further information.\n\nLooking forward to your positive response.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
98	48	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:36:39.562524	Enhance Flowers By Allas Online Presence with a Branded Domain Email	Good morning,\n\nI recently had the pleasure of exploring your website Flowers By Alla. The exquisite range of floral arrangements and dedication towards providing a personalized experience is genuinely commendable. \n\nWhile admiring your unique designs, I wondered how you could further strengthen your online presence and brand identity. My company, WeGetYou.Online, specializes in setting up professional domain branded emails for businesses. A branded email can give your communication a more professional look, aligning perfectly with the high-quality service you offer.\n\nImagine sending out emails from an address like 'contact@FlowersByAlla.com,' which immediately enhances your brand recognition and fosters trust among your clientele. \n\nIf you're interested in learning more, I'd be happy to discuss how we can support Flowers By Alla in strengthening its online presence. \n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
99	49	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:36:55.052545	Enhance Your Floral Communications with a Domain Branded Email	Hello,\n\nI recently had the pleasure of exploring your website, Edith Wilmot Bristol Florist, and I'm quite impressed with your exquisite array of floral arrangements. Your passion for creating beautiful bouquets is evident and it's clear that every petal counts in your business.\n\nWhile browsing, I noticed that you offer same-day delivery services, which is an excellent feature that surely keeps your customers happy and coming back for more. In this fast-paced online world, it's all about customer convenience, and you've nailed just that!\n\nNow imagine matching this top-notch service with a professional domain branded email. It could take your business communication to the next level, ensuring that your online presence is as elegant and refined as your floral arrangements. \n\nI'm Ryan from WeGetYou.Online. We specialize in setting up professional domain branded emails that help businesses like yours enhance their brand credibility and improve customer trust.\n\nIf you're interested to know how a professional domain branded email can compliment your business, just reply to this email and I'd be more than happy to provide more information. \n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
100	50	23	sent	2025-08-18 20:27:30.597712	0	0	\N	2025-08-18 20:37:11.680272	Enhance Your Blooming Business with a Branded Email	Hello,\n\nI hope this message finds you well. I recently visited your website and was truly captivated by the beautiful floral arrangements at Don Gay’s Florist Bristol. Your dedication to quality, variety, and customer satisfaction is truly commendable.\n\nAs a florist, you understand the importance of personal touches. Just as you add a personal touch to your floral arrangements, I believe you can do the same for your business communications. \n\nMy company, WeGetYou.Online, specializes in creating professional domain-branded email addresses. A bespoke email address that includes your business name not only looks more professional, but it also helps in reinforcing your brand every time you send an email. \n\nI would love the opportunity to discuss how we could possibly add a touch of personalization to your business communication. How does your schedule look for a quick chat sometime next week?\n\nJust reply if you'd like to learn more.\n\nBest Regards,\nRyan\nFounder | WeGetYou.Online\nHttps://wegetyou.online
188	106	34	sent	2025-08-22 12:57:45.306676	0	0	c8242912-4883-4964-9f6c-57509880e00d	2025-08-22 13:00:39.901083	Rosalyn: elevate client trust with email	Hi Rosalyn,\n\nI spent a moment on Rosalyn Jay Photography and your emphasis on storytelling and natural light clearly comes through. Your portfolio feels personal and trustworthy, which is exactly what clients seek when you’re capturing some of life’s most meaningful moments.\n\nOne quick note: your brand already communicates warmth through clean design and a client-first vibe. A professional domain branded email (for example, you@rosalynjayphotography.co.uk) can amplify that trust at every touchpoint—from inquiry to final delivery. It helps reassure clients you’re a serious, established photographer and reduces hesitation during the booking process.\n\nWe help photographers present a consistent, credible image while keeping your existing domain. The goal is to remove friction in the client journey: clear sender recognition, a cohesive signature, and a simple way for clients to reach you.\n\nIf this sounds useful, you can learn more at wegetyouonline.co.uk/domain-email. I’d be glad to run through a quick overview or set up a sample to show how it looks in practice.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
64	42	23	sent	2025-08-18 20:25:50.528397	1	0	seq_42_23_81faff91	2025-08-18 20:28:28.872105	Let Blooms The Florist Emsworth Blossom Online with a Branded Email	<p>Dear there,<br>\n</p><p><br>\nI’ve been admiring Blooms The Florist Emsworth and the stunning floral arrangements you provide. Your passion for flowers is evident and it's clear why you're a favourite in Emsworth.<br>\n</p><p><br>\nJust like a bouquet, a branded email can make a lasting impression. As the Founder of WeGetYou.Online, I help businesses like yours create professional domain-branded emails that stand out. Our service not only enhances your online presence but also adds a personal touch to your email communications.<br>\n</p><p><br>\nLet’s help Blooms The Florist Emsworth bloom online. Visit wegetyou.online/domain-email to see how a branded email can help you grow.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
60	38	23	sent	2025-08-18 20:25:50.528397	1	0	seq_38_23_c92ac5ce	2025-08-18 20:27:56.139652	Blooming Online Presence with Branded Emails?	<p>Dear there,<br>\n</p><p><br>\nI hope this message finds you well. I stumbled upon Full Bloom Hayling's website today and was utterly captivated by the floral arrangements showcased. Your artistry truly stands out in the florist industry.<br>\n</p><p><br>\nWhile admiring your work, I noticed an opportunity for Full Bloom Hayling to bloom even more vibrantly online. At WeGetYou.Online, we provide professional domain branded emails that can boost your credibility and grant you a unified online presence. It's a simple change that can have a significant impact. <br>\n</p><p><br>\nWould you be interested in exploring this further? I invite you to learn more at wegetyou.online/domain-email. <br>\n</p><p><br>\nLooking forward to helping Full Bloom Hayling flourish online.<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
72	50	23	sent	2025-08-18 20:25:50.528397	1	0	seq_50_23_f40cfddc	2025-08-18 20:29:25.865495	Blooming digital presence for Don Gay’s Florist Bristol	<p>Dear team at Don Gay’s Florist Bristol,<br>\n</p><p><br>\nAs a florist, you know the importance of first impressions. Just as a beautifully arranged bouquet catches the eye, a professional domain branded email can give your digital presence a fresh, polished look.<br>\n</p><p><br>\nAt WeGetYou.Online, we can provide you with a bespoke email address that reflects the unique identity of Don Gay’s Florist Bristol (<a href="https://www.dongaysflorist.co.uk/).">https://www.dongaysflorist.co.uk/).</a> Imagine instead of generic gmail or yahoo addresses, your emails come from @dongaysflorist.co.uk!<br>\n</p><p><br>\nI invite you to explore further how our service can help add value to your brand at wegetyou.online/domain-email.<br>\n</p><p><br>\nLooking forward to helping you bloom online!<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
106	53	27	sent	2025-08-20 06:08:32.81238	1	0	b8d36cf9-3ce6-4ff3-a7e2-62700af11f09	2025-08-20 06:09:04.836572	Elevate Your Personal Training Business with Professional Domain Email	Hi there,\n\nAs a fellow fitness enthusiast, I understand the importance of building a relationship of trust with your clients. That's why I wanted to introduce you to our professional domain branded email service at WeGetYou.Online. \n\nHaving a personalized email address like [theirname]@yourbusiness.com not only enhances your credibility as a personal trainer but also strengthens the bond of trust with your clients. \n\nVisit wegetyou.online/domain-email to learn more about how a professional domain email can elevate your personal training business. Let's build a strong foundation together for your success.\n\nBest regards,\n\nRyan\nFounder\nWeGetYou.Online\nryan@wegetyou.online
128	69	30	sent	2025-08-20 14:05:53.767683	0	0	708837d8-381d-41ba-ae68-9fe39c412e21	2025-08-20 14:18:05.254805	Strengthen client trust with a branded email	Hi there,\n\nI’ve taken a quick look at motivationfitnesspt.co.uk and I’m impressed by your focus on personalized training and accountability that drives real results for clients. That trust-based relationship is the cornerstone of long-term success for fitness pros, and it’s something we’ve helped many coaches strengthen at We Get You Online.\n\nImagine every message your clients receive—from onboarding and check-ins to progress updates—coming from a professional, recognizable domain rather than a generic inbox. A branded domain email boosts credibility, reduces confusion, and reinforces consistency across the client journey. It also helps your emails land in inboxes more reliably, so important updates (workouts, nutrition notes, booking reminders) aren’t missed.\n\nA simple step like adopting a domain email can be paired with a clean, branded signature and a standard onboarding template to establish trust from the very first touchpoint.\n\nIf you’d like to explore how a domain email can fit your client experience, you can see details here: wegetyouonline.co.uk/domain-email. I’m happy to tailor ideas for Motivation Fitness PT.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
129	68	30	sent	2025-08-20 14:05:53.767683	0	0	b2f6802a-3f21-45bf-9c45-5bb19b181c10	2025-08-20 14:20:39.798847	Boost client trust with branded emails	Hi there,\n\nFrom ENB Fitness' site, it's clear you focus on personalized training and real client results. That emphasis on trust is what keeps clients showing up, sharing goals, and following through.\n\nA simple step many coaches overlook is using a branded domain email for client communications. A name like yourname@enbfitness.co.uk signals professionalism and helps clients feel messages are coming from you, not a random inbox. It reduces confusion, improves deliverability, and reinforces the trust you’ve built in sessions. Many trainers also find that clients respond faster to clear, branded emails that include appointment links or progress checks.\n\nPair this with a clean signature featuring your logo and a direct booking link to keep conversations efficient and consistent.\n\nI’d love to show how a branded email strategy can fit ENB Fitness without disrupting your current workflow. If you’re curious, you can explore what we offer at wegetyouonline.co.uk/domain-email, including practical benefits and quick setup options.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
44	24	23	sent	2025-08-18 20:25:50.528397	1	0	seq_24_23_644b6261	2025-08-18 20:26:12.960825	Bloom into a new digital era with a branded domain email	<p>Dear team at Mapperley Blooms,<br>\n</p><p><br>\nI've admired the beauty of your floral arrangements on your website, and I can see the dedication you put into crafting each piece. As someone who also values craftsmanship and attention to detail, I believe I can help Mapperley Blooms bloom even further online.<br>\n</p><p><br>\nI'm Ryan, the founder of WeGetYou.Online. We specialize in creating professional domain branded emails that reflect the uniqueness of a brand. Having a branded domain email not only enhances your online presence but also adds credibility to your business.<br>\n</p><p><br>\nImagine sending emails from a custom domain like 'name@mapperleyblooms.com'. It speaks volumes about your commitment to your business and gives a professional touch to your communication.<br>\n</p><p><br>\nCurious to see how this could work for you? Visit <a href="https://wegetyou.online/domain-email">https://wegetyou.online/domain-email</a> for more information or to get started.<br>\n</p><p><br>\nLooking forward to helping Mapperley Blooms reach new heights!<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
56	35	23	sent	2025-08-18 20:25:50.528397	1	0	seq_35_23_78799a58	2025-08-18 20:27:34.85561	Blooming online? Boost your brand with a custom domain email!	<p>Dear Little & Bloom Team,<br>\n</p><p><br>\nAs a florist, you understand the importance of aesthetics, details, and personalization. This is why I thought of Little & Bloom when I was thinking about how a domain-branded email could enhance your brand's digital presence.<br>\n</p><p><br>\nAt WeGetYou.Online, we offer professional domain-branded emails that not only look professional but also increase your brand recognition and trust with every email you send. <br>\n</p><p><br>\nImagine sending emails from an address like "bloom@littleandbloom.com" - it's a small detail that makes a big difference.<br>\n</p><p><br>\nCheck out this link (wegetyou.online/domain-email) to see how simple it is to set up and the benefits it can bring to your business.<br>\n</p><p><br>\nLet's bloom together online!<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
105	53	27	sent	2025-08-20 06:07:38.770963	1	0	14a8e985-b165-4b38-8743-d8a8ffeaab7b	2025-08-20 06:08:34.785674	Elevate your personal training business with a professional domain email	Hi there,\n\nAs a fellow entrepreneur in the fitness industry, I understand the importance of building trust with your clients. Your business relies on the strong relationship you create with each individual you work with. That's why having a professional domain email, like yourname@yourbusiness.com, can help elevate your personal training business to the next level.\n\nAt WeGetYou.Online, we specialize in providing customized domain emails that reflect the professionalism and dedication you bring to your clients. Visit our site at wegetyou.online/domain-email to learn more about how this simple yet impactful tool can benefit your business.\n\nTake the first step towards solidifying your brand and enhancing your client relationships. Start with a professional domain email today.\n\nBest,\nRyan\nFounder\nWeGetYou.Online\nryan@wegetyou.online
130	73	30	sent	2025-08-20 14:05:53.767683	0	0	0d985902-8995-45ad-940b-91bebd32c9fe	2025-08-20 14:23:18.683878	Elevate New Physique with branded email	Hi there,\n\nI recently came across New Physique Personal Training and was struck by your client-centered approach to personalized fitness programs and clear progress storytelling. That emphasis on results and trust is exactly what keeps clients motivated and coming back.\n\nAt We Get You Online, we help coaches like you strengthen that trust through a domain-branded email. In personal training, trust is built not just through workouts but through the way you communicate—consistent, professional, and instantly recognizable. A branded domain email signals reliability from the first hello and reduces any hesitation a potential client might feel.\n\nA couple of quick wins you can start with:\n- Use a consistent sender name and your domain email for all client communications, so messages are instantly recognizable.\n- Include a concise signature with your name, title, and direct contact to reinforce accessibility and care.\n\nIf you’d like, I can share a quick, no-pressure example of how a domain-branded email could look for New Physique. Learn more at wegetyouonline.co.uk/domain-email.\n\nLooking forward to hearing from you,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
189	108	34	sent	2025-08-22 12:57:45.306676	0	0	2bf28274-b9d2-40d9-8ab5-935f49c5ffba	2025-08-22 13:03:00.837577	A branded email idea for Beau-Louise Photography	Hi Jane,\n\nI spent a moment on Beau-Louise Photography and was struck by how your wedding and portrait sessions feel intimate and cinematic, with an emphasis on genuine moments. That trust between you and your clients is the core of your business, especially when you’re asked to freeze life’s most meaningful occasions.\n\nOne simple way to strengthen that trust from first contact? A professional domain-branded email. When clients see beau-louisephotography.co.uk in the from address, they feel reassurance and consistency—two fundamentals of a strong photographer-client relationship. It signals you’re serious, accessible, and committed to quality from inquiry through delivery.\n\nOur domain-based email service makes setting this up easy, with your own beau-louisephotography.co.uk mailbox and a clean, brand-aligned signature. It’s not just about looks; it’s about trust-building: clear contact paths, response expectations, and a cohesive brand experience.\n\nIf you’d like to explore how this could fit Beau-Louise Photography, you can find details at wegetyouonline.co.uk/domain-email. Happy to tailor a quick plan around your workflow.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
139	29	24	sent	2025-08-21 20:29:42.843529	0	0	114bbe94-95f9-41a6-971c-b4fd5c112201	2025-08-21 20:30:59.313776	New ideas for About Flowers email	Hi there,\n\nFollowing up on my previous messages about a domain-branded email for About Flowers, I wanted to share a practical, easy-to-implement approach that can start delivering benefits in days rather than weeks.\n\nWhy it matters: a branded sender strengthens trust, boosts recognition, and can improve reply rates from customers planning floral arrangements.\n\nHere’s a simple plan you can start with:\n- Create a branded inbox, such as hello@aboutflowers.co.uk, and a matching signature with your store hours and contact details.\n- Verify SPF, DKIM, and a DMARC policy to protect deliverability and prevent misrouting.\n- Draft a short welcome/ordering flow: one introductory email that confirms services and next steps, followed by a reminder for delivery times or pickup windows.\n- Keep email templates aligned with your site: consistent colors, logo, and friendly tone.\n- Monitor opens and responses to refine subject lines and timing.\n\nIf you’d like, I can tailor this to About Flowers’ seasonal promos and local customers. A quick 20-minute chat could map these steps to your calendar.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
108	55	29	sent	2025-08-20 08:23:25.90034	0	0	1ec9c731-ffda-452b-9f63-9141ce415200	2025-08-20 08:24:00.906878	Elevate Your Personal Training Business with Professional Branded Email	Hi Ryan,\n\nAs a CEO in the fitness industry, trust is key between personal trainers and clients. At We Get You Online, we understand the importance of building that trust through professional communication. That's why we offer professional domain branded email services tailored to personal trainers like yourself.\n\nHaving a branded email not only enhances your credibility but also strengthens the relationship with your clients. Visit wegetyouonline.co.uk/domain-email to learn more about how our service can add value to your business.\n\nLooking forward to helping you elevate your online presence,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
109	56	29	sent	2025-08-20 09:46:44.185623	0	0	97241d5e-e8ff-47ac-be27-9591248fc766	2025-08-20 09:47:07.193713	Subject: Elevate Your Personal Training Business with a Professional Domain Email	Hi there,\n\nAs a personal trainer, trust and communication are key in building strong client relationships. That's why I wanted to introduce you to our professional domain branded email service. \n\nHaving a branded email not only enhances your professional image but also boosts credibility and trust with your clients. Imagine your clients receiving emails from yourname@yourbusiness.com - it adds a personal touch that sets you apart.\n\nLearn more about how a domain email can benefit your personal training business at wegetyouonline.co.uk/domain-email. Take the next step in elevating your online presence.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
107	54	28	sent	2025-08-20 07:43:36.418043	1	0	584e0e94-34f5-45d1-93c8-f40287167fd2	2025-08-20 07:44:21.430963	Elevate Your Personal Training Business with a Professional Domain Email	Hi there,\n\nAs a personal trainer, building a relationship of trust with your clients is crucial to your success. That's why having a professional domain email like [theirname]@yourbusiness.com can make a big difference in how you're perceived by potential clients.\n\nAt WeGetYou.Online, we specialize in helping personal trainers like you establish a strong online presence with personalized domain emails. This simple yet powerful tool can elevate your business and instill confidence in your clients.\n\nInterested in learning more about how a professional domain email can benefit your personal training business? Visit wegetyou.online/domain-email and take the first step towards enhancing your online credibility.\n\nLooking forward to helping you succeed,\n\nRyan\nFounder\nWeGetYou.Online\nryan@wegetyou.online
132	79	30	sent	2025-08-20 14:31:36.994755	0	0	15c26e31-1059-4426-866e-95d298986069	2025-08-20 14:33:05.019653	Build trust with branded email	Hi Kimmy,\n\nI came across Get Fit with Kimmy and was impressed by your commitment to personalized coaching, consistent accountability, and real client transformations. Your emphasis on trust between trainer and client—clear communication, reliable scheduling, and transparent progress tracking—really stands out.\n\nI help small service businesses strengthen that trust with a simple yet powerful asset: a domain-branded email. A dedicated address communicates professionalism and keeps your brand front and center in every message, from welcome emails to progress reports. Clients feel more confident when they see a consistent sender name and domain, which supports retention and referrals—critical for growing a personal training business.\n\nPro tip: align your branded email with your existing booking and client update flows. It reduces confusion, builds familiarity, and reinforces care.\n\nIf you’d like, I can share a quick example of how the first week’s client communications could look with a branded domain, and we can tailor it to Get Fit with Kimmy.\n\nIf you’re curious, take a quick look at wegetyouonline.co.uk/domain-email.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
133	77	30	sent	2025-08-20 14:31:36.994755	0	0	578e9ee3-9b64-4f2a-a335-e33251a7330f	2025-08-20 14:34:56.749964	Boost client trust with a branded email	Hi Jack,\n\nI recently explored Jack Williamson PT and was impressed by your focus on personalized training and real results for clients. Your emphasis on accountability and clear communication really resonates because trust is the foundation of long-term success for a personal trainer.\n\nA small but powerful upgrade I see many high-performing coaches adopting is a branded domain email. Having jack@jackwilliamsonpt.com, instead of a generic address, reinforces professionalism, makes it easier for clients to recognize you in their inbox, and reduces friction when they reply to progress updates or booking inquiries. It also sets a consistent, trusted touchpoint across your client communications.\n\nIf you’re curious, I can show how a branded domain email integrates with your site and scheduling tools. You can explore how this can work for you at wegetyouonline.co.uk/domain-email.\n\nCheers,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
131	80	30	sent	2025-08-20 14:31:36.994755	1	0	ddc970a4-ad53-4a03-89ed-8b917e335363	2025-08-20 14:32:17.001161	Boost client trust with branded emails	Hi Lee,\n\nI spent a moment on Dedicated Coaching's site and was impressed by your emphasis on personalised coaching and real client results. In the fitness space, trust is earned through clear, reliable communication—something your clients rely on session after session.\n\nA branded domain email helps you reinforce that trust every time you reach out. Instead of using a generic address, a dedicated email tied to dedicatedcoaching.co.uk makes onboarding smoother, improves the credibility of progress updates, and reduces the chances messages get missed. It creates a cohesive client journey—from initial inquiry to weekly check-ins and program PDFs—so clients feel supported and confident in their plan.\n\nIf Dedicated Coaching is looking to elevate client experience and conversions, I’d be glad to show how a domain email aligns with your goals. You can learn more at wegetyouonline.co.uk/domain-email, or reply to this email and we can quick-schedule a 15-minute chat.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
140	27	24	sent	2025-08-21 20:29:42.843529	0	0	f8395418-903a-41ea-b4a5-d004e83f4e16	2025-08-21 20:31:53.87081	Quick wins for Garlands online presence	Hi there,\n\nFollowing up on my earlier note about Garlands’ online presence—and the idea of a domain-branded email for your team—I wanted to share a few practical steps that can make a quick, measurable impact for a local florist.\n\n- Local visibility: claim and optimize Google Business Profile with up-to-date hours and delivery areas; post fresh bouquet photos and encourage recent customers to leave short reviews.\n\n- Product clarity: ensure each bouquet category on garlandsofllandaff.co.uk has a clear description, vibrant images, delivery details, and an obvious order button.\n\n- Site speed and mobile: compress images, enable lazy loading, and verify your site looks great on phones so customers can order easily.\n\n- Trust signals: add a simple contact form and a visible phone number on every page, plus a straightforward delivery and returns policy.\n\n- Quick win option: I can deliver a compact 15-minute audit with concrete, page-by-page tweaks tailored to Garlands.\n\nWould you be open to a quick chat this week to review these ideas and pick a couple to start with?\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
190	107	34	sent	2025-08-22 12:57:45.306676	0	0	7b8b7c30-fa33-4e7f-847d-90527c5e130a	2025-08-22 13:04:22.012378	Lucy, boost client trust with branded email	Hi Lucy,\n\nI came across Lucyewarner Photography and was struck by how you capture intimate, authentic moments for couples and families. Your storytelling clearly helps clients feel seen and confident in choosing you for life’s meaningful moments.\n\nOne of the quiet challenges photographers face is maintaining that same level of trust through every email—from initial inquiry to session prep and final galleries. A branded domain email helps you carry that trust into every interaction: it looks professional, reinforces your brand in every thread, and reduces the chance messages go to spam or get overlooked.\n\nWith a domain email, Lucyewarner Photography can present a consistent signature, use clear subject lines, and ensure inquiries land in a dedicated inbox that you check regularly. It’s a small change that can boost client confidence before you even meet.\n\nIf you’d like to see how easy it is, we’ve got a simple path for photographers at wegetyouonline.co.uk/domain-email. Could we schedule a quick 10-minute chat to explore what this would look like for your brand?\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
134	78	30	sent	2025-08-20 14:31:36.994755	1	0	0828e5b1-9062-41bb-8181-1d6b8c89bc01	2025-08-20 14:36:35.181733	Stuart, boost trust with a branded email	Hi Stuart,\n\nI spent some time exploring Motiv8 Personal Training and was impressed by your client-first approach—tailored workouts, clear progress checks, and a focus on sustainable results. In personal training, trust is the key currency; clients invest in you to guide them through sensitive goals and routines, often for months at a time. Small, consistent communications can reinforce that trust.\n\nOne practical insight: switching to a professional branded email domain dramatically strengthens credibility. When clients see motiv8personaltraining.co.uk in your messages, it reduces confusion and signals consistency—every email from you feels like it comes from the same trusted coach, not a generic inbox. That small shift can boost engagement and retention.\n\nIf you’re curious how a branded domain email fits with your client journey, I’d be glad to share a simple setup that doesn’t add admin burden. You can learn more here: wegetyouonline.co.uk/domain-email.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
141	28	24	sent	2025-08-21 20:29:42.843529	0	0	5ad19d37-4f4f-4f3b-b44d-0c9445bbd7fb	2025-08-21 20:33:58.835612	Quick upgrade for Blodau Tlws email	Hi there,\n\nFollowing up on my earlier note about strengthening Blodau Tlws' digital presence with branded emails and a dedicated domain inbox, I wanted to share a practical angle that often yields quick wins for florists.\n\nKey ideas:\n- Use a domain-based address (e.g., info@blodau-tlws.co.uk) to boost trust with customers and avoid generic inboxes.\n- Align your email visuals with your site: logo, color palette, and tone to reinforce brand.\n- Simple deliverability checks: ensure the domain has SPF and DKIM; this can dramatically improve inbox placement for order inquiries and confirmations.\n- A concise welcome sequence: a 3-email flow that thanks customers, confirms orders, and shares care tips or seasonal arrangements; this can lift repeat bookings.\n\nIf helpful, I can draft a lightweight setup checklist and a ready-to-send initial welcome email tailored to Blodau Tlws, plus a couple of domain-email options for you to choose from.\n\nWould you be open to a 15-minute chat this week to review? No pressure—just practical next steps.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
142	33	24	sent	2025-08-21 20:29:42.843529	0	0	40f8d5a5-4cda-4ecd-a37f-be43015cc9f1	2025-08-21 20:35:52.887049	Small update to boost Jas and Floral online	Hi there,\n\nFollowing up on my previous note about a branded domain email for Jas and Floral, I wanted to share a couple of practical steps that can pay off quickly, even before a full setup.\n\nFirst, ensure your contact details on the site match your domain email. Consistency builds trust with local customers searching for bouquets and event florals.\n\nSecond, use a branded email address in outreach to clients and partners—it's more professional and improves email deliverability, reducing the chance of messages ending up in spam.\n\nThird, add a simple “Arrange a consultation” or “Book a delivery” CTA near the top of the homepage and in the footer of every page; pair with a direct contact email.\n\nIf you’d like, I can draft a quick, tailored plan for Jas and Floral, plus suggest a branded email option that can be live within a short timeframe. No hard sell—just practical steps to help more local orders and event bookings.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
143	30	24	sent	2025-08-21 20:29:42.843529	0	0	af7da203-769d-4693-9a06-aeab4dc2df3d	2025-08-21 20:38:10.14207	Quick branding tip for Wild Meadow Floral	Hi there,\n\nJust following up on my previous emails about a domain-branded email for Wild Meadow Floral. I wanted to share a couple of practical steps you can apply now to strengthen customer trust and streamline communications.\n\n- Create a small set of branded inboxes: hello@, orders@, and support@ under wildmeadowfloral.co.uk. This signals professionalism and makes it easy for customers to reach the right team.\n\n- Align your email signatures and templates with your brand: include your logo, colors, and a concise contact line. A consistent signature boosts recognition and reduces confusion on order confirmations and delivery notices.\n\n- Simple automations: set up automatic order confirmations within an hour of purchase, and a friendly delivery update after dispatch. These reduce follow-ups and improve the customer experience during peak seasons.\n\n- Security basics: ensure SPF and DKIM are enabled for your domain to protect inbox deliverability.\n\nIf helpful, I can map a tailored 15-minute plan for your brand. Happy to help you decide the best next steps.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
144	32	24	sent	2025-08-21 20:29:42.843529	0	0	fb33be85-6745-475b-9e31-ceab2c2eab15	2025-08-21 20:40:06.729926	Domain email options for Sweet Peony	Hi there,\n\nFollowing up on my earlier note about branded domain email for Sweet Peony Florist, I wanted to offer a practical angle that can save time and boost trust with clients.\n\nA cohesive, domain-based email presence can improve inquiry response times, convey professionalism for weddings, and reduce misdirected messages. Here are a few quick steps you can consider:\n\n- Use a primary address on your existing domain, e.g. hello@sweetpeonyfloral.co.uk, for general inquiries.\n- Create role-based aliases such as weddings@sweetpeonyfloral.co.uk and support@sweetpeonyfloral.co.uk, then forward them to your current inbox.\n- Add SPF, DKIM, and DMARC records to protect deliverability and reputation.\n\nIf you’d like, I can map a simple starter setup for Sweet Peony Florist and provide a 1-page checklist you can hand to your team. A 15-minute chat could cover which inboxes to create and a quick technical path to get them live.\n\nWould you be open to a short conversation this week? I’m happy to tailor the plan to your schedule.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
191	105	34	sent	2025-08-22 12:57:45.306676	0	0	3165c133-0960-4bef-a849-46a20bcab08d	2025-08-22 13:06:22.994995	A trust boost for Roz Pike Photography	Hi Roz,\n\nI recently visited Roz Pike Photography and was struck by how your wedding and portrait work feels intimate and authentic—the kind of moments families remember for a lifetime. Your storytelling across galleries clearly centers on client comfort and connection.\n\nPhotographers are trusted with milestones, and the first contact sets the tone. A professional, domain-branded email reinforces that trust before you say a word. Instead of a generic address, Roz@rozpike.com signals steadiness, care, and a premium experience.\n\nWe Get You Online helps photographers move to a branded domain email quickly and smoothly, with a setup that fits your current workflow. It also ensures every inquiry looks consistently professional, from first hello to contract.\n\nIf this resonates, you can see how domain email could support Roz Pike Photography at wegetyouonline.co.uk/domain-email. Would you be open to a quick 15-minute chat next week to explore options?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
127	72	30	sent	2025-08-20 14:05:53.767683	1	0	8b826674-6692-4fe7-932e-5012ae118870	2025-08-20 14:15:51.049032	A branded email edge for SNL Fitness	Hi there,\n\nI spent a moment exploring SNL Fitness and your work with clients to hit personal goals. In fitness, trust is built through clear, reliable communication as much as through workouts. A branded domain email—like you@snlfitness.com—helps you start conversations on a professional, credible note and keeps client messages organized under one trusted domain.\n\nHere are a couple of practical benefits I see for SNL Fitness:\n- Immediate credibility: clients and prospects feel more confident when replies come from a recognizable domain.\n- Streamlined communication: consistent email addresses, signatures, and booking confirmations reinforce accountability.\n- Better deliverability and privacy: domain-based emails pair with reliable hosting and safer opt-ins, reducing miscommunication.\n\nI’d love to show you how this small change can align with your client-first approach. You can learn more at wegetyouonline.co.uk/domain-email, and I can tailor a quick plan around SNL Fitness’ workflow.\n\nWould you be open to a short 15-minute chat next week? I’m happy to adjust to your schedule.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
135	81	33	sent	2025-08-20 19:57:51.109605	1	0	12aae7f3-dfda-4b48-9584-ff7bd46d04cb	2025-08-20 19:58:01.121647	Quick win for Vezra UK LTD online	Hi Ryan,\n\nI’ve been looking at Vezra UK LTD’s online presence and see room for a few practical tweaks that can lift inquiries without changing your core offering. At We Get You Online, we help leaders like you convert more of your site visitors into conversations.\n\nHere are three simple, high-impact ideas you could implement quickly:\n- Place a clear value proposition above the fold so first-time visitors know the benefit in 3 seconds.\n- Make contacting you effortless with a short form or direct CTA in the top area.\n- Add 2 short client outcomes or logos near the CTA to build credibility fast.\n\nIf any of these align with your current priorities, I’d be happy to share a concise 3-point audit tailored to Vezra UK LTD and show practical steps you can deploy in days. Would you be open to a 15-minute chat to explore this?\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
136	82	33	sent	2025-08-21 00:03:49.669854	1	0	fc3a7fa5-2fbf-4c13-875f-ce170929bb98	2025-08-21 00:04:11.679747	Could your online presence use a tune-up?	Hi there,\n\nI’m Ryan, founder of We Get You Online. We help businesses attract more customers and grow revenue by tuning up online presence and site performance. Even small changes can unlock a meaningful lift in qualified leads.\n\nI don’t know your exact goals yet, but in my work with similar teams, three areas tend to move the needle: clarity, credibility, and conversion. A quick, 5-minute assessment can spot opportunities like: is your homepage clearly communicating your value within the first few seconds? Are you capturing local search traffic with a consistent business profile and solid citations? Are your top pages guiding visitors to a simple next step?\n\nIf you’d like, I can share a concise plan with 2–3 practical ideas you can test in the next two weeks—no fluff, just actionable steps tailored to your business. I’m happy to jump on a 15-minute call to discuss goals and priorities. What times work for you this week or next?\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
193	104	34	sent	2025-08-22 12:57:45.306676	1	0	d5a2d04e-bc7f-4df9-aa75-b816a184c8ec	2025-08-22 13:11:01.098866	Elevate Irina GS Photography with branded email	Hi Irina,\n\nI enjoyed browsing Irina GS Photography and was drawn to the way your portfolio centers on real moments and natural light. Your approach seems to put client connection first, which is exactly what people remember when they look back at their photos.\n\nAt its core, a photographer’s trust relationship is built through every email and consultation. A professional domain-branded email (for example, yourname@irinagsphoto.co.uk) subtly signals care, consistency, and reliability—elements clients instinctively rely on when you’re capturing life’s big moments.\n\nWe Get You Online helps photographers like you adopt a trusted domain email that aligns with your brand, reduces confusion, and improves reply rates. It’s not about tech; it’s about reinforcing trust at every touchpoint—from initial inquiry to delivery of galleries.\n\nIf you’re curious, we have a simple, no-pressure setup and a quick guide on how branded email can boost client confidence. Learn more at wegetyouonline.co.uk/domain-email.\n\nHappy to tailor a plan to your site and workflow.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
199	61	31	sent	2025-08-23 13:45:02.611598	0	0	0e4f7745-b8a7-452a-89b1-b1bbb00bc4cc	2025-08-23 13:48:06.307923	Quick branding boost for Cordell	Hi Cordell,\n\nFollowing my note about elevating client trust with branded email, I took another look at Cordell Wilson Personal Training and saw a few practical tweaks you can start this month to boost credibility and client momentum.\n\n- Welcome template: a short intro to your approach, a client success snippet, and a clear next step (booking a consult or receiving a sample plan). It sets trust from day one.\n- Consistent header and signature: your logo, a one-line specialty (custom fitness programs that deliver results), and 2 links to testimonials or case studies. Consistency lowers friction for new clients.\n- Lightweight onboarding sequence: an early check-in after 3 days, a progress snapshot at week 1, and a monthly transformation highlight. These touchpoints keep results front and center.\n\nIf you’d like, I can draft 2–3 ready-to-use email templates tailored to Cordell Wilson Personal Training and share a quick, actionable email audit of your current messages.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
114	63	30	sent	2025-08-20 13:43:11.990249	0	0	9f8bf49a-0585-4c06-8282-445b07abc317	2025-08-20 13:45:15.143157	Your branded email for 223ROC Boxing	Hi there,\n\nI’m Ryan, founder of We Get You Online. I spent a moment on 223ROC Boxing and was impressed by how you blend boxing-focused fitness with clear coaching, helping clients build strength and confidence.\n\nA quick insight: in personal training, trust is built through consistent, professional communication. Clients decide to train with you not only for technique but for how safe and supported they feel in every interaction. A branded email domain (for example yourname@223rocboxing.co.uk) reinforces that trust from the first contact—every message, reminder, or progress update signals professionalism.\n\nA simple shift can make a big difference: adopt a branded domain email across client communications, from inquiry responses to session reminders. It reduces confusion, improves recognition, and reinforces your coaching brand with every message. If you’d like, we can help implement a clean domain email strategy tailored to your workflow.\n\nLearn more at wegetyouonline.co.uk/domain-email, or tell me a good time for a quick chat.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
115	61	30	sent	2025-08-20 13:43:11.990249	0	0	941e414f-0172-4719-8373-a55b3e9f7ea1	2025-08-20 13:46:49.990462	Cordell: Elevate client trust with branded email	Hi Cordell,\n\nI’m Ryan, founder of We Get You Online. I took a moment to learn about Cordell Wilson Personal Training and your commitment to customized fitness programs and solid client results. In personal training, trust isn’t built only in sessions—it shows up in every email, reminder, and progress note clients see. A domain-branded email can reinforce that trust at every touchpoint.\n\nThree practical benefits you can expect:\n- Credibility: emails from cordellwilsonpersonaltraining.com look professional and reassure clients when sharing progress data.\n- Consistency: branded messages align with your training plans, invoices, and reminders, reducing confusion.\n- Verification: clients can easily verify who’s reaching out, increasing engagement and adherence.\n\nIf you’re curious how this could fit your business, check out wegetyouonline.co.uk/domain-email. It explains how a professional domain email integrates with your branding and tech stack.\n\nWould you be open to a quick 15-minute chat to map out a branded domain email plan for Cordell Wilson Personal Training? You can start here: wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
116	59	30	sent	2025-08-20 13:43:11.990249	0	0	54a4747d-d163-463d-8d50-919f5d17b705	2025-08-20 13:48:36.950919	Boost trust with a branded email	Hi there,\n\nI’ve been checking Ocean Fitness Poole and appreciate how you put client goals at the center of every plan. It’s clear you’re helping people build consistency, whether in the gym or online, which is exactly the kind of trust that turns inquiries into committed clients.\n\nI’m Ryan, founder of We Get You Online. We help personal trainers like Ocean Fitness Poole present a professional, cohesive image with a domain-branded email. Small things matter: a hello@oceanfitnesspoole.co.uk inbox looks more credible than a generic Gmail, and it reinforces the client relationship from the first contact through onboarding and check-ins.\n\nA few quick wins you could consider right away:\n- Use a single branded email for inquiries, another for client communications.\n- Add a consistent email signature with your logo, phone, and booking link.\n- Create short, friendly reply templates to speed up responses without sounding robotic.\n\nIf you’d like to see how a domain email could fit Ocean Fitness Poole, I can walk you through options that align with your brand. Learn more at wegetyouonline.co.uk/domain-email.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
117	62	30	sent	2025-08-20 13:43:11.990249	0	0	43a10af6-3521-4aa5-9637-c30433435077	2025-08-20 13:51:06.274169	Fit N Fresh: a branded email that builds trust	Hi Dan,\n\nI spent a moment looking at Fit N Fresh Coaching and was impressed by your focus on sustainable results and personalized coaching. Your emphasis on accountability and tailored plans naturally hinges on trust between trainer and client.\n\nAt We Get You Online, we help personal trainers project that trust through a simple, professional touch: a domain-branded email. A branded address (for example, hello@fitnfreshcoaching.com) signals consistency, reduces confusion, and reinforces your fitness philosophy every time you send an update, program, or nutrition tip. It also makes client communications easier to manage across devices and platforms.\n\nHere are quick moves you can adopt today:\n- Use a single branded email for onboarding and updates.\n- Align your signature with your brand colors and clear contact options.\n- Keep replies timely to reinforce reliability.\n\nIf you’re curious, I’d love to share a quick plan tailored to Fit N Fresh Coaching. You can learn more at wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
118	65	30	sent	2025-08-20 13:43:11.990249	0	0	e6bfb78e-76f3-40c4-be21-87fcd6ae7d23	2025-08-20 13:52:42.967256	Branded Email for Jane Cox Fitness	Hi Jane,\n\nI recently explored Jane Cox Fitness and was impressed by your emphasis on personalised training and measurable progress for clients. In the personal training space, trust between a coach and client is the foundation of every win—clear expectations, consistent communication, and privacy for sensitive plans. A professional, domain-branded email helps you reinforce that trust from the first hello.\n\nUsing you@janecoxfitness.co.uk instead of a generic address shows clients you treat their information with care and that every message comes from your studio, not a random inbox. It improves credibility at onboarding, keeps communications cohesive, and can boost response rates from new inquiries.\n\nIf you’re balancing PT programs, online coaching, and in-studio sessions, a trusted email identity reduces confusion and reinforces your brand with every touchpoint. It also makes it easier to sort client messages and protect personal data.\n\nWould you be open to a brief chat to explore how we can implement this for Jane Cox Fitness? You can learn more about our domain-email service at wegetyouonline.co.uk/domain-email.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
137	9	15	sent	2025-08-21 09:56:52.011099	0	0	a3eed725-699f-4d3b-84ca-41c3e507197d	2025-08-21 09:57:18.017551	Quick ideas to boost your digital presence	Hi there,\n\nFollowing up on my note about transforming your digital presence, I wanted to share a couple of practical steps we often implement with clients who want to grow online impact—without overhauling everything at once.\n\n- Quick audit checklist: ensure your homepage communicates a clear value within 3 seconds, mobile load times under 3 seconds, and your primary call-to-action is above the fold.\n- Conversion nudges: add a simple social proof section and a friction-free inquiry form (2 fields max) to capture qualified inquiries.\n- Visibility lift: implement clean, structured data for your services and testimonials, and align on 1-2 target keywords to start.\n\nIf any of these resonate, I can tailor a 15-minute quick-win plan based on your site and goals. Even if you’re not ready for a full project, these steps often map to a measurable lift in engagement and inquiries. If you'd like, I can share a 2-page miniguide with quick checklists and benchmarks tailored to small teams. No pressure—just a couple of ideas you can test in a week.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
119	60	30	sent	2025-08-20 13:43:11.990249	0	0	a28cdb10-c908-4c4b-851a-312077250279	2025-08-20 13:55:03.147423	NPerformance Poole: branded email	Hi there,\n\nI spent a few minutes looking at NPerformance Personal Training Poole and was impressed by your hands-on, client-first approach—tailoring workouts to goals, tracking progress, and celebrating real results. That personal connection is the heart of trust in a trainer-client relationship, and it’s what keeps clients showing up week after week.\n\nA branded domain email helps you protect and project that trust from the first touch. When clients see an address that matches npperformance.co.uk, they experience privacy, consistency, and professionalism—critical in onboarding, progress updates, and sensitive health conversations. It also makes your communications look cohesive across booking reminders, progress reports, and follow-ups.\n\nIf you’re exploring ways to strengthen that trust with your branding, I’d love to share how a professional domain email can work for NPerformance Poole. You can learn more about our domain-email service at wegetyouonline.co.uk/domain-email. Would you be open to a brief 15-minute chat this week to discuss potential value for your studio?\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
120	67	30	sent	2025-08-20 13:43:11.990249	0	0	270648f6-cc98-4f35-b297-eb44bde807cb	2025-08-20 13:57:35.158255	Build trust with a branded email for Addis	Hi James,\n\nI’ve taken a look at Addis Lifestyle & Fitness and your emphasis on personalised coaching and lifestyle changes really stands out. In the personal training space, clients decide who to trust in moments of uncertainty—from first inquiries to ongoing check-ins. A small, professional touch can make that decision easier: a branded domain email that mirrors your website.\n\nUsing james@addislifestylefitness.co.uk for client communications signals consistency and credibility, while separate emails for bookings, progress updates, and support help you stay organized and responsive. It reduces confusion, smooths onboarding, and reinforces the strong relationship you’re already building with clients.\n\nI help trainers like you implement professional domain emails that are easy to manage, secure, and scalable. If you’re open to it, we can explore a setup that fits Addis Lifestyle & Fitness and keeps client communications aligned with your brand.\n\nWould you be available for a quick chat this week? You can also see options at wegetyouonline.co.uk/domain-email.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
65	43	23	sent	2025-08-18 20:25:50.528397	1	0	seq_43_23_1a5f9179	2025-08-18 20:28:36.050788	Spruce Up Your Christmas Trees Portsmouth Brand with a Custom Domain Email	<p>Dear Christmas Trees Portsmouth Team,<br>\n</p><p><br>\nI hope this festive season is treating you well. My name is Ryan, founder of WeGetYou.Online, and I was intrigued by the impressive Christmas spirit you've fostered in Portsmouth.<br>\n</p><p><br>\nAs a company that provides professional domain branded email services, we understand the value of a memorable brand, just like your Christmas Trees. That's why I believe our service can bring even more magic to your business.<br>\n</p><p><br>\nBy switching to a domain email from us, you'll enhance your brand's credibility and recognition. Find out more at our website (wegetyou.online/domain-email) and see how we can help Christmas Trees Portsmouth stand out in every inbox.<br>\n</p><p><br>\nLet's make this Christmas more memorable with a custom domain email. Are you ready to spruce up your brand?<br>\n</p><p><br>\nBest Regards,<br>\nRyan<br>\nFounder | WeGetYou.Online<br>\nHttps://wegetyou.online</p>
121	66	30	sent	2025-08-20 13:43:11.990249	0	0	946efe1a-9e60-4548-8ddc-4e2b142d2e09	2025-08-20 14:00:18.389241	ZiaFitLife: Branded email for trust	Hi Anastazia,\n\nI’ve been looking at ZiaFitLife and your focus on personalized coaching and ongoing client support stands out. In the personal trainer space, trust is built not just by results but by how clearly you communicate—from onboarding to progress updates.\n\nA branded domain email can boost that trust. When clients see hello@ziafitlife.com or training@ziafitlife.com in their inbox, they know the message is from you, not a random address. It also improves deliverability, keeps communications consistent with your brand, and makes it easier for clients to reach you—even if you’re juggling online and in-studio sessions.\n\nBeyond appearances, you can use domain emails for consistent onboarding, appointment reminders, and progress reports—all with your voice and style. We can help set this up, migrate existing mail, and create simple, professional signatures.\n\nIf you’d like to explore how this could work for ZiaFitLife, take a look at wegetyouonline.co.uk/domain-email or just reply here and we can chat.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
146	26	24	sent	2025-08-21 20:29:42.843529	0	0	955f50bf-6952-4eb2-bcd5-e722ca3af9c8	2025-08-21 20:45:13.073771	A simple branding boost for Art of Flowers	Hi there,\n\nFollowing up on my earlier note about a domain-branded email for Art of Flowers Nottingham, I wanted to share a quick, practical next step that often yields noticeable results without changing your current workflow.\n\nA branded address like hello@artofflowersnottingham.co.uk can elevate trust, improve deliverability, and keep every customer message consistent with your stunning portfolio. It also makes it easier for clients planning weddings or events to find and contact you.\n\nThree easy steps to get started:\n- Confirm ownership of your domain and create a primary address aligned to your brand (for example hello@artofflowersnottingham.co.uk).\n- Update your email signature and the Contact page on your site to reflect the new address.\n- Redirect inquiries from forms or old emails to the new address and monitor replies for a week to catch any misrouted messages.\n\nIf you'd like, I can map a simple 3-step plan tailored to Art of Flowers and hop on a quick 15-minute chat to review specifics.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
192	101	34	sent	2025-08-22 12:57:45.306676	1	0	dbaedab7-ffbf-4433-81bb-67d0d96027b0	2025-08-22 13:09:00.882143	Elevate Shaun Henry Photography’s client trust	Hi Shaun,\n\nI’ve taken a moment to explore Shaun Henry Photography and appreciate how you position your work as a thoughtful, client-focused craft. In photography, clients entrust you with some of their most meaningful moments, and every touchpoint—booking, proofs, galleries, and emails—contributes to that trust.\n\nOne insight I’ve seen for photographers is that a branded domain email makes communications feel more legitimate and reassuring to new clients. It reduces the gap between your stunning portfolio and how you’re perceived when you email them, boosting credibility before a client even opens a message.\n\nWe Get You Online helps you have a professional domain email that matches shaunhenryphotography.uk, so inquiries land in a trusted inbox with your brand intact. The setup is straightforward, and we handle the technical stuff so you can focus on what you do best—capturing moments.\n\nIf you’d like to see how it could fit Shaun Henry Photography, you can learn more at wegetyouonline.co.uk/domain-email. Would you be open to a quick chat this week to explore options?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
148	42	24	sent	2025-08-21 20:54:56.120958	0	0	d5dff070-34fc-4fb6-8ba0-f48c43424ca4	2025-08-21 20:55:53.167377	Boost Blooms The Florist Emsworth's email trust	Hi there,\n\nIn case my earlier note about a branded domain email slipped by, I wanted to share a practical angle you can act on this week for Blooms The Florist Emsworth.\n\nWhy it matters: messages from bloomstheflorist.co.uk look more trustworthy to customers, delivery partners, and suppliers, which can improve open rates for orders and confirmations.\n\nThree quick steps you can try in under 15 minutes:\n- Verify SPF and DKIM are set up for bloomstheflorist.co.uk to improve inbox deliverability.\n- Choose a consistent From display name (Blooms The Florist Emsworth) with a simple address like hello@bloomstheflorist.co.uk or orders@bloomstheflorist.co.uk.\n- Add a compact branded signature with your logo, hours, and a link to bloomstheflorist.co.uk.\n\nIf helpful, I can share a short setup checklist or draft example signatures tailored to your branding. Small changes here can reduce missed messages during peak periods and make customer inquiries feel seamless.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
152	41	24	sent	2025-08-21 20:54:56.120958	1	0	51a5751d-61b1-4071-b467-89fde0fa8c3c	2025-08-21 21:02:29.937668	A practical email upgrade for Claire's	Hi there,\n\nFollowing up on my previous messages about branding Claire’s Floristry and Tea Room with a domain-based email, I wanted to share a couple of practical steps you can start with today to boost trust and response rates—without overhauling your current workflow.\n\nFirst, set up branded inboxes like hello@clairesfloristry.co.uk and bookings@clairesfloristry.co.uk. Adding SPF and DKIM records protects deliverability, which matters when customers inquire about weddings, bespoke bouquets, or tea room reservations.\n\nSecond, create a simple three-email welcome/response flow: 1) a friendly acknowledgement, 2) what to expect (lead times, pickup/delivery, event services), and 3) a next-step CTA (view menu, reserve a table, or request a quote). A consistent sender name across your team helps build trust.\n\nThird, update signatures to include hours, location, and a clear call to action.\n\nIf helpful, I can map a quick-start plan tailored to your site and typical inquiries. No pressure—just a clearer, more trustworthy way to communicate with customers.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
149	36	24	sent	2025-08-21 20:54:56.120958	0	0	7531eb89-961a-4084-8cdd-4dc033914ef2	2025-08-21 20:57:37.12593	New leaf floristry: a fresh angle	Hi there,\n\nFollowing up on my earlier notes about a branded domain email, I wanted to share a practical angle that often moves the needle for florists like New leaf floristry.\n\nLocal visibility: Start with a polished Google Business Profile. Fresh photos of your signature arrangements, weekly updates, and quick replies to reviews can boost local trust and drive more orders. Make sure your delivery area and hours are clear to prevent missed opportunities.\n\nWebsite and conversion: Ensure the homepage is mobile-friendly with a single clear CTA to shop bouquets, plus a visible delivery option. If same‑day delivery is available, highlight it upfront to capture last‑minute orders.\n\nBrand credibility: A branded domain email reinforces trust in inquiries. If helpful, I can outline a lightweight setup and deliverability tweaks (SPF/DKIM) to protect messages without adding friction.\n\nIf you’d like, I can share a compact 1-page checklist with 3 tailored wins for New leaf floristry and walk you through them in a 15‑minute call.\n\nWould you be open to a quick chat next week? I’m happy to fit your schedule.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
151	43	24	sent	2025-08-21 20:54:56.120958	1	0	4ebf792e-8937-4e04-b197-2ef2fb3b1b83	2025-08-21 21:00:09.18908	Boost Christmas Trees Portsmouth with branded emails	Hi there,\n\nI wanted to follow up on my previous messages about helping Christmas Trees Portsmouth leverage domain-branded email to look more professional and connect better with customers. In the florist space, a clean, reliable email setup reduces miscommunications around orders, delivery windows, and custom requests — especially during the busy festive season.\n\nHere are a few quick wins you can implement now:\n\n- Set up a primary domain-branded inbox and role-based addresses for orders, inquiries, and support to keep messages organized and prevent important inquiries from getting lost.\n- Use a consistent sender name and signature across your team to boost recognition and trust with local customers and seasonal shoppers.\n- Check deliverability basics (SPF and DKIM) to improve inbox placement and reduce bounce risk when sending promotions or order confirmations.\n- Consider a simple auto-reply for peak times to acknowledge inquiries and set expectations on order lead times and pickup/delivery windows.\n\nIf you’d find it helpful, I can run a quick 15-minute audit of your current setup and share a tailored 3-point plan focused on speed, security, and simplicity.\n\nWould you be open to a short chat this week?\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
150	35	24	sent	2025-08-21 20:54:56.120958	0	0	a65d8a08-e533-4493-ba40-eca496f0667c	2025-08-21 20:58:52.282364	A fresh approach for Little & Bloom	Hi there,\n\nFollowing up on my earlier note about a domain-branded email for Little & Bloom, I wanted to share a quick, practical idea you can apply right away to boost trust and inquiries.\n\nConsider standardizing a branded inbox across your team (for example, hello@littleandbloom.com or info@littleandbloom.com). It reinforces a professional image and improves open rates for messages from customers planning weddings and events. Pair this with a consistent email signature and a simple “Contact us” line on your homepage that links to that inbox. Small changes like this reduce confusion and can lift conversions by a few percentage points without touching your site design.\n\nIf helpful, I can draft a 1-page checklist with three actionable tweaks tailored to Little & Bloom—focused on inquiry flow, product imagery optimization, and local search visibility. A quick 15-minute chat could get us started; no obligation.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
154	37	24	sent	2025-08-21 20:54:56.120958	1	0	13628999-1db4-4ea3-a7bb-3ba55b073689	2025-08-21 21:06:56.515136	A practical boost for Blushing Bloom	Hi there,\n\nFollowing up on my earlier note about branded domain emails for Blushing Bloom and OceanFlora, I wanted to share a practical next step that can start delivering sooner than you think.\n\nA branded inbox not only looks more professional; it also builds trust with couples and suppliers. Quick ideas you can try this week:\n- Create a few simple aliases on your domain, such as hello@blushingbloom.co.uk, bookings@blushingbloom.co.uk, and florals@blushingbloom.co.uk, and route them into your existing inbox.\n- Add SPF and DKIM records to improve deliverability and prevent replies from landing in spam.\n- Set up a warm auto-reply that acknowledges inquiries within 1 hour and includes a link to your portfolio and a calendar for quick consults.\n- Use a consistent email signature with your logo, social links, and a note on lead times or wedding availability.\n\nIf you'd like, I can share a tailored 5-point setup checklist for Blushing Bloom and OceanFlora. Happy to help you decide the best approach.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
277	109	35	sent	2025-08-26 00:06:05.450637	0	0	28aa9f5a-f043-4915-a6a6-4c8119844ec1	2025-08-26 00:09:56.658236	Quick ideas for Ian Richardson Photography	Hi Ian,\n\nJust following up on my last email. I took another look at Ian Richardson Photography and your emphasis on warmth and trust comes through clearly. To help you turn more site visitors into inquiries without adding workload, here are a few practical tweaks you could try this month:\n\n- Homepage clarity: a single, value-focused headline for weddings and portraits, plus a clear CTA like "Book a consult" and a short client quote to build trust.\n- Portfolio and SEO: create a concise "Weddings in the UK" gallery with alt text for images and a blog post about top UK venues. This improves search visibility and keeps potential couples longer on your site.\n- Lead capture: add a lightweight inquiry form and a simple welcome email that shares 1-2 sample galleries after submission.\n\nIf you'd be open to it, I can prepare a tight 2-page checklist with these ideas tailored to your site and offer a quick 15-minute call to walk through them.\n\nWarm regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
156	38	24	sent	2025-08-21 20:54:56.120958	1	0	db2b9089-5048-461d-b832-8dc2b56062e7	2025-08-21 21:11:25.070847	Boosting Full Bloom Hayling's email presence	Hi there,\n\nFollowing up on my previous notes about helping Full Bloom Hayling with a branded domain email, I wanted to share a quick, practical idea you can test this week.\n\nA branded email builds trust and can improve reply rates. Here are a few small moves florists often find effective:\n\n- Use a dedicated branded address for inquiries (for example hello@fullbloomhayling.co.uk) with a consistent sender name.\n- Align your email signature across the team (name, title, store hours, and a link to your Instagram) so every message feels cohesive.\n- Add a simple welcome/thank-you reply for new inquiries that sets expectations (response time and what you offer).\n\nIf you’d like, I can draft a starter template and a one-page setup checklist tailored to Full Bloom Hayling. A quick 10-minute chat could map the first steps.\n\nWould you be open to a brief call this week? Happy to share ideas when it suits you.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
157	40	24	sent	2025-08-21 20:54:56.120958	0	0	a197b7e9-2d07-4c4a-9e8f-53678f323860	2025-08-21 21:14:29.048539	Follow-up: branded email for Lullabelles	Hi there,\n\nFollowing up on my note about a branded domain email for Lullabelles Floristry, I wanted to share a few quick, practical ways this can support your floristry business without adding complexity.\n\n- Trust and recognizability: a domain like lullabellesfloristry.me appears in every message, which helps customers feel confident and improves open rates.\n- Clarity and response times: separate addresses for orders, inquiries, and partnerships keep conversations organized when the studio is busy.\n- Consistency and deliverability: a professional sender profile improves inbox placement for promos and order confirmations.\n\nA simple, low-friction plan to get started:\n1) Create two primary inbox addresses (hello@lullabellesfloristry.me and orders@lullabellesfloristry.me).\n2) Point them to your current email, with a unified inbox view.\n3) Add a brief signature linking to lullabellesfloristry.me and your Instagram.\n\nIf you’d like, I can sketch a tailored 5-minute setup and share a few subject lines that have resonated with florist clients.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
145	24	24	sent	2025-08-21 20:29:42.843529	1	0	517625e4-78ca-4389-805e-314f944a2efd	2025-08-21 20:41:56.057466	A simple upgrade for Mapperley Blooms	Hi there,\n\nFollowing up on my note about a branded domain email, I wanted to add a practical angle that could boost Mapperley Blooms’ customer experience today.\n\nA professional domain email does more than look polished. It makes it easier for customers to reach you, reduces misrouted messages, and pairs nicely with your Square storefront for orders and inquiries. It also improves trust when you send receipts, quotes, or wedding-and-event proposals.\n\nHere’s a quick, non-disruptive plan you could consider:\n- Confirm whether you already own a domain. If yes, we can set up 2-3 branded inboxes (for general inquiries, orders, and support) that align with your brand.\n- Add a simple forwarding rule from your current contact page to your new inboxes, so no messages are missed.\n- Implement SPF/DKIM basics to improve deliverability and reduce spam flags.\n\nIf you’d like, I can provide a short 60-second audit of your current email touchpoints and a tailored 3-step rollout. Happy to hop on a quick call when you’re ready.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
138	25	24	sent	2025-08-21 20:29:42.843529	1	0	fb572053-f213-445c-b56d-e6a60844a765	2025-08-21 20:30:00.850947	Brand email ideas for The Florist Nottingham	Hi there,\n\nFollowing up on my note about a branded email domain for The Florist Nottingham, I wanted to share a few practical improvements you can implement this week to boost trust and inbox delivery.\n\n1) Email authentication: SPF, DKIM, and DMARC. Proper setup helps protect your brand and keeps messages out of spam.\n\n2) Consistent identities: a few core addresses—hello@thefloristnottingham.co.uk, orders@thefloristnottingham.co.uk—and a unified signature with your logo, website, and phone.\n\n3) Simple templates: a clean, mobile-friendly email template aligned with your site’s look and a starter seasonal promo to reinforce the brand across channels.\n\nI know your focus is on stunning bouquets and exceptional customer experience; these steps help ensure your messages are trusted and reach the right people.\n\nIf you’d like, I can run a quick 5-minute domain health check and share a focused one-page set of recommendations. No pressure—just practical steps to consider.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
158	23	24	sent	2025-08-21 21:19:52.439575	0	0	b9f63b20-7bcb-49e6-b3ef-e7317765ec1b	2025-08-21 21:20:46.447686	A quick win for The Flower Shop Beeston	Hi there,\n\nFollowing up on my earlier notes about a personalised domain email for The Flower Shop Beeston, I’ve got four quick wins you can implement this week to boost trust and inquiries.\n\n- Use a branded address for customer inquiries, such as hello@theflowershopbeeston.co.uk, to look more professional and increase trust compared with generic addresses.\n\n- Add a simple email signature with your business name, website, and a local phone number to every message.\n\n- Ensure SPF and DKIM records are in place to protect your messages from spoofing and improve deliverability.\n\n- Update your website’s contact page to feature the branded email and a short note about replying within 24 hours.\n\nImplementing these is quick, low-cost, and can lift your inquiry-to-conversation rate with local customers. If you’d like, I can tailor a step-by-step setup checklist for The Flower Shop Beeston.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
159	46	24	sent	2025-08-21 21:19:52.439575	0	0	1d517974-323e-4399-a4b5-8ffee530cc1d	2025-08-21 21:22:11.901905	A practical branded email plan for Tiger Lily	Hi there,\n\nFollowing up on my earlier notes about boosting Tiger Lily’s online presence with a professional domain email, I wanted to share a practical, low-friction plan you can use alongside any site improvements. The goal is to boost trust, deliverability, and responses from local customers.\n\nHere’s a simple 5-point plan:\n\n- Establish a branded inbox: create a primary hello or info address aligned with tigerlilyflowers.co.uk to improve open rates and perception.\n\n- Ensure deliverability: set up SPF, DKIM, and DMARC on your domain to prevent misfires and spoofing.\n\n- Migration in 4 steps: map current inboxes, pick 1-2 primary addresses, migrate messages, update signatures and contact forms.\n\n- Quick wins: update email signatures with your logo, phone, and website; use consistent tone; add a seasonal bouquet CTA.\n\n- Measurable outcomes: track open/click rates, bounce rates, and inquiry volume after 2–4 weeks.\n\nIf you’d like, I can tailor this to Tiger Lily’s brand voice and customers, and deliver a 1-page rollout plan with milestones for a smooth transition.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
160	21	24	sent	2025-08-21 21:19:52.439575	0	0	46626664-3b3c-44bf-ae18-80d01ad08683	2025-08-21 21:23:24.710081	Boost Fleur Florists online identity	Hi there,\n\nFollowing up on my note about domain-branded email and strengthening Fleur Florists' online identity, I wanted to share a practical angle you can act on quickly. Using your own domain for emails (for example, you@fleurfloristbelper.co.uk) builds trust with customers, professionalizes inquiries, and can improve deliverability with minimal setup.\n\nTwo quick wins to consider:\n- Ensure SPF, DKIM, and DMARC are in place to protect your brand and improve inbox placement.\n- Create a small library of branded reply templates for common inquiries (orders, deliveries, gifting, and wedding flowers) to save time and keep consistency.\n\nIf you’d find it useful, I can outline a simple, 1-hour setup plan and provide starter templates tailored to Fleur Florists. It won’t disrupt current emails—just a clean upgrade to your brand presence.\n\nWould you be open to a brief chat this week or next? I’m flexible and happy to fit your schedule.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
161	47	24	sent	2025-08-21 21:19:52.439575	0	0	292e9b76-8222-4ff8-81b9-bb1e29b6f59f	2025-08-21 21:24:36.8911	Branded email for Fleurtations Bristol	Hi there,\n\nFollowing up on my earlier note about a domain-branded email for Fleurtations Florist Bristol, I wanted to share a few practical ideas that can make a real difference with minimal effort.\n\n- Trust and consistency: a branded email (for example hello@fleurtations-bristol.co.uk) looks more professional across your website, social posts, and packaging, helping customers feel confident when they reach out.\n\n- Deliverability basics: coordinating SPF and DKIM with a DMARC policy protects messages from being filtered out and reduces the chance of inquiries getting lost in spam.\n\n- Local presence synergy: pair the branded email with a clean Google Business Profile and consistent contact details to support local searches and inbound inquiries.\n\n- Simple next steps: I can provide a short starter guide with a 3-step setup (domain, email host, basic security) plus a few inquiry and order templates tailored for Fleurtations Bristol.\n\nIf you’re open, a brief 15-minute chat this week could be tailored to your goals and your current setup. I’m happy to work around your schedule.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
162	22	24	sent	2025-08-21 21:19:52.439575	0	0	24d4a11c-f85e-4415-b2e3-2b4a8afd2131	2025-08-21 21:26:22.65647	Follow-up: Branded email for Melbourne Florist	Hi there,\n\nI’m following up on my earlier note about using a branded domain email to boost Melbourne Florist and Gifts' online presence. From what I saw on melbourneflorist.co.uk, your customer focus and beautiful arrangements deserve communications that feel as polished as your bouquets.\n\nA branded domain email does more than look professional. It improves deliverability, reduces the chance your messages land in spam, and creates consistent recognition across order confirmations, quotes, and newsletters. If you’re not already, consider: 1) creating a dedicated inbox like hello@melbourneflorist.co.uk for customer inquiries and orders, 2) applying SPF/DKIM/DMARC to protect your domain, 3) standardizing email signatures so every staff message carries your logo and contact details.\n\nIf you’d like, I can run a quick 15-minute diagnostic to pinpoint quick wins specific to your site and customer flow, and share a tailored plan.\n\nWould Thursday or Friday next week work for a short chat?\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
163	44	24	sent	2025-08-21 21:19:52.439575	0	0	c34e6dc4-c582-4967-90a0-454ab6f20bb7	2025-08-21 21:28:14.943559	Boost Lily Violet May with branded emails	Hi there,\n\nFollowing up on my earlier messages about a branded email domain for Lily Violet May Florist, I wanted to share a few practical steps that could make a quick impact without disrupting your day-to-day.\n\nYour floral work already speaks for itself online. A branded email domain not only strengthens trust with customers but also improves message reach and deliverability. Here are a few easy wins:\n\n- Set hello@lilyvioletmay.co.uk as a primary contact and use it across your website and forms.\n- Configure SPF and DKIM records (and DMARC if possible) to protect your domain and improve inbox placement.\n- Route inquiries from your site directly to the right team member, ensuring timely responses.\n- Update your email signature to include your website and Instagram link for ongoing brand consistency.\n\nIf you'd like, I can share a compact one-page checklist and outline a simple 2-week implementation plan after a quick 15-minute chat.\n\nWould you be open to a brief chat this week to explore these steps?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
164	45	24	sent	2025-08-21 21:19:52.439575	0	0	36e18c75-4526-4b38-9bca-2dcc13421b9c	2025-08-21 21:30:59.26696	Fresh ideas for The Flower Shop emails	Hi there,\n\nFollowing up on my note about branding The Flower Shop's emails with a custom domain, I wanted to share a practical angle that often yields quick wins for customers in the florist space.\n\nWhy it helps: it builds trust with customers, especially for order confirmations, delivery updates, and seasonal promos. It improves inbox deliverability and open rates, because branded domains with proper SPF and DKIM signals feel more legitimate than generic ones. And it keeps your brand consistent from website to inbox, reducing friction when customers click through to your shop.\n\nActionable next steps:\n1) Pick a branded sending domain (for example, mail.theflowershopbristol.com) and set up a matching reply-to address.\n2) Implement SPF and DKIM records, plus a DMARC policy to protect your sender reputation.\n3) Draft a short welcome email and a simple post-purchase note that uses your brand voice and logo, so every touchpoint feels cohesive.\n\nIf you're open, I can put together a quick 15-minute plan tailored to The Flower Shop and its current email tools, plus a sample welcome and a transactional template you can test this week.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
155	39	24	sent	2025-08-21 20:54:56.120958	1	0	936c172d-a27b-43e8-aa66-249ea8fce27c	2025-08-21 21:08:43.728211	A practical email upgrade for Sherwood Florist	Hi there,\n\nI hope you’re well. I recently revisited Sherwood Florist’s site and was again struck by your beautiful arrangements and the clarity of your branding. Following my earlier notes about a branded email domain, I wanted to share a practical angle that can deliver quick wins without a big lift.\n\nThree fast, doable steps to align emails with your brand and improve reliability:\n- Set up a dedicated inbox such as info@sherwood-florist.com for orders and inquiries.\n- Create smart aliases (support@sherwood-florist.com, hello@sherwood-florist.com) to route to the right team.\n- Check domain deliverability basics (SPF, DKIM, DMARC) to protect messages from spam filters and boost trust.\n\nIf you’d like, I can do a quick 15-minute audit of your current setup and share a tailored plan. Would you be open to a short chat next week?\n\nWarm regards,\nRyan\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
165	48	24	sent	2025-08-22 00:01:10.920505	0	0	2766c554-b77d-4d77-9ddb-d91014e64ae2	2025-08-22 00:01:52.926804	A quick win for Flowers By Alla's email	Hi there,\n\nFollowing up on my earlier note about branded domain emails for Flowers By Alla, I took another look and wanted to share a simple, practical step you can implement this week that can boost trust and response.\n\nConsider setting up a branded inbox alongside your current channels, such as info@flowersbyalla.com or hello@flowersbyalla.com. A consistent, recognizable address helps customers feel confident when they receive messages about orders or deliveries, and it also improves deliverability and organization for your team.\n\nHere are a few quick moves:\n- Ensure SPF, DKIM, and DMARC are configured for flowersbyalla.com to keep messages from landing in inboxes.\n- Create a uniform signature across the team with your logo, name, phone, and a link to your shop or Instagram.\n- Use branded emails for order confirmations, quotes, and promotions, but keep them concise with a clear next step.\n\nIf you’d like, I can draft a simple 1-page setup plan or handle the initial setup to minimize any disruption.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
169	85	34	sent	2025-08-22 12:12:39.966876	1	0	3e9a4ecb-6c63-4bca-bf59-8d4455e1afb8	2025-08-22 12:14:49.827126	Build trust with 75Hudson emails	Hi there,\n\nI’m Ryan, founder of We Get You Online. I recently explored 75Hudson Photography and was struck by your storytelling approach—natural light, candid moments, and a warm, timeless vibe that clearly helps clients feel at ease.\n\nIn photography, trust between photographer and client is earned every step of the way. A domain-branded email supports that trust by presenting a cohesive, professional front when you reach out to prospective clients, share galleries, or finalize contracts. It avoids the ambiguity of a generic address and helps clients feel confident they’re communicating with the real business behind 75Hudson Photography. Plus, consistent branding across your emails reinforces your portfolio when you send quotes and proofs.\n\nOur service delivers professional domain-branded emails built on your existing site, so clients always see your brand in their inbox. It’s straightforward to set up and keeps your communications aligned with your aesthetic.\n\nIf you’re curious, you can learn more here: wegetyouonline.co.uk/domain-email. I’d be glad to walk through a quick, 10-minute example for 75Hudson Photography.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
167	49	24	sent	2025-08-22 00:01:10.920505	0	0	802e244a-3538-4b98-8e4f-11892f508196	2025-08-22 00:05:26.538782	Branded domain emails for Edith Wilmot	Hi there,\n\nFollowing up on my note about domain-branded emails for Edith Wilmot Bristol Florist, I wanted to share a practical step you can take this week to boost trust and streamline communications.\n\nConsider launching a couple of branded inboxes: orders@edithwilmot.co.uk and hello@edithwilmot.co.uk (or support@edithwilmot.co.uk). A consistent domain not only looks more professional, it also helps customers recognize legitimate messages from you, reduces the chance of missed orders, and improves response times when inquiries come in via social or search results.\n\nTo get started, pick 2-3 roles (orders, support, marketing), update your contact details on the website and Google listing, and configure SPF/DKIM with your email provider to protect deliverability. It helps to draft a few ready-to-send templates for orders confirmations, delivery updates, and a friendly greeting.\n\nIf you’d like, I can share a simple 5-step setup checklist tailored to your site. A small change like this can pay off in more consistent communication and more bookings for Edith Wilmot Bristol Florist.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
147	31	24	sent	2025-08-21 20:29:42.843529	1	0	ba9f5709-486b-427b-8c6f-64dce7763220	2025-08-21 20:47:15.553648	Boost AFS credibility with email branding	Hi there,\n\nJust following up on my note about adding a domain-branded email to AFS Artificial Floral Supplies. For a florist supplier, a professional inbox is often the first line of trust with customers and suppliers, and it can improve both credibility and deliverability.\n\nHere are three quick wins you can apply this week:\n- Use your domain-based address for all external messages (e.g., yourname@artificialfloralsupplies.co.uk) to reinforce brand consistency.\n- Create a simple signature: name, founder at AFS, phone, website, and a link to your catalog. This looks polished and makes it easy for partners to reach you.\n- Check email authentication: ensure SPF and DKIM are set up for your domain. This helps prevent messages from being flagged as spam and improves inbox placement.\n\nIf helpful, I can share a one-page setup checklist tailored to your domain and provide a ready-to-use signature you can drop in today.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
153	34	24	sent	2025-08-21 20:54:56.120958	1	0	98902ddb-257e-495f-96d9-3805256ed767	2025-08-21 21:04:12.314116	Follow-up: branded domain email for Poppies	Hi there,\n\nI wanted to touch base regarding my previous messages about branded domain email for Poppies Florist Bournemouth. I know how busy the shop floor can be, especially around seasonal orders and special occasions. A branded email address can quietly boost trust with customers while improving deliverability and recognition in their inbox.\n\nIf you’re considering a quick, practical start, here are a few bite-sized steps you could take this week:\n- Choose a consistent sender address (info, hello, or support) under your domain to unify communication.\n- Set up a simple auto-reply for new inquiries and order confirmations that mirrors your brand voice.\n- Prepare two or three short templates for common questions (availability, custom arrangements, delivery areas) to save time and ensure consistent messaging.\n\nIf you’d like, I can outline a minimal setup plan that fits around your current workflow and takes less than an hour to implement, with no disruption to orders. I’m happy to tailor recommendations to your current systems and goals.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
200	63	31	sent	2025-08-23 13:45:02.611598	0	0	0c9bfe31-2a3e-4c23-a901-152068f42478	2025-08-23 13:50:22.426149	Quick follow-up for 223ROC Boxing	Hi there,\n\nI followed up on my note about branding your emails for 223ROC Boxing and how a focused, coaching-driven message can help convert interest into clients. I revisited your site and noticed that new leads often land on your classes and progress stories—great signals to amplify with email.\n\nA practical step you can implement now: set up a short welcome sequence plus a weekly boxing tip series. This builds trust faster and keeps your coaching voice consistent.\n\nHere are two quick templates to start:\n- Welcome email: set expectations, outline programs (fundamentals, conditioning, sparring), and include a clear next step to book an assessment.\n- Weekly tip email: one actionable technique or workout, plus a single CTA to see class options.\n\nTips for best results: keep subject lines direct, mobile-friendly, and use client success visuals on your site linked from emails.\n\nIf you want, I can outline a starter sequence tailored to 223ROC Boxing in a single page for your review.\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
201	60	31	sent	2025-08-23 13:45:02.611598	0	0	c03a10a0-ce88-415a-877c-950c5cb8c3cd	2025-08-23 13:52:18.496854	NPerformance Poole: quick follow-up	Hi there,\n\nI came across NPerformance Personal Training Poole again and was reminded how your hands-on, client-first approach sets you apart. Following up on my last note, I wanted to offer a couple of practical ideas you can test this month without overhauling your routines.\n\n- Sharpen local visibility: claim and optimize your Google Business profile, add 3 fresh training-session photos, and invite recent clients to leave a quick review. You’ll often see new local inquiries improve.\n\n- Simple content plan: one weekly client spotlight, one actionable tip video, and one “behind the scenes” post showing how you tailor progress tracking. Consistency beats complexity.\n\n- Lightweight follow-up flow: a two-email welcome sequence for new prospects that names a goal board you can share in the first session, reducing friction to book.\n\nIf any of these resonate, I can tailor a compact 2-week implementation plan and draft sample copy you can plug into your channels. Happy to help.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
202	59	31	sent	2025-08-23 13:45:02.611598	0	0	bfc95ec1-30c8-493a-a0f8-d394b8892440	2025-08-23 13:55:07.19478	Branded emails that build trust	Hi there,\n\nFollowing up on my note about boosting trust with a branded email for Ocean Fitness Poole, I wanted to share a simple, low‑effort tactic you can test this week.\n\nIdea: a concise onboarding email series that matches your client‑first approach. 1) Welcome and goal‑setting: outline the four‑week roadmap and how you measure progress. 2) Weekly check‑in: a short tip and a reminder of your support channels. 3) Results spotlight: a quick client story or a before/after snapshot kept anonymous if you prefer, with a clear next‑step CTA to book a quick call or session.\n\nWhy it helps: it reinforces your brand with every inquiry, reduces friction for new clients, and starts conversations from a place of clarity and care.\n\nIf you’d like, I can draft a ready‑to‑send 3‑email sequence in Ocean Fitness Poole’s voice and branding within 24 hours. We can also do a quick 15‑minute review to tailor it to your client journey.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
203	64	31	sent	2025-08-23 13:45:02.611598	0	0	0938e1f6-325c-4316-ae7b-31a63a61b22e	2025-08-23 13:57:25.398682	Quick wins for Phil Lea PT branding	Hi Phil,\n\nFollowing up on my note about boosting client trust with branded emails, I took another look at Phil Lea Personal Training. Your emphasis on tailored workouts and steady progress really resonates, and a small branding tweak can make onboarding feel premium and improve engagement from day one.\n\nHere are two quick wins you can implement this week:\n\n- A simple 5-email onboarding sequence branded with Phil Lea Personal Training: Welcome, Goal Confirmation, First Week Check-in, Progress Snapshot, and Referral/Review request. Keep the tone consistent, include a logo, and use your color palette.\n\n- A post-session Progress recap email every 3–4 sessions, with a concise snapshot (milestones reached, next-week plan) and a clear call to action.\n\nIf you'd like, I can draft a ready-to-send 5-template kit tailored to your brand in under 30 minutes and share a 1-page branding guide to keep things consistent. If you’re open to it, we can jump on a 15-minute call this week to tailor these to Phil Lea Personal Training.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
170	83	34	sent	2025-08-22 12:12:39.966876	0	0	ac29bbc9-a1df-4960-bf08-acc743cddea6	2025-08-22 12:16:54.582061	A trusted email for Gem Photography	Hi there,\n\nI recently browsed Gem Photography and was drawn to the portfolio’s timeless, elegant approach that captures real moments with warmth. In a field built on trust between photographer and client, the first impression you give when inquiries arrive matters as much as the images you capture.\n\nAt We Get You Online, we help photographers like you adopt a domain-branded email that reinforces that trust from the first hello. A simple, professional email address (yourname@yourdomain) reduces confusion, increases perceived legitimacy, and helps clients feel confident during the booking and delivery process. It also makes client communications easier to track and reference.\n\nPractical step: pair your new branded email with a clean signature that includes your logo, key contact details, and a link to Gem Photography’s portfolio. If you’re curious how seamless it can be, I can walk you through setup and best practices for email authentication to protect your brand.\n\nIf you’d like to explore, learn more at wegetyouonline.co.uk/domain-email.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
177	97	34	sent	2025-08-22 12:35:07.177416	1	0	a091d605-0935-45fc-a5cb-48c994f64c4c	2025-08-22 12:35:19.194523	Branded email for Kate Davey Photography	Hi Kate,\n\nI spent a moment exploring Kate Davey Photography and was struck by how your portraits capture genuine moments with warmth and clarity. That focus on trust between you and clients is powerful—after all, you’re trusted to preserve life’s important moments.\n\nOne simple way to reinforce that trust at every touchpoint is a domain-branded email. When inquiries arrive as hello@katedaveyphotography.com (or bookings@), it instantly signals professionalism and consistency, reducing hesitation for new clients who want to feel confident from the first message. A branded email also helps keep your inbox organized and makes you easier to reach for collaborations or referrals.\n\nIf you’re considering options, we help photographers like you set up a clean, domain-branded email that matches your website and branding, with reliable delivery and easy maintenance. It’s a small change with a tangible impact on client trust and bookings.\n\nWould you be open to a quick chat or a moment to review how this could fit Kate Davey Photography? More details here: wegetyouonline.co.uk/domain-email\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
172	84	34	sent	2025-08-22 12:12:39.966876	0	0	e7c768bf-bed8-42af-9e8b-5ee4b5a9494c	2025-08-22 12:20:48.600988	Elevate trust with Elen Studio Photography	Hi there,\n\nI visited elenstudiophotography.com and was drawn to how your work centers on storytelling and genuine moments, often captured with warm, natural light. That focus on authentic connections is what helps clients feel confident in you from the first inquiry through delivery.\n\nOne practical way to reinforce that trust at every touchpoint is a professional domain branded email. Instead of a generic address, you’d communicate as elen@elenstudiophotography.com, which signals credibility and consistency. When clients can trust the sender, they’re more likely to respond quickly, share details about moments they want captured, and feel assured they’re in good hands.\n\nIf you’re open to exploring, we can set up a branded domain email that aligns with your current site and branding, plus ready-to-use templates for inquiries and proofs. It’s a small change with a meaningful impact on client trust and the overall experience you deliver.\n\nLearn more at wegetyouonline.co.uk/domain-email, and if you’d like, we can tailor this to Elen Studio Photography in a quick chat.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
174	87	34	sent	2025-08-22 12:12:39.966876	0	0	6ac9af42-a87b-4d64-8907-8f55807aa980	2025-08-22 12:25:18.208142	Domain email for Lovell Photography	Hi there,\n\nI recently came across Lovell Photography and was struck by how your imagery captures moments with warmth and authenticity. Your portfolio demonstrates a thoughtful blend of natural light and storytelling that really puts clients at ease during important life events.\n\nIn this line of work, the trust between photographer and client is everything. A domain-branded email signals professionalism and reliability from the very first hello, helping clients feel confident you’re the real partner they can rely on for their most precious moments. A cohesive touchpoint—consistent address, signature, and contact details—creates a seamless experience from the initial inquiry to proof delivery.\n\nIf you’re curious about making this easy, we help photographers set up professional domain emails that align with your Lovell brand. It’s not just about look; it enhances trust at every client touchpoint.\n\nWould you like to see how it could work for Lovell Photography? Learn more at wegetyouonline.co.uk/domain-email.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
175	91	34	sent	2025-08-22 12:12:39.966876	0	0	7ccd8456-e20a-48d9-8366-a8e925335308	2025-08-22 12:27:30.163031	Trust-building for Mustard Fox Photography	Hi there,\n\nI’m Ryan, Founder of We Get You Online. I’ve taken a look at Mustard Fox Photography, and your storytelling approach—capturing candid, heartfelt moments—clearly centers on helping clients feel at ease and truly seen. That emphasis on authentic connection is what turns inquiries into booked sessions and keeps clients coming back for future shoots.\n\nA simple but powerful step to reinforce that trust is using a professional domain-branded email that matches your mustardfoxphotography.co.uk domain. It sends a clear signal of credibility and consistency across every touchpoint, from initial inquiry to delivery of memories. Clients often decide within the first email whether they want to work with a photographer, and a brand-aligned address helps you start on the right foot rather than with a generic inbox.\n\nIf you’d like to see how this could work for Mustard Fox Photography, I’d be happy to share a quick, no-pressure example tailored to your brand. You can learn more about our domain-email service at wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
173	88	34	sent	2025-08-22 12:12:39.966876	1	0	46af8fac-1e0b-442b-a69c-7977ca4b5b7a	2025-08-22 12:22:26.930571	Elevate client trust with branded email	Hi there,\n\nI took a quick look at Nuria Serna Photography and your portfolio conveys a warm, storytelling approach that helps clients feel seen during life’s important moments. That focus on genuine connection is exactly what builds trust when you’re capturing weddings, portraits, or milestones.\n\nA professional domain-based email can reinforce that trust from the first hello—whether you’re replying to inquiries, delivering galleries, or sending invoices. It keeps your brand front and center and signals to clients you care about protecting memories at every touchpoint.\n\nIf you’re weighing a quick win, here are a few ideas:\n- Use a domain email aligned with Nuria Serna Photography to keep every message cohesive.\n- Include a concise signature with your logo, website, and a link to a recent portfolio.\n- Maintain timely, personalized responses to reinforce the thoughtful experience you provide.\n\nIf you’d like to explore how this could fit your business, take a look at wegetyouonline.co.uk/domain-email. I’d be glad to discuss how a branded email can support your client relationships.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
275	111	35	sent	2025-08-26 00:06:05.450637	1	0	8c838df7-b349-494b-aa78-905052174312	2025-08-26 00:06:14.457421	Growing Anna Martin Photography: trust & bookings	Hi Anna,\n\nI hope you’re well. I’ve been thinking about our last note and revisited Anna Martin Photography. Your portfolio continues to communicate authentic storytelling with a warm, timeless feel—clearly built on trust.\n\nA few quick, practical tweaks that can help convert more inquiries into bookings without overhauling anything:\n\n- Add a concise “What to Expect” section on the homepage that outlines what clients can anticipate from booking, shooting, and delivery in 3 simple steps.\n- Feature client voices more prominently with a small testimonials block and a couple of before/after or session-shot captions that reinforce reliability.\n- Simplify inquiries with a short, 3-field form plus an easy calendar link for discovery chats.\n\nIf it helps, I can do a fast 15-minute audit of your homepage and inquiry flow and share tailored, no-pressure improvements. No obligation—just insights to raise trust and capture more bookings.\n\nWould you be open to a brief chat this week? I can align with your schedule.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
198	66	31	sent	2025-08-23 13:45:02.611598	0	0	c3ba7da1-ae93-4d7d-be8a-67c1efae09bc	2025-08-23 13:47:14.28092	A quick branding note for ZiaFitLife	Hi Anastazia,\n\nFollowing up on my last note about how branded emails can deepen trust for ZiaFitLife, I wanted to share a few practical ideas you can apply quickly.\n\n- Onboarding welcome email: outline the first 30 days, set clear expectations, and include a single, easy CTA to book a 15-minute check-in.\n\n- Consistent branding across emails: a small logo in the header, a signature block with your coaching focus, and a short, client-focused takeaway at the end to boost recognition.\n\n- Quarterly client success snapshot: share a measurable outcome (like adherence or energy) with a brief quote, and invite readers to learn more or start a program.\n\nIf you'd like, I can draft a three-email starter sequence in ZiaFitLife's voice to test with a segment of your list. A quick 15-minute chat would let me tailor it to your clients' journey. Would you be open to a conversation later this week or next?\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
197	62	31	sent	2025-08-23 13:45:02.611598	1	0	7ac3513c-8157-436b-afa0-78228f486fc8	2025-08-23 13:45:30.618367	Fit N Fresh: follow-up and ideas	Hi Dan,\n\nFollowing up on my previous note about Fit N Fresh Coaching. I revisited fitnfreshcoaching.com and your focus on sustainable results and personalized coaching comes through clearly. To help you convert more site visitors into clients without changing your approach, here are a few quick, practical ideas:\n\n- Clarify the client journey: add a simple 3-step path (Assessment → Plan → Results) with a prominent “Book a quick discovery call” CTA on the homepage.\n- Show social proof near the top: a short client result line or testimonial to build trust fast.\n- Capture leads with a small, value-driven offer: a 5-minute starter guide or 3-question fitness quiz that leads to a consultation.\n\nIf you’d like, I can put together a concise 60-minute on-site audit for Fit N Fresh with 3 targeted tweaks aligned to your brand voice.\n\nWould love to hear what you think.\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
194	109	34	sent	2025-08-23 00:04:22.00744	1	0	f5d78c95-77ea-45c6-8993-1d5e5505b630	2025-08-23 00:04:47.027438	Elevate Ian Richardson Photography emails	Hi Ian,\n\nI’ve been exploring Ian Richardson Photography and your portfolio shows a strong focus on capturing moments with warmth and trust—especially in weddings and portraits. Photographers like you are trusted with some of life’s most meaningful moments; the first impression your clients get often comes from how you present yourself in email.\n\nUsing a branded domain email — for example contact@irphoto.co.uk or bookings@irphoto.co.uk — signals continuity with your work and reduces hesitation from potential clients who receive inquiries or confirmations. It also improves deliverability and security, helping your messages land in inboxes instead of spam and making your communications feel more personal and professional.\n\nA simple branding upgrade can also unlock faster replies, better signatures, and consistent messaging across inquiries, shoots, and delivery. I’d love to show you how our domain-email service at wegetyouonline.co.uk/domain-email can fit seamlessly with your existing site and workflow.\n\nWould you be open to a quick 10-minute chat to see what it could look like for Ian Richardson Photography? If interested, feel free to check the details here: wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
195	110	34	sent	2025-08-23 00:04:22.00744	1	0	bdae3c16-225e-4647-91f0-a816e56996d6	2025-08-23 00:05:57.186707	Mo, elevate trust with your brand email	Hi Mo,\n\nI’ve been following Mo Photography & Film after checking moweddingphotographyuk.com. Your cinematic, documentary-style wedding storytelling stands out and speaks to couples who value real moments over cliché poses. The way you frame emotion and connection suggests a trusted, personal partnership with clients from the first inquiry.\n\nAs you know, clients entrust you with their most important day. A domain-branded email helps reinforce that trust from the very first hello and ensures your outreach feels like an extension of your brand. It also simplifies how clients reach you, reduces confusion after venue visits, and signals professionalism across inquiries, quotes, and contracts.\n\nAt We Get You Online, we tailor professional domain email for photographers, so every message aligns with your Mo Photography & Film story. If you’d like, I can share a quick example of how your emails would look with a branded domain and how it can improve response and inquiries.\n\nLearn more at wegetyouonline.co.uk/domain-email.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
178	92	34	sent	2025-08-22 12:35:07.177416	0	0	09c5f1af-1355-4e0a-9b3c-c0aabb8190f4	2025-08-22 12:37:02.18362	Clive, enhance client trust with branded email	Hi Clive,\n\nI recently explored Clive Stapleton Photography and was impressed by how your portfolio captures real, meaningful moments with a timeless, natural vibe. In photography, clients trust you with some of the most important memories of their lives, and that trust starts with every point of contact — from a booking inquiry to a proof email.\n\nOne insight I took away from your site is the emphasis you place on authentic storytelling as your core value. A branded, professional domain email reinforces that story in every client interaction. When a potential client sees yourname@clivestapleton-photography.co.uk, they immediately sense consistency, credibility, and care — which can boost bookings and calmer negotiations.\n\nWe Get You Online helps photographers like you project that trust with a simple, reliable branded domain email that works with your existing setup. It’s easy to deploy, improves email deliverability, and keeps your communications aligned with your brand across inquiries, proofing, and contracts.\n\nIf you’d like to explore how a domain email could fit into your workflow, take a look at wegetyouonline.co.uk/domain-email. I’d be happy to offer a quick, no-pressure tour of options.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
204	67	31	sent	2025-08-23 13:45:02.611598	0	0	7f6953bf-8e8b-4a0f-9f75-050350e5fdfb	2025-08-23 13:59:54.860463	Practical follow-up for Addis Fitness	Hi James,\n\nFollowing up on my note about building trust with a branded email for Addis Lifestyle & Fitness, I wanted to share a practical, low-friction plan you can test this month.\n\nFirst, an onboarding email sequence tailored to your coaching style can boost new client engagement. Here’s a quick outline you could adapt:\n- Email 1: Welcome to Addis Lifestyle & Fitness — what a new client can expect, how to schedule a getting-started consult, and a link to the goal form.\n- Email 2: A starter week — a 30-minute workout plan, simple nutrition tips, and encouragement to log progress.\n- Email 3: A recent client win — a concise testimonial with a before/after note and an invitation to book the next session.\n\nAlso consider a few on-site tweaks: feature client stories on the homepage, add a clear “Start your free week” CTA, and include a short goal quiz.\n\nIf this resonates, I can draft the full 3-email sequence and a branded banner within a week. Would you be open to a quick 15-minute chat to review details?\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
166	50	24	sent	2025-08-22 00:01:10.920505	1	0	4b0dc77b-8e92-4b8d-b5b6-620622b5c8cc	2025-08-22 00:03:12.368928	Branding tweak for Don Gay's Florist	Hi there,\n\nI wanted to follow up on my note about a domain-branded email for Don Gay’s Florist Bristol. I revisited your site and your floral work continues to stand out—lovely compositions and a clear commitment to quality that resonates with Bristol customers.\n\nHere are a couple of practical wins you can implement quickly, even before broader changes:\n\n- Use a branded reply address that matches your domain, such as hello@dongaysflorist.co.uk, to build trust from the first inbox interaction.\n- Add a consistent email signature that mirrors your in-store signage: your shop name, Bristol contact, and a direct link to dongaysflorist.co.uk.\n- Design a simple welcome or order-confirmation email template that spotlights seasonal arrangements and makes it easy to view your latest bouquets or book delivery.\n\nIf you’d like, I can map a quick 10-minute review of your current emails and draft a ready-to-test branded template for this week.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
179	93	34	sent	2025-08-22 12:35:07.177416	0	0	ee98453a-998f-4a5d-9375-ca58c65ff747	2025-08-22 12:39:14.892428	Kamila, boost trust with branded email	Hi Kamila,\n\nI found Kamila Malitka Photography and was drawn to your ability to capture authentic moments with warm, natural light. Your portfolio seems to focus on intimate connections—moments that clients will remember for a lifetime—relying on trust between you and them to guide the session.\n\nOne immediate thought: a branded email domain reinforces that trust from the very first line. When clients see your messages arriving from kamilamalitkaphotography.com instead of a generic address, it signals professionalism, care, and consistency—qualities that matter when booking someone to photograph life’s most important moments.\n\nBeyond credibility, a branded domain streamlines your client experience: consistent subject lines, cohesive signatures, easy-to-find contact info, and better deliverability. In practice, this small change reduces friction and reinforces the relationship you’re building—long before you even meet.\n\nIf you’d like to explore how a domain-branded email could fit Kamila Malitka Photography, you can learn more at wegetyouonline.co.uk/domain-email. I’d be happy to tailor the approach to your style.\n\nWould you be open to a quick chat this week?\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
276	110	35	sent	2025-08-26 00:06:05.450637	1	0	fbf13647-bcb1-451f-92f6-f5c08b14a5a1	2025-08-26 00:08:14.916217	Mo, new ideas to grow trust	Hi Mo,\n\nFollowing up on my note about Mo Photography & Film and your cinematic, documentary-style wedding storytelling. I revisited moweddingphotographyuk.com and your work really speaks to couples who value real moments.\n\nA small but meaningful way to turn visitors into inquiries is foregrounding trust signals and a clear journey.\n\nThree quick wins:\n- Add a short testimonials section near the top with 2-3 authentic quotes and client photos.\n- Feature a 60-second hero reel on the homepage so first-time visitors feel your vibe within seconds.\n- Clarify the booking process in 3 steps on the homepage (inquiry → consultation → delivery) with a clear call to action.\n\nIf helpful, I can draft a 60-second showreel outline and a homepage wireframe focused on credibility and conversion, or run a quick 15-minute UX audit to pinpoint friction points.\n\nWould love to hear what you think and whether you’d like to explore one of these next steps.\n\nWarmly,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
180	99	34	sent	2025-08-22 12:35:07.177416	0	0	54b930e6-8c07-497c-918c-dba1c2417319	2025-08-22 12:40:42.723634	Harvey Mills Photography: trusted email upgrade	Hi Harvey,\n\nI spent a moment looking at Harvey Mills Photography and was struck by the clean, timeless storytelling in your portfolio. Photographers are trusted with life’s most meaningful moments, and the way you present your work online reinforces that trust every step of the way.\n\nA branded domain email is a small change with big impact. It signals professionalism at first contact, supports clearer communication through proofs and delivery, and helps clients feel they’re in capable hands from inquiry to album. When your emails sit on a branded domain, your voice and your brand stay consistent, which is essential for the trust relationship you’ve built.\n\nA few quick ideas you could apply now: set up a dedicated studio email that matches Harvey Mills Photography’s brand, adopt a single signature with your site and a booking link, and consider an auto-reply that acknowledges inquiries with a link to your portfolio.\n\nIf you’d like to explore how branded domain email can boost client trust for your business, learn more at wegetyouonline.co.uk/domain-email. I’d love to chat about options that fit your workflow.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
182	100	34	sent	2025-08-22 12:35:07.177416	0	0	7db8d817-3b2c-4c84-8a61-a4d41e1b081e	2025-08-22 12:45:09.119869	For Marek Bomba Photography: elevate client trust	Hi Marek,\n\nI took a moment to explore Marek Bomba Photography at mbomba.com, and your portfolio stood out for its storytelling—the quiet, confident light and the way you capture real emotion. That focus on meaningful moments aligns perfectly with the kind of trust clients seek when inviting you to photograph life’s milestones.\n\nIn photography, the relationship you build with clients is as important as the images you deliver. A branded domain email can reinforce that trust from the first hello. When inquiries originate from an address that matches your site, it feels safer and more professional to potential clients, making them more likely to share details about weddings, family sessions, or editorial shoots. It’s a small touch that signals consistency, care, and reliability.\n\nIf you’re curious how a domain-branded email could work for Marek Bomba Photography, I invite you to explore practical options at wegetyouonline.co.uk/domain-email. I’d be glad to tailor a simple plan that fits your brand and workflow.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
181	96	34	sent	2025-08-22 12:35:07.177416	1	0	9bffb91d-c90a-4662-9842-ad1a0cf69297	2025-08-22 12:43:25.423181	Elevate Alex Mills Photographic trust	Hi Alex,\n\nI recently visited Alex Mills Photographic and was drawn to how your images tell genuine stories—your focus on capturing candid moments and your emphasis on client experience clearly shines through your portfolio.\n\nA quick insight: your work appears to balance timeless elegance with a warm, approachable feel, which builds trust before you even say a word. In photography, trust is the backbone of every shoot—from initial inquiry to final delivery.\n\nA branded domain email can reinforce that trust at every touchpoint. When clients see your inquiries and confirmations come from alex@alexmillsphotographic.com, they experience consistency, professionalism, and clarity—especially important when you’re coordinating moments that matter.\n\nWe offer professional domain-branded email tailored to photographers like you, with simple setup and ongoing support. You’ll keep your current branding while making first impressions more confident and memorable.\n\nIf you’d like to explore how this could work for Alex Mills Photographic, learn more at wegetyouonline.co.uk/domain-email. I’d be happy to tailor a quick plan to fit your brand.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
183	98	34	sent	2025-08-22 12:35:07.177416	0	0	4b1348cf-2c92-4dea-8c60-d07ab29b3e52	2025-08-22 12:47:18.54634	Branding email for Marie Carden Photography	Hi Marie,\n\nI’ve taken a moment to explore Marie Carden Photography, and your commitment to capturing authentic moments really comes through in your portfolio. The way you use natural light to highlight genuine expressions helps clients relive their stories—something that makes your work memorable long after the shoot.\n\nIn a business built on trust, even small details matter. A professional domain branded email signals credibility at every step, from first contact to delivery. It makes it easier for clients to remember you and lowers the friction of choosing you for their important moments.\n\nIf you’re aiming to strengthen that trust with a cohesive, professional image, I can help you set up a branded domain email quickly and smoothly. It’s a simple upgrade that aligns with your website and client-first approach. You can learn more about our service at wegetyouonline.co.uk/domain-email, and see how it could fit Marie Carden Photography.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
184	94	34	sent	2025-08-22 12:35:07.177416	0	0	382a96ac-b4c9-4813-b4f8-ebc027e59cd4	2025-08-22 12:49:58.911126	Gemma Poyzer Photography: trust through branding	Hi Gemma,\n\nI’ve spent a few minutes looking at Gemma Poyzer Photography and am impressed by how your work on http://www.gemmapoyzer.co.uk/ tells real stories—moments of joy, calm, and connection. That trust you earn from clients is the backbone of every shoot, from weddings to family portraits.\n\nA simple, practical way to reinforce that trust on every email is a domain-branded address (for example, you@gemmapoyzer.co.uk) aligned with your website. When your messages come from a branded domain, clients feel confident that they’re dealing with the same photographer they saw in your portfolio, not a random inbox. It also helps reduce email confusion or spam concerns, so important moments reach the right people.\n\nWe Get You Online helps photographers set up professional domain email that’s easy to maintain and scales with your brand. If you’d like, I can share a quick outline of options and a sample signature tailored to Gemma Poyzer Photography. Learn more at wegetyouonline.co.uk/domain-email, and we can chat when you’re ready.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
205	65	31	sent	2025-08-23 13:45:02.611598	0	0	31aabece-ca2b-4522-ac08-62766b8cfcde	2025-08-23 14:02:52.422273	Grow Jane Cox Fitness online	Hi Jane,\n\nFollowing up on my last note about the branded approach for Jane Cox Fitness, I keep admiring how you personalize training and track client progress. To help you convert more site visitors into clients without slowing your day-to-day, here are a few quick, practical tweaks you can consider:\n\n- Clarify the hero: a single clear value proposition (e.g., “Personalized 1:1 training with measurable results”) and a prominent “Book a Free Consultation” button.\n- Showcase results: add 2-3 short client outcomes or testimonials with before/after visuals or numbers.\n- Content cadence: 1 weekly client story and 1 practical tip video to post across Instagram and LinkedIn to demonstrate outcomes.\n- Booking flow: simplify the enquiry form and consider a lightweight online booking widget to reduce friction.\n\nIf you’d like, I can do a 15-minute quick audit of your site copy and booking flow with actionable recommendations—no obligation.\n\nCheers,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
185	95	34	sent	2025-08-22 12:35:07.177416	0	0	ca02913e-e03a-4710-9479-2efeb2b1859c	2025-08-22 12:52:10.752163	Branded email for Ryan Hall Studios	Hi Ryan,\n\nI’ve been admiring Ryan Hall Studios' approach to beauty product and personal branding photography. Your portfolio blends crisp product detail with storytelling that helps brands and clients feel confident about the results. In photography, clients entrust you with important moments and their image—your communications should reinforce that trust from the first hello.\n\nA simple upgrade can make a big difference: using a domain-branded email (for example, you@ryanhallstudios.com) signals continuity between your work and your messages, improves recognition, and can boost inbox deliverability. When clients receive inquiries and project updates from a consistent address, the trust relationship starts before the first shoot.\n\nIf you’re curious, I can share a straightforward migration plan to get you set up with minimal downtime. You can explore what we offer at wegetyouonline.co.uk/domain-email and see how it fits with photographers like you.\n\nWould you be open to a quick 10-minute chat to discuss your current email setup and next steps?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
206	76	31	sent	2025-08-23 14:08:17.608408	0	0	e593eb8c-275f-4ef9-a096-d023cc3e4954	2025-08-23 14:08:22.614799	Simple branding tweak for LeonBFitness	Hi Leon,\n\nFollowing up on my note about boosting client trust with a branded email, here’s a straightforward, low-effort approach you can start this week. The aim is to reinforce your credibility at every touchpoint without adding to your workload.\n\nThree practical steps to get moving:\n- Launch a branded onboarding sequence: three emails that use the same logo, colors, and friendly, outcome‑focused language. This helps new clients feel confident from day one.\n- Quick-win templates you can adapt:\n  - Email 1: Welcome and overview. Subject ideas: "Welcome to your LeonBFitness journey"\n  - Email 2: Check-in and progress. Subject ideas: "How's your plan this week?"\n  - Email 3: Next steps and accountability. Subject ideas: "Next steps to reach your goals"\n- Create a lightweight branding kit: a one-page guide with your logo usage, color codes, and a short signature line you can drop into every email.\n\nIf helpful, I can tailor these to LeonBFitness branding and help you deploy in your email tool within 48 hours.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
207	75	31	sent	2025-08-23 14:08:17.608408	0	0	cb9bdfb8-2541-407b-9dba-4dd4b54c971e	2025-08-23 14:10:21.082171	Quick wins for Mark Field Fitness	Hi Mark,\n\nFollowing up on my earlier note about building trust with a branded email, I spent a little time thinking about Mark Field Fitness and your mobile trainer model. Meeting clients where they are is a powerful foundation—now let’s pair it with a crisp, branded touchpoint that reinforces professionalism at every step.\n\nHere are a few quick, practical ideas you could roll out in a couple of weeks:\n\n- Branded welcome and intro emails: a two-email sequence that uses your logo, colors, and a concise “what to expect” from sessions, prep tips, and a simple CTA to book the next session.\n- Social proof that travels: lightweight client stories or before/after highlights (with permission) on a dedicated page or alongside your service pages to build credibility.\n- Booking and discovery made easy: ensure your Google Business Profile is polished and that a clear “Book a Free Intro Session” button links to a mobile-friendly calendar.\n\nIf helpful, I can draft a compact branded email set and a one-page onboarding sheet you can reuse—designed to fit your brand and workflow.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
208	72	31	sent	2025-08-23 14:08:17.608408	0	0	96cd35fe-42c7-467c-a61e-204e68b4c73b	2025-08-23 14:11:44.695447	A simple onboarding tweak for SNL Fitness	Hi there,\n\nFollowing up on my last note about giving SNL Fitness a branded email edge, here’s a practical tweak you can roll out this week to improve onboarding and early retention.\n\nIdea: a short three-email onboarding sequence that mirrors your coaching approach. It helps set expectations, lowers friction, and nudges clients to take action.\n\n- Email 1: Welcome + goal alignment. A simple quick-form for goals and a clear plan for Week 1.\n- Email 2: A fast win. A 15-minute at-home workout or nutrition tip tailored to beginners.\n- Email 3: Quick progress check-in. Invite them to book a 30-minute momentum session and confirm the next steps.\n\nTips to implement fast:\n- Keep branding consistent (logo, color, tone) and include a single clear CTA and a calendar link.\n- Ask for a tiny testimonial after the first milestone.\n- Track opens, clicks, and bookings to optimize over time.\n\nIf you’d like, I can draft the three emails in your brand voice.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
209	74	31	sent	2025-08-23 14:08:17.608408	0	0	4bfdce46-adec-437f-8b5a-51efddf5749b	2025-08-23 14:13:41.453989	Quick follow-up on branded emails	Hi Jess,\n\nFollowing up on my last note about boosting client trust with a branded email, I revisited Jess Wilson PT. Your client-first approach and focus on accountability clearly differentiate your training. I’d love to offer a few quick, low-effort tweaks that align with that message and can lift engagement without a big overhaul.\n\n- Onboarding email: a concise 2-3 sentence welcome that outlines the first week plan, highlights your coaching style, and includes a clear next step (e.g., scheduling a discovery call). This sets expectations and reduces early drop-off.\n\n- Branded signature and footer: a consistent signature with your logo, phone, and a CTA like “Book a complimentary consult” to reinforce trust in every message.\n\n- Social proof nudge: include a single line from a client success story in your weekly updates or progress emails to subtly validate results.\n\nIf any of these feel right, I can draft 2–3 templates in your voice tailored to Jess Wilson PT in under an hour.\n\nBest regards,\nRyan\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
210	68	31	sent	2025-08-23 14:08:17.608408	0	0	934386c5-06bb-4910-8970-d077de94b14c	2025-08-23 14:16:01.77292	Branded emails to boost client trust	Hi there,\n\nFollowing up on my note about boosting client trust with branded emails, I wanted to share a simple approach ENB Fitness can start this week. Your focus on personalized training and real results is a strong foundation—branding the client journey makes that trust tangible at every touchpoint.\n\nTry a lightweight 3-part sequence tied to progress milestones: weekly check-ins, a monthly client spotlight, and a quick goal reminder. Each email would feature a concise progress stat or photo (with consent), one client result or testimonial, and a clear next step (book a session, log a goal, or try a new workout). This keeps communication consistent and makes your value proposition obvious without feeling salesy.\n\nTwo quick wins to start now:\n- Include a small “results snapshot” banner in updates.\n- Use a consistent sign-off that reinforces ENB Fitness and your approach.\n\nIf helpful, I can draft a 5-email sequence tailored to ENB Fitness in under a day.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
211	69	31	sent	2025-08-23 14:08:17.608408	0	0	fbae9f31-76c0-4a30-bfbe-ab3aba772fa3	2025-08-23 14:18:17.234108	Branded onboarding to boost client trust	Hi there,\n\nSince I didn’t hear back from my last note, I wanted to share a practical angle you could test this month that aligns with motivationfitnesspt’s emphasis on personalized training and accountability.\n\nA quick, implementable plan:\n\n- Branded onboarding: a simple 3-part welcome sequence that mirrors your site’s vibe (logo, colors, tone). Part 1: welcome and what new clients can expect. Part 2: the first-week plan. Part 3: a gentle accountability check-in with a quick goal prompt.\n\n- Timing: send the welcome within 24 hours of signup, a check-in on day 3, and a progress nudge on day 7.\n\n- Soft CTA: invite clients to reply with their top goal or to book a first check-in, rather than pushing for a sale.\n\nImplementing this can create a consistent client experience from signup to week one, reducing confusion and early drop-offs. If you’d like, I can draft a starter sequence in your brand voice to save you a few hours. I can also help set up a lightweight tracking plan to monitor engagement.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
215	79	31	sent	2025-08-23 14:32:46.850078	0	0	89830ee3-e7c8-4323-8993-ba803d60c071	2025-08-23 14:33:15.856205	Boost trust with onboarding emails	Hi Kimmy,\n\nFollowing up on my previous note about building trust with branded email, I wanted to share a few practical angles that align with Get Fit with Kimmy’s personalized coaching.\n\nOnboarding sequence (3 emails): set expectations, introduce your approach, and invite early questions. Include a brief transformation story and a link to a testimonial that resonates with your audience.\n\nAccountability check-ins: friendly weekly nudges with a quick progress prompt and a suggested plan for the next week. Keep the tone encouraging and focused on measurable wins.\n\nTestimonial prompts: after milestone workouts, ask for simple feedback and shareable results. Pair with confidence-building visuals that fit your branding.\n\nBranding tune-up: ensure a consistent tone, logo placement, and a concise signature in every message.\n\nIf you’d like, I can draft a tailored 3-email onboarding sequence and a one-page branding brief aligned to your voice. I can also run a quick 20-minute audit of your current emails and suggest two concrete tweaks to improve engagement and trust.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
216	78	31	sent	2025-08-23 14:32:46.850078	0	0	fb95a3b8-9703-4fc3-b623-0c8d7c40a599	2025-08-23 14:33:51.063798	Stuart, a fresh branding idea for Motiv8	Hi Stuart,\n\nFollowing up on my note about boosting trust with a branded email for Motiv8 Personal Training, I spent a bit more time thinking about a lightweight approach you can start using today—without changing your core client process.\n\nIdea: a simple branded email sequence that mirrors Motiv8’s client-first ethos: 1) a warm welcome that outlines how you tailor workouts and track progress, 2) a gentle mid-program progress check with actionable next steps, and 3) a quick client story or result highlight with a clear CTA to continue or book a consult.\n\nThree quick wins you can implement this week:\n- Use consistent Motiv8 colors and your logo in the header to appear in every inbox.\n- Include one result-focused line or testimonial in each email.\n- Add a single CTA (e.g., “Book a 15-min strategy call”) and a link to a recent client story.\n\nIf you’d like, I can draft a complete 3-email sequence tailored to Motiv8’s voice and add it to your CRM.\n\nWould you have 15 minutes this week for a quick chat?\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
217	77	31	sent	2025-08-23 14:32:46.850078	0	0	32987029-eef9-4a82-8de2-91bfd6b178b7	2025-08-23 14:35:40.39891	A quick idea for client trust	Hi Jack,\n\nFollowing up on my note about boosting client trust with a branded email, I wanted to share a simple, testable plan you could try this week for Jack Williamson PT.\n\nThree quick steps:\n\n- Onboarding sequence: a 3-part welcome series that uses your logo, color, and tone to set expectations and invite a quick progress check.\n\n- Weekly progress snapshot: a short update you can send every Friday, with two measurable metrics (workouts completed, energy level or weekly goal) and a next-step CTA.\n\n- Monthly client spotlight: one success story with a before/after detail and a pasteable testimonial link to reinforce credibility.\n\nIf you’d like, I can tailor these templates to match your branding and voice. Happy to review what you already have and suggest small refinements that improve open rates and response.\n\nWould you have 15 minutes this week for a quick chat?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
214	73	31	sent	2025-08-23 14:08:17.608408	1	0	e97e2bbe-323d-4e31-8946-50565d3e18a4	2025-08-23 14:25:10.520547	A fresh angle for New Physique	Hi there,\n\nFollowing up on my earlier note about elevating New Physique Personal Training with branded email, I wanted to share a practical angle you can test this week.\n\nIdea: turn client progress into shareable, brand-consistent stories that feel personal while staying respectful of privacy. Three easy steps:\n\n- Create a weekly “Progress Spotlight” email featuring a client goal, a single measurable result (e.g., inches lost, workouts completed, weeks in program), and a brief, authentic quote. Secure consent and keep details simple.\n\n- Use a clean branded template with your colors and logo, plus a recurring subject line like “New Physique — Week X Wins.”\n\n- Measure impact with three metrics: open rate, click-through to a short client story page, and replies with interest to share more or book a session.\n\nIf you’d like, I can draft a 2-week starter sequence tailored to New Physique’s tone and audience.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
267	107	35	sent	2025-08-25 13:00:43.580014	0	0	7ab2d0fc-3766-4edd-9da6-0680ae18e2a4	2025-08-25 13:01:21.587167	Boost client trust in your emails	Hi Lucy,\n\nI hope you’re well. Following up on my last note about branded email for Lucyewarner Photography, I wanted to share a couple of quick, practical ideas to enhance trust with your inbox audience—without changing your voice.\n\nTwo tweaks you can try this month:\n- Lead with a strong, warm hero image: place one standout moment from a recent shoot at the top, with a short caption that ties to your storytelling approach.\n- Add a human touch and proof: include a brief client quote and photo credit in a sidebar near your logo so readers feel the emotion behind your brand.\n\nBonus: simplify the path to inquiry with a single, clear button in a brand-consistent color—e.g., “See Packages” or “Check Availability”—so new inquiries have an easy next step.\n\nIf you’d like, I can draft a quick two-email flow aligned to your portfolio and site to test these ideas. I’m happy to tailor tone and visuals to match Lucyewarner Photography.\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
268	104	35	sent	2025-08-25 13:00:43.580014	0	0	b906f929-a1e2-4923-9016-4eed02b42039	2025-08-25 13:02:33.730436	A quick idea for Irina GS Photography	Hi Irina,\n\nFollowing up on my note about elevating Irina GS Photography with branded email, I wanted to share a practical approach that fits your style—authentic, light-filled moments and true client connection.\n\nThree small steps you can start this month:\n\n- Welcome inquiry email: send within 24 hours with a favorite image from your recent work, a concise outline of your process, and a clear next step to book a discovery call. Keep the tone warm and human.\n\n- Post-session follow-up: include the client’s gallery link, a brief note inviting feedback or a testimonial, and a soft reminder of your availability.\n\n- Monthly portfolio highlight: a simple update that features a recent shoot focused on natural light and candid moments, with one clear CTA to view the full gallery on your site.\n\nIf you’d like, I can tailor a concise plan and draft a welcome email for Irina GS Photography so you can test it quickly—no heavy lift, just a starting point.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
218	80	31	sent	2025-08-23 14:32:46.850078	0	0	d84dd4e6-cbd0-49fc-92a6-83420ddca263	2025-08-23 14:37:59.42456	A practical step to strengthen client trust	Hi Lee,\n\nFollowing up on my note about boosting client trust with branded emails, I wanted to share a quick, practical approach you can try this week.\n\n- Onboarding sequence: a simple 3-part welcome series focused on goal alignment, milestone clarity, and one early win from a real client. Keep it concise, actionable, and aligned with how you coach.\n\n- Real results in context: pair short before/after snapshots with a fresh testimonial and a consented client photo. This kind social proof travels well in emails and on your site without feeling pushy.\n\n- Consistent branding: mirror Dedicated Coaching colors and typography in each touchpoint so emails feel like a natural extension of your coaching, not a separate tool.\n\nIf helpful, I can draft a ready-to-send 3-email onboarding sequence that matches your branding and includes a quarterly progress update template you can share with clients.\n\nWould love to hear what outcomes you’re prioritizing this quarter and whether you’d be open to testing a light, branded onboarding sequence.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
219	25	25	sent	2025-08-24 20:32:58.691497	0	0	8b72f821-c00d-4fc4-8b41-3c38bc516aa8	2025-08-24 20:33:05.699422	Final note: branded emails for Nottingham	Hi there,\n\nThis is the final note in my outreach about giving The Florist Nottingham a branded email domain to boost trust, inbox delivery, and customer engagement. I’ve touched on brand consistency and performance in my previous messages, and I’d like to offer three practical steps you can implement this week.\n\n- Set up SPF/DKIM for your domain and test deliverability with a couple of recent campaigns to see improvement in open and reply rates.\n\n- Create a simple, memorable branded address (for example hello@thefloristnottingham.co.uk) and route enquiries to a dedicated team mailbox to speed responses and build trust.\n\n- Consider a lightweight welcome email series and season-specific campaigns with consistent visuals and subject lines to lift engagement.\n\nTo make trying this risk-free, we’re offering the first 3 months for £1 a month using code 1EMAIL.\n\nIf you’d like, I can map a 30-minute setup plan tailored to your catalog and promotions.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
220	33	25	sent	2025-08-24 20:32:58.691497	0	0	bad011d2-468b-4278-8fa8-c7859d64a557	2025-08-24 20:34:48.698286	Quick wins for Jas and Floral online	Hi there,\n\nFollowing up on my previous notes about boosting Jas and Floral online, here are a few quick wins you can implement in a couple of hours that tend to pay off fast.\n\n- Refresh your homepage banner with a clear value prop and a couple of best-sellers, plus a straightforward “Order online” CTA. Crisp photography helps capture attention and conversions.\n\n- Sharpen product pages: add 1–2 sentence descriptions per bouquet, confirm prices, and ensure a visible “Order online” or “Delivery” button. If you’d like, I can draft example copy tailored to your style.\n\n- Strengthen local presence: claim your Google Business Profile, keep hours accurate, and add 3 new photos of recent arrangements. Encourage a quick review from a satisfied customer.\n\nTo make this easy to test, we’re offering the first 3 months at £1 per month with code 1EMAIL for a branded domain email setup and related improvements.\n\nIf you’d like, I can tailor these steps to Jas and Floral and your current site. A short 10-minute chat this week could lock in the most impactful changes.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
221	30	25	sent	2025-08-24 20:32:58.691497	0	0	f3779571-933b-4253-96da-e66e8907c7aa	2025-08-24 20:36:36.198467	Final follow-up: elevate Wild Meadow Floral branding	Hi there,\n\nFollowing up on my previous emails about a domain-branded email for Wild Meadow Floral, I wanted to share a simple, concrete plan you can apply this week to boost trust and consistency with customers.\n\nA branded email domain signals professionalism and improves deliverability. It also unites your emails, website, and social channels, reducing any confusion for customers ordering flowers.\n\nHere are 3 quick steps you can implement today:\n- Set up a primary branded address for orders and inquiries (e.g., hello@wildmeadowfloral.co.uk).\n- Create a consistent email signature with your brand colors and contact info.\n- Add a clear auto-reply for orders confirming receipt and delivery window.\n\nTo make it easy to trial, we’re offering the first 3 months for £1 a month with code 1EMAIL.\n\nIf helpful, I can tailor a quick setup plan for your team and provide a short guide to get you live in under 24 hours.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
222	28	25	sent	2025-08-24 20:32:58.691497	0	0	767908bb-7768-40c8-bbda-cfc827c72b66	2025-08-24 20:38:57.22961	Boost Blodau Tlws with branded emails	Hi there,\n\nI wanted to circle back on my previous notes about strengthening Blodau Tlws' digital presence with a dedicated domain inbox and branded emails. For a florist, a professional inbox isn't just about looks—it improves deliverability, trust, and customer responses, especially during peak seasons like Mother's Day or Christmas.\n\nA quick plan you can act on this week:\n- Set up hello@blodau-tlws.co.uk and support@blodau-tlws.co.uk to keep inquiries aligned with your site.\n- Launch a simple 3-email welcome/ordering flow: 1) thanks for visiting, 2) how to place an order and care tips, 3) post-purchase care and future promotions.\n- Build a seasonal promotions calendar and a light automation to remind customers of timely bouquets.\n\nTo make this easy, we’re offering the first 3 months for £1 a month with code 1EMAIL. If you’d like, we can map a 15-minute plan and get the setup started.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
223	26	25	sent	2025-08-24 20:32:58.691497	0	0	9b9e62bd-dc7b-4871-9600-f80a31e6754f	2025-08-24 20:41:15.707643	Lasting branding boost for Art of Flowers	Hi there,\n\nFollowing up on my earlier notes about a domain-branded email and a simple branding boost for Art of Flowers Nottingham, I wanted to share a quick, practical plan that many florists find easy to implement and see benefits from in days, not weeks.\n\n- Create a dedicated domain email: hello@artofflowersnottingham.co.uk you can use for bookings, inquiries, and supplier messages. It instantly communicates professionalism and helps you keep client emails organized.\n- Standardize your signature: one clean signature across any device with your name (or Art of Flowers Nottingham), your website, and a contact number. A consistent signature builds trust and improves click-through rates.\n- Simple auto-response: a friendly acknowledgement that sets expectations (e.g., Thanks for reaching Art of Flowers. We’ll reply within 1 business day.) plus a link to your online portfolio.\n\nAs a thank you for considering, we’re offering the first 3 months at £1 per month using code 1EMAIL.\n\nIf you’d like, I can set up a quick pilot with one domain email and a starter signature in about 20 minutes. Would you have 15 minutes this week for a quick chat?\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
212	70	31	sent	2025-08-23 14:08:17.608408	1	0	f9c65d41-ac1a-4128-ae59-9c9367fd8a18	2025-08-23 14:20:39.591765	A quick win for The Cabin Personal Training	Hi there,\n\nFollowing up on my note about The Cabin Personal Training in Havant and your focus on personalized coaching and client trust, I wanted to share a couple of practical tweaks that can start delivering results this quarter.\n\n- Improve your online lead flow: update your Google Business Profile with Havant-area service descriptions, fresh client photos, and a clear “Book your intro session” button on the homepage.\n\n- Local lead magnet idea: a simple 3-day Havant-focused home workout plan plus nutrition tips—packaged on a short landing page and shared via social or local communities.\n\n- Simplify the booking path: keep the inquiry form short (name, email, goal) and route directly to a calendar for an intro call.\n\n- Measure and iterate: track weekly inquiries and conversions, aiming to increase inquiries by 2–3 per week with small tweaks.\n\nIf you’d like, I can draft a concise one-page plan tailored to The Cabin in Havant that you can implement this week.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
213	71	31	sent	2025-08-23 14:08:17.608408	1	0	7d4b5c50-59af-42b1-981f-6594fb3811b2	2025-08-23 14:23:15.188203	Branded emails for FJK Fitness	Hi there,\n\nFollowing up on my last note about building trust with a branded email, I wanted to share a simple, quick-win you can implement this week.\n\n- Use a branded address: consider info@fjkfitness.co.uk or hello@fjkfitness.co.uk. It signals professionalism when clients book, message, or reply.\n\n- Improve inbox delivery: ask your domain host to add SPF and DKIM records (and a DMARC policy). That helps ensure messages reach clients and reduces the chance of being marked as spam.\n\n- Consistent signature: set a standard email signature for your team that includes your website and a clear call to action, like booking a session. A cohesive look boosts credibility across devices.\n\nIf you’d like, I can draft a 60-second plan to switch over with zero disruption and outline a brief 3-email intro sequence for new clients.\n\nI’m happy to tailor these steps to FJK Fitness’s setup or discuss any questions you have.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
171	90	34	sent	2025-08-22 12:12:39.966876	1	0	0dfbf5bb-7fb2-424c-a85c-9bead5900532	2025-08-22 12:18:18.819859	A trusted touch for Front Row Photography Cardiff	Hi there,\n\nI’ve been checking out Front Row Photography Cardiff and your work capturing life’s big moments in Cardiff. Your focus on authentic, storytelling imagery suggests you build lasting relationships with clients—trust that starts long before the first photo is taken and continues through every email.\n\nOne practical way to reinforce that trust from the first impression is with a professional domain-branded email. A branded address, for example hello@frontrowphotographyuk.com, signals a serious, client-focused business and makes your messages feel more personal and reliable. It’s a small change that can boost confidence, improve reply rates, and keep communications consistent with your brand.\n\nIf you’re open to exploring how this could work for Front Row Photography Cardiff, I’d be happy to show you what a branded email can look like and how it aligns with your existing branding. You can also learn more at wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
294	60	32	sent	2025-08-27 12:48:47.335385	0	0	09ee4f4c-c71d-47bf-a2ce-280eb5c5a112	2025-08-27 13:01:58.366475	NPerformance Poole: final note + 1-month trial	Hi there,\n\nFollowing up on my previous emails about NPerformance Personal Training Poole, I wanted to share a practical idea that complements your hands-on, client-first approach. When clients can see a clear path to their goals and feel tracked along the way, bookings and retention tend to rise.\n\nHere's a simple plan I can tailor: a 4-week onboarding with goal discovery, a starter program aligned to aims, weekly check-ins, and a concise progress report they can view online. We can deliver this through a lightweight client portal or via personalized emails—no heavy lift, just a steady, human touch. It scales with your client base and can adapt to Poole’s schedule.\n\nTo prove the concept, I’d like to offer a no-commitment 1-month complimentary trial of the setup with your actual client list. If this resonates, a quick 20-minute chat to customize for Poole’s rhythms would be enough to move forward. I’ll keep it brief and respectful of your time—no pressure.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
295	62	32	sent	2025-08-27 12:48:47.335385	0	0	6c639f4a-16b9-46c2-b2c3-3e2bf4b164ff	2025-08-27 13:05:05.958168	No-commitment 1-month trial for Fit N Fresh	Hi Dan,\n\nI hope you’re well. I revisited fitnfreshcoaching.com and your emphasis on sustainable results and personalized coaching stands out. Following up on my prior notes, I see a clear path to turning more site visitors into engaged clients without compromising your coaching approach.\n\nI’d like to offer a no-commitment, 1-month complimentary trial focused on turning interest into action. During the trial, we’ll implement a practical setup:\n\n- A concise onboarding flow (5 questions) to capture goals, routines, and accountability preferences.\n- An automated weekly progress check-in (email with optional SMS) to reinforce accountability and reduce churn.\n- A simple plan to collect and showcase 2 client success stories, boosting credibility.\n- A minor site tweak to highlight a clear Get Started offer above the fold, plus a one-page case-study highlight.\n\nIf this resonates, I’m happy to jump on a 20-minute call to align on goals and kick off. No obligation after 30 days if you decide not to continue.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
296	59	32	sent	2025-08-27 13:10:39.304089	0	0	6d27f07e-740a-4c8f-8a55-45950c3e9205	2025-08-27 13:11:27.310465	No-commitment onboarding trial	Hi there,\n\nFollowing up on my previous notes about boosting trust with a branded email for Ocean Fitness Poole, I want to offer a practical, low‑effort plan you can test this week that fits your client‑centric approach.\n\nPlan overview:\n- Onboarding email: After a new signup, send a concise branded email that confirms goals (pull from intake), outlines first 2–3 steps to start, and includes a direct link to book the first session or a quick goal‑check survey.\n- Tone and assets: Use your brand colors, logo, and a real trainer photo if possible to increase recognition and trust.\n- Quick test: Run two variants for a week—variant A highlights goal recap; variant B adds a 7‑day progress check‑in.\n\nMetrics to watch: open rate, click‑through to booking, and first‑session booking rate.\n\nIf you’d like to explore impact without risk, we can run a no‑commitment one‑month complimentary trial of branded onboarding for Ocean Fitness Poole and measure how trust and conversions shift.\n\nWould you be open to a quick 15‑minute chat this week to tailor this to your brand?\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
196	111	34	sent	2025-08-23 00:04:22.00744	1	0	988e37b6-5e1d-4550-b6b4-a8b8e385af0e	2025-08-23 00:08:01.338368	Boost client trust for Anna Martin Photography	Hi Anna,\n\nI recently spent a few minutes exploring Anna Martin Photography. Your portfolio communicates authentic storytelling with a warm, timeless feel—clear evidence that you put trust at the heart of every shoot.\n\nPhotographers are entrusted with life’s most meaningful moments. A branded domain email helps reflect that trust from the first hello. When inquiries come from hello@annamartinphotography.com or bookings@annamartinphotography.com, clients see a cohesive brand rather than a generic inbox. That reassurance can smooth inquiries, bookings, and coordination, and also improves email deliverability—so messages don’t get lost.\n\nIf you're considering a switch, I’d be happy to share a simple path to a professional domain email that aligns with your site and branding. You can learn more about what we offer at wegetyouonline.co.uk/domain-email.\n\nWarm regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
278	68	32	sent	2025-08-27 12:27:00.065711	0	0	2e613efb-e115-4d51-95dc-7f8f81c15678	2025-08-27 12:27:06.09079	A fresh angle to boost client trust	Hi there,\n\nI hope you’re well. Following up on my previous notes about boosting client trust with branded emails, I’d like to offer a practical, low-friction approach you can start this week—focused on real client results that people can actually relate to.\n\nHere’s a simple plan you can implement quickly:\n- Create one branded “Progress Spotlight” email per week featuring a client story (consent and anonymity options if preferred) and measurable results (e.g., reps, rate of progress, consistency).\n- Pair each email with a consistent visual frame: logo, color, and a short client quote to reinforce trust.\n- Include a clear call to action for clients to share goals and for prospects to book a session.\n\nIf you’d like, I can set up a no-commitment one-month complimentary trial of branded emails so you can test the impact and see how clients engage without risk.\n\nWould you be open to a quick 10-minute chat this week to tailor this to ENB Fitness and your client journey?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
279	74	32	sent	2025-08-27 12:27:00.065711	0	0	d8c9d025-52ec-4988-8b08-749b7cb84b36	2025-08-27 12:28:12.161669	One-month branded email trial (no commitment)	Hi Jess,\n\nI’ve followed up on my earlier notes about strengthening client trust through a branded email approach. Your emphasis on accountability and results makes the client journey feel personal—an edge we can amplify with a simple, proven email sequence.\n\nHere's a practical 3-email framework you can test this month:\n- Onboarding welcome: sets expectations, shares your methodology, and invites the first value-packed check-in.\n- Progress check-in: asks for feedback, highlights measurable wins, and suggests next steps.\n- Referral nudge: celebrates client milestones and softly invites a friend or IG follower to join.\n\nTo make this easy, I can set up a no-commitment 1-month complimentary trial of a branded email sequence for Jess Wilson PT. You’ll receive templates, subject lines tuned for gym clients, and a quick analytics snapshot to show engagement uplift.\n\nIf you’re open to it, I’ll tailor the copy to your voice and tone and drop a ready-to-send pack in your inbox. No risk, just a quick way to boost trust, retention, and referrals.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
280	75	32	sent	2025-08-27 12:27:00.065711	0	0	fada3429-e43e-4638-9276-07f7fd5d3840	2025-08-27 12:30:15.213431	Trust boost for Mark Field Fitness	Hi Mark,\n\nI wanted to circle back after my two notes about branded emails for Mark Field Fitness. I know you’re delivering mobile, client-centered training, which means trust and easy booking are critical in your week-to-week workflow. Here are two quick tweaks that align with your model and your clients’ reality:\n\n- Lead with real-world results: include a brief client story or a before/after in every email to show how sessions translate outside a gym or studio.\n\n- One clear next step: end each message with a single, obvious action (schedule a 15-minute intro, text START to trigger a consult, etc.) with a mobile-friendly link.\n\nIf you’d like, I can draft a three-email sequence tailored to your mobile trainer model, plus ready-to-test subject lines. As a no-commitment one-month trial, I’ll run it for you, monitor opens and clicks, and adjust content to improve response rates within 4 weeks.\n\nIf you’re open to a quick chat, I’d love to tailor this to Mark Field Fitness and your current client journey.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
281	73	32	sent	2025-08-27 12:27:00.065711	0	0	ab753adc-a2a1-46fb-a782-e75c28723cd3	2025-08-27 12:31:59.900107	A practical next step for New Physique	Hi there,\n\nFollowing up on my earlier notes about elevating New Physique Personal Training with branded email, and the practical angle I shared on turning client progress into stories, I want to offer one more value-driven option you can test this week.\n\nHere's a simple, low-effort approach you can implement in 3 steps:\n- Create a weekly client spotlight: one concise progress story (2-3 lines) with a concrete, relatable metric and a photo if you have consent.\n- Pair each story with a short, benefit-focused CTA: “Discover how we tailor plans for real results” linking to a booking page or simply inviting a call.\n- Use a consistent, friendly tone that mirrors client-centered language you already use.\n\nWhy this works: it builds trust with new clients, demonstrates progress storytelling, and creates social proof without heavy production.\n\nTo remove any risk, I’m offering a no commitment 1 month complimentary trial of our branded-email setup so you can see the impact with zero obligation. If interested, reply “Yes, trial” and I’ll send a ready-to-use draft for your first campaign.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
282	76	32	sent	2025-08-27 12:27:00.065711	0	0	6b124e44-01ba-4089-8653-49d5b18c70d6	2025-08-27 12:33:26.318073	Trust-building email tweak + 1-month trial	Hi Leon,\n\nFollowing up on my earlier notes about boosting client trust with a branded email, here’s a focused approach you can test this week. Create a short welcome/consultation email that highlights LeonBFitness’s tailored training, accountability, and a quick client success quote. Pair it with a two-step follow-up: 24 hours after inquiry, then one week later with a clear next step.\n\nPractical tweaks:\n- Subject: “Your first week with LeonBFitness.”\n- Include a brief testimonial or before/after snapshot.\n- End with a branded signature and one credibility badge.\n\nI’m offering a no-commitment 1-month complimentary trial of our branded-email setup for LeonBFitness. I can configure three emails and provide a simple dashboard with opens, clicks, and booked sessions.\n\nIf you’re open, I’d be happy to tailor this to your schedule. By tracking opens and bookings from the trial, we can quickly validate impact and refine the message for LeonBFitness.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
283	69	32	sent	2025-08-27 12:27:00.065711	0	0	c0b8faaf-c852-4f53-a15f-1846693e60d7	2025-08-27 12:36:26.732222	No-commitment 1-month onboarding trial	Hi there,\n\nFollowing up on my earlier notes about strengthening client trust through branded onboarding and consistent accountability messages, I wanted to offer a practical approach you can test this month.\n\nHere's a simple onboarding blueprint tailored for motivationfitnesspt:\n- Branded welcome email that sets expectations and shows the path to results.\n- A quick-start plan with 3 starter workouts and a first-week personal goal.\n- Weekly progress check-ins and milestone updates to keep clients engaged.\n- A lightweight testimonial ask after the initial progress period.\n- Clear next steps for ongoing coaching and renewals.\n\nTo make this easy, I’m offering a no-commitment 1-month complimentary trial of a branded onboarding package you can implement with motivationfitnesspt.co.uk today. If it resonates, we’ll tailor visuals and copy to your branding and client journey, aiming to go live in days—not weeks.\n\nWould you be open to a 15-minute chat to outline next steps?\n\nCheers,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
225	29	25	sent	2025-08-24 20:32:58.691497	0	0	b0593554-bac7-40be-a2e9-81b6cf70ff3d	2025-08-24 20:46:39.338721	Final idea: branded emails for About Flowers	Hi there,\n\nFollowing our earlier messages about a branded, domain-based email for About Flowers, I wanted to share a practical, fast-start plan you can implement within days—and it’s designed to boost trust, consistency, and response rates from your florist customers and gift buyers.\n\nWhat you can do this week:\n\n1) Set up two branded inboxes on your domain: orders@aboutflowers.co.uk for orders and support@aboutflowers.co.uk for questions. That immediate recognition reduces confusion and improves deliverability.\n\n2) Create 3 ready-to-use templates: order confirmation, delivery update, and care instruction. Personalize with the About Flowers tone, include a clear call to action, and keep images lightweight for mobile.\n\n3) Sync with your marketing: reuse your brand colours, logo, and signature style. Add a short welcome line to new subscribers and promote seasonal bouquets.\n\nAs a bonus, we’re offering the first 3 months for £1 a month using code 1EMAIL.\n\nIf you’d like, we can tailor these templates to your exact products and holiday campaigns in a 20-minute call. Happy to help you get this live fast.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
226	24	25	sent	2025-08-24 20:32:58.691497	0	0	caaba26d-e366-48d3-8986-07a05fc11aee	2025-08-24 20:48:56.144531	A simple upgrade for Mapperley Blooms	Hi there,\n\nFollowing up on my previous notes about a branded domain email for Mapperley Blooms, I wanted to share a practical angle you can act on today. A professional domain email does more than look polished; it helps every touchpoint feel reliable—from order confirmations and delivery notices to promotions and replies to customer questions. It also improves deliverability (less likely to end up in junk) and makes team communications seamless, which matters when busy florists juggle multiple orders and tight deadlines.\n\nIf you’re exploring a low-friction upgrade, here’s a simple path:\n- Set up a branded email tied to your domain\n- Create a few ready-to-send templates for orders, quotes, and inquiries\n- Optionally set up a shared inbox for customer support so no message slips through\n\nTo make this even easier, we’re offering the first 3 months for £1 a month with code 1EMAIL. No big commitment—just a smoother customer experience.\n\nWould you have 10 minutes this week for a quick chat or I can send a tailored plan?\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
227	32	25	sent	2025-08-24 20:32:58.691497	0	0	78482342-a5cc-404f-b2ed-5b086649ed82	2025-08-24 20:51:37.786227	Final follow-up: domain email for Sweet Peony	Hi there,\n\nI wanted to circle back on my previous notes about branded domain email for Sweet Peony Florist. I know you’re busy delivering stunning arrangements, so here’s a simple path you can implement this week to boost trust and save time.\n\nThree quick steps:\n- Create a consistent primary address (for example hello@sweetpeonyfloral.co.uk) and use clear aliases for inquiries, orders, and weddings.\n- Align signatures and response templates across the team so every reply looks and sounds like Sweet Peony Florist.\n- Route client emails through the same domain to keep branding in every touchpoint and improve credibility.\n\nAs a next step you can try the full setup with the first 3 months for £1 a month using code 1EMAIL. If you’d like, I can tailor this to your current workflows and propose a quick three-point rollout.\n\nWould you be open to a 15-minute chat this week? If so, reply with a couple of times that work, and I’ll send a calendar invite.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
224	27	25	sent	2025-08-24 20:32:58.691497	1	0	71ba4395-fc3f-436a-b079-cbd909e0af06	2025-08-24 20:43:42.500113	Garlands: quick steps for online growth	Hi there,\n\nFollowing up on my earlier notes about Garlands’ online presence—and the idea of a domain-branded email for your team—I wanted to share a concise, practical plan you can start this week.\n\n- Local visibility: claim or update your Google Business Profile with current hours, a few fresh photos of recent bouquets, and respond to reviews to show you’re listening.\n\n- On-site clarity: highlight 3 bestsellers on the homepage, with clear delivery areas and a simple add-to-cart path. A quick seasonal bundle can drive higher order value.\n\n- Professional email: a domain-branded address (for example team@garlandsofllandaff.co.uk) can raise trust with customers and partners. If helpful, I’ll outline a streamlined setup.\n\nAs a gesture, We Get You Online is offering the first 3 months for £1 per month when you use code 1EMAIL. If you’d like a quick 15-minute audit of your site and social presence, I’ll tailor a short plan for Garlands.\n\nWould you be open to a brief chat this week?\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
228	39	25	sent	2025-08-24 20:57:15.78522	0	0	7812b2d2-91be-44ab-931f-da973c261ed3	2025-08-24 20:57:52.791695	Final follow-up for Sherwood Florist	Hi there,\n\nI’ve revisited Sherwood Florist’s site and your floral work continues to impress. In my previous messages I highlighted how a professional email domain and consistent branding can boost trust and inquiries. Since we haven’t connected yet, here are a few quick, practical tweaks you can test this week that often move the needle for florists:\n\n- Add a simple "Request a quote" or "Book a consultation" form on the homepage to capture event details early.\n- Set up a short welcome email series for new subscribers with timely bouquet ideas and a seasonal offer.\n- Ensure your Google Business Profile is complete with up-to-date hours, phone, and 3 high-quality product photos.\n\nAs a friendly incentive, we’re offering the first 3 months for £1 a month with code 1EMAIL. If you’d like, I can prepare a 2-week action plan tailored to Sherwood Florist and walk you through it in a quick call.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
285	70	32	sent	2025-08-27 12:27:00.065711	0	0	2c281b90-6d8d-42eb-96b0-2e67c3ef1353	2025-08-27 12:40:57.19631	A fresh idea for The Cabin	Hi there,\n\nFollowing up on my earlier notes about The Cabin Personal Training in Havant and your focus on personalized coaching and client trust, I’d like to share a practical approach you can test quickly. Since this is my final outreach in this thread, I’m offering a low‑risk option to prove the value.\n\nOnboarding clarity: offer a simple 1-page plan for new clients that outlines intake, baseline goals, 4‑week milestones, and weekly check‑ins. This sets expectations and builds trust from day one.\n\nSocial proof: publish one short client success snapshot each month (goal, progress, a photo) to boost inquiries without a heavy lift.\n\nLow-friction trial: consider a no‑commitment 1‑month complimentary trial for new clients, with a clear exit option and a small cap on trial slots.\n\nMetrics that matter: track inquiries, onboarding completion rate, and 4‑week retention to gauge impact.\n\nIf you’d like, I can set up this no‑commitment 1‑month complimentary trial for The Cabin to test the impact on inquiries and retention—no long‑term obligation.\n\nWould you be open to a brief 15‑minute chat to tailor this to Havant’s audience?\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
229	41	25	sent	2025-08-24 20:57:15.78522	0	0	da1d8b3d-9a20-47b0-8622-ca3d369e4ca9	2025-08-24 20:59:01.558225	Final step: budget-friendly email upgrade	Hi there,\n\nFollowing up on my previous messages about branding Claire’s Floristry and Tea Room with a domain-based email, here are three practical steps you can implement this week to boost credibility and streamline inquiries.\n\n- Set up a primary address at hello@clairesfloristry.co.uk and connect it to your current email client so you can send and reply from the brand domain, reducing confusion for customers.\n- Update your email signature and the website contact page to reflect the new domain, include a simple call to action, and ensure hours and location are easy to find.\n- Create lightweight forwarding rules and filters so new inquiries—weddings, events, and shop reservations—arrive in one organized inbox, enabling faster responses.\n\nThese changes can be tested quickly and often lead to faster response times and stronger trust with clients.\n\nTo make this easy, we’re offering the first 3 months for £1 a month using code 1EMAIL. If you’d like, I can tailor the setup to your needs and share a quick 15-minute plan.\n\nWarm regards,\n\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
230	36	25	sent	2025-08-24 20:57:15.78522	0	0	843c5427-5cd7-46f6-b409-ff7ca43bd2da	2025-08-24 21:01:11.607394	Final note: boost New Leaf Floristry	Hi there,\n\nFollowing up on my earlier notes about boosting New Leaf Floristry’s online presence, I wanted to share two practical steps you can start this week that directly impact inquiries and bookings.\n\n1) Brand your inbox: set up a branded domain email (you@newleaffloristry.net). It builds trust with customers and improves deliverability, so more messages reach you rather than getting filtered as spam.\n\n2) Improve local visibility: claim and optimize your Google Business Profile. Add high-quality bouquet photos, post weekly updates, and respond to reviews. This helps you appear in local search and map results when customers look for florists nearby.\n\nAlso ensure your website has clear calls to action, like “Book a free consultation” or “Request a quote,” with a straightforward form.\n\nAs a gesture, we’re offering the first 3 months for £1 a month using code 1EMAIL. If you’d like, I can tailor this setup to New Leaf Floristry’s schedule.\n\nWishing you continued success, and I’d be happy to help you implement these steps when you’re ready.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
231	42	25	sent	2025-08-24 20:57:15.78522	0	0	211b14e9-06f8-41c1-b6e1-1fac361f9b8f	2025-08-24 21:02:26.588381	Boost Blooms The Florist Emsworth Online	Hi there,\n\nFollowing my previous notes about a branded domain email, I wanted to share a practical win you can act on this week that directly supports Blooms The Florist Emsworth’s growth.\n\nWhy this matters: customers trust a sender they recognize, and branded emails improve deliverability and click-through. Quick wins:\n\n- Point your transactional and marketing messages to a bloomstheflorist.co.uk address and ensure your SPF and DKIM records are configured. This boosts inbox placement and reduces spoofing risk.\n\n- Create a simple, consistent signature (name, title, website) and use a single reply-to that goes to your team inbox.\n\n- Draft a short, friendly template for order confirmations and delivery updates that highlights your store’s personality.\n\nIf you want a head start, I can set this up and show you the first three steps end-to-end. And as a thank you for exploring with us, we’re offering the first 3 months for £1 a month using code 1EMAIL.\n\nWould you like to jump on a quick 15-minute chat this week to map out a domain email and the onboarding steps? Happy to tailor to Blooms The Florist Emsworth’s schedule.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
233	43	25	sent	2025-08-24 20:57:15.78522	0	0	6fe7c394-5e9c-4384-a047-ca485fe286f9	2025-08-24 21:06:39.287957	Final follow-up: branded emails for Portsmouth	Hi there,\n\nI’ve followed up a couple of times about helping Christmas Trees Portsmouth present a more professional, trusted brand through domain-branded emails. For florists, a cohesive email address setup signals reliability and can boost reply rates during the busy season.\n\nA quick win you can apply now: create 1–2 branded addresses for key roles (shop and orders) and attach a consistent signature with your logo, contact info, and a short seasonal note. This makes every customer touchpoint feel like one brand, from order confirmations to support replies.\n\nIf this is of interest, I’m offering the first 3 months for £1 a month with code 1EMAIL. No heavy commitment—just a straightforward setup and a simple guide to keep your emails consistent during peak season.\n\nIf you’d like, I can do a 15-minute audit to show exactly how branded emails could look for your orders and customer inquiries. Reply with a good time and I’ll send a calendar link.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
234	34	25	sent	2025-08-24 20:57:15.78522	0	0	d1985430-04b9-4ef3-9877-f070efb15719	2025-08-24 21:08:14.852598	A simple branded-email win for Poppies	Hi there,\n\nFollowing up on my previous emails about branded domain email for Poppies Florist Bournemouth, I wanted to offer a practical angle that can help your day-to-day.\n\nA branded email address (for example, orders@poppiesfloristbournemouth.co.uk) signals reliability, helps customers recognize messages, and can improve deliverability since it sits on your own domain. A simple way to start is a phased setup: add one primary inbox for orders or inquiries, keep your current mail running, and gradually migrate remaining addresses as you confirm templates and signatures.\n\nIf you’d like, I can send a quick 5-point checklist to keep this low-friction and ensure branding is consistent across orders, deliveries, and marketing.\n\nAs a small gesture, we’re offering the first 3 months at £1 per month with code 1EMAIL.\n\nWould you be open to a 15-minute chat this week?\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
286	72	32	sent	2025-08-27 12:27:00.065711	0	0	6289e194-c82f-4e67-8da8-b91bad3bec63	2025-08-27 12:43:16.76107	A fresh onboarding idea for SNL Fitness	Hi there,\n\nThis is my final note in this sequence. I want to share a practical onboarding approach that fits into SNL Fitness’ client journey and can be rolled out this month.\n\nProposed: a simple 3-part onboarding email sequence that sets expectations, signals progress, and invites the first workout plan. Email 1: Welcome + milestones for two weeks; Email 2: Quick wins + a lean plan; Email 3: Book the first assessment and agree on cadence. I’ll tailor the copy to SNL Fitness’ voice and pair it with a lightweight tracking sheet to monitor opens, replies, and engagement.\n\nTo remove hesitation, we’re offering a no commitment 1 month complimentary trial of a branded onboarding kit and the first three onboarding emails for your team to test with current clients. If this resonates, I can customize further and pilot with a small group.\n\nWould you have 20 minutes to review a draft and share any tweaks?\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
235	37	25	sent	2025-08-24 20:57:15.78522	0	0	09a3b6f1-edf0-4151-ac9a-7175be8d8e7c	2025-08-24 21:10:38.337746	A practical step for Blushing Bloom	Hi there,\n\nFollowing up on my earlier notes about branded domain emails for Blushing Bloom and OceanFlora, I wanted to share a simple, practical step you can start implementing this week that often delivers tangible results quickly.\n\n1) Pick a primary branded address (hello@blushingbloom.co.uk or inquiries@blushingbloom.co.uk) and ensure all customer-facing emails come from it.\n2) Add SPF and DKIM records to your domain to improve deliverability and prevent spoofing; set a DMARC policy to monitor.\n3) Run a quick 1-week test: send to 5–10 customers and check open rates and replies; ensure replies go to a team inbox.\n\nThis small change can boost trust, improve brand recognition, and potentially lift reply rates from inquiries and orders.\n\nTo help you test-drive the change, We Get You Online is offering the first 3 months at £1/month with code 1EMAIL.\n\nIf you'd like, we can draft a 15-minute plan tailored to your current provider and timeline.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
236	35	25	sent	2025-08-24 20:57:15.78522	0	0	6fea9d65-b21d-449e-90d5-7a67671373cb	2025-08-24 21:13:00.640579	A simple upgrade for Little & Bloom	Hi there,\n\nFollowing up on Email #3, I wanted to share a small, practical move that can start paying off quickly: adopting a domain-branded email for Little & Bloom. A professional address like hello@littleandbloom.com signals trust and makes inquiries feel more credible—especially when customers are choosing a florist online.\n\nTip: pair it with a concise signature and a 1-2 sentence auto-reply that confirms receipt and sets expectations for response time. Then add a short welcome email for new inquiries that highlights your signature styles, delivery areas, and care tips.\n\nIf you’re short on time, I can set up a simple 3-email starter sequence and connect it to your site, ready to go in under a week.\n\nAs a welcome bonus, we’re offering the first 3 months for £1 a month using code 1EMAIL. No long-term commitment—just a chance to test the impact.\n\nWould you be open to a quick 15-minute chat to tailor this to Little & Bloom’s goals?\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
237	40	25	sent	2025-08-24 21:18:27.245838	0	0	250c16a4-4008-4fda-b0b7-86f883c3e561	2025-08-24 21:18:44.254699	Branded email for Lullabelles	Hi there,\n\nFollowing up on my earlier notes about a branded domain email for Lullabelles Floristry, I wanted to share a quick, practical plan that fits a busy floristry workflow.\n\n- Create a dedicated inbox on lullabellesfloristry.me (for example hello@lullabellesfloristry.me) to handle inquiries, orders, and bookings.\n- Use the same domain across your website and social profiles to build immediate trust with clients.\n- Set a simple auto-reply and a short follow-up email that includes a link to your portfolio or a featured bouquet to drive engagement.\n\nThis approach helps you respond faster, look more professional, and capture more orders without huge setup. To make it even easier, we’re offering the first 3 months for £1 per month with code 1EMAIL.\n\nIf you’d like, I can send a 1-page setup checklist or jump on a quick 15-minute call to tailor this to your operations.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
238	38	25	sent	2025-08-24 21:18:27.245838	1	0	daf7b913-9fd0-416e-ac4b-d02a10e004c6	2025-08-24 21:20:03.70327	Final idea to boost Full Bloom Hayling emails	Hi there,\n\nFollowing up on my earlier notes about a branded domain email for Full Bloom Hayling, I want to share a simple plan you can test this week that prioritizes your brand and customer experience.\n\nStep 1: Create 2–3 core templates (welcome, order confirmation, seasonal promo) that carry your brand voice and from name as Full Bloom Hayling. Consistency here builds trust.\n\nStep 2: Use a branded address (for example hello@fullbloomhayling.co.uk) rather than a generic inbox to improve deliverability and recognition.\n\nStep 3: Set up light automation: welcome emails within 24 hours of signup, a thoughtful post-purchase thank-you, and a gentle follow-up with related bouquets in the next month.\n\nAim for measurable results: open rates in the 25–35% range for welcome emails, and a few more clicks on promotions.\n\nTo help you get started, we’re offering the first 3 months for £1 a month using code 1EMAIL.\n\nIf you’d like, I can draft the first templates for you and outline a quick 1-page setup plan.\n\nBest regards,\nRyan\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
239	23	25	sent	2025-08-24 21:25:35.985051	0	0	7c912161-3e62-4e3f-aebd-ad7d5c96a905	2025-08-24 21:26:19.991367	Boost trust with a personalised domain email	Hi there,\n\nFollowing up on my earlier notes about a personalised domain email for The Flower Shop Beeston, I wanted to share a few concrete steps you can take this week to boost inquiries and trust.\n\n- Use a branded inbox for main customer emails (for example hello@theflowershopbeeston.co.uk) and dedicated addresses for orders and support.\n- Display the branded address on your website, signage, and social profiles to make it clear where messages land.\n- Tidy up signatures with your shop name, contact number, and postcode so every reply reinforces your local presence.\n\nIf you’d like a simple start, we’re offering the first 3 months for £1 a month using code 1EMAIL. I’m happy to draft a quick setup plan tailored to your site and send a visual of what the inbox will look like in your branding.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
240	22	25	sent	2025-08-24 21:25:35.985051	0	0	7976bb41-180c-4209-9003-bf424df43011	2025-08-24 21:28:07.757358	Brand your emails — £1/mo for 3 months	Hi there,\n\nI’m following up on my earlier notes about using a branded domain email to boost Melbourne Florist and Gifts’ online presence. Since you’re in the florist space, I know how essential trust and reliability are—customers want to see order confirmations and gift offers from a brand they recognize. A branded domain email (for example hello@melbourneflorist.co.uk) improves inbox delivery, strengthens trust, and makes your promos feel consistent across your site and social.\n\nTo keep things simple, here’s a quick-start plan:\n- Set up a branded email aligned with melbourneflorist.co.uk and connect it to your existing systems (orders, support).\n- Update signature blocks and auto-responses to reflect your tone and offerings.\n- Start with one or two customer touchpoints (order confirmations, delivery notifications) and measure open and response rates.\n\nAs a final note, we’re offering the first 3 months at £1 per month with code 1EMAIL. If you’d like, I can map a 15-minute plan tailored to Melbourne Florist and Gifts.\n\nCheers,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
241	47	25	sent	2025-08-24 21:25:35.985051	0	0	7caff691-7500-45a4-8a94-e8c369344511	2025-08-24 21:30:07.510497	A practical next step for Fleurtations	Hi there,\n\nFollowing my earlier notes about a domain-branded email for Fleurtations Florist Bristol, I wanted to share a couple of practical, low-effort ideas that can boost trust and response rates.\n\nTips you can act on this week:\n- Use a domain-branded contact email (for example hello@fleurtations-bristol.co.uk) with a clean signature and a direct booking link.\n- Add a brief auto-reply that confirms receipt and lists the next steps (availability, deliveries, quotes).\n- Update the contact page with a simple form and a clear hours line to reduce back-and-forth.\n\nIf you’d like, I can handle the setup. The first 3 months are £1 a month with code 1EMAIL, making it easy to try.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
242	45	25	sent	2025-08-24 21:25:35.985051	0	0	7f22cfca-ec29-4782-bbcf-4adef3d97d15	2025-08-24 21:32:49.584318	Quick follow-up for The Flower Shop	Hi there,\n\nI’ve been thinking about how The Flower Shop Bristol can stand out in the inbox. Building on my previous notes about branding emails with a custom domain and the practical ideas from Email #3, here are a few quick, practical steps that can move the needle this season.\n\n- Use a branded domain for all customer messages (orders, promos, newsletters) to boost trust and deliverability.\n- Align email visuals with your shop’s style—soft florals, clear pricing, and one strong CTA for delivery or pickup.\n- Run tiny, targeted campaigns: seasonal bouquets, care tips, and a simple same-day delivery reminder.\n\nTo help you test this fast, we’re offering the first 3 months for £1 a month with code 1EMAIL. If you’d like, I can do a 15-minute email audit and outline 3 concrete changes that could lift opens and bookings.\n\nWould you be open to a quick chat this week to explore options?\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
243	44	25	sent	2025-08-24 21:25:35.985051	0	0	09c1ceb5-5d35-4d1d-b04e-c31d13fe6ec1	2025-08-24 21:34:33.793763	A simple email upgrade for Lily Violet May	Hi there,\n\nFollowing up on my earlier messages about a branded email domain for Lily Violet May Florist, I wanted to share a practical plan that won’t disrupt your day-to-day operations but can make a real difference online.\n\nWhy it helps: a consistent, branded email address (like you@lilyvioletmay.co.uk) boosts trust with customers and improves deliverability, so more order confirmations and care tips reach inboxes.\n\nLow-friction steps you can take this week:\n- secure a branded domain and set SPF/DKIM to protect your messages\n- create a simple templates kit for order confirmations, delivery updates, and post-purchase tips\n- run a small “brand aware” campaign to welcome new subscribers and remind customers of seasonal bouquets\n\nThe impact can be measured by open rates, click-throughs on offers, and a steady reduction in undelivered messages. To help you test without risk, we’re offering the first 3 months at £1 per month with code 1EMAIL.\n\nIf you’d like, we can jump on a quick 15-minute call to map your current emails and outline a minimal setup.\n\nWarm regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
244	46	25	sent	2025-08-24 21:25:35.985051	0	0	01472122-a5b4-47ff-8f91-78faf7c329b3	2025-08-24 21:36:51.571149	Final follow-up: boost Tiger Lily online	Hi there,\n\nI hope you're well. Following up on my earlier notes about boosting Tiger Lily’s online presence with a professional domain email, and the practical plan I shared, I’ve outlined a quick, low-friction pilot you can implement in a week.\n\n- Set up 2-3 branded email addresses (hello@, orders@, team@) that match tigerlilyflowers.co.uk and route to your current inbox.\n- Create a simple 3-part welcome/order email series to reassure customers, share care tips, and prompt a review after delivery.\n- Align your email signature and a small banner with Tiger Lily branding to improve recognition in every message.\n\nMeasure success with a few metrics: response rate, delivery rate, and open rate on the welcome series.\n\nTo make it easy, you can try the first 3 months for £1 per month using code 1EMAIL.\n\nIf this sounds useful, I can jump on a quick 15-minute call to tailor the setup to your workflow and calendar.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
245	21	25	sent	2025-08-24 21:25:35.985051	0	0	0422d4f3-2710-49f5-b6b2-ff8ea11d66fe	2025-08-24 21:39:10.699949	Boost Fleur Florists with domain email	Hi there,\n\nFollowing my earlier notes about domain-branded email and strengthening Fleur Florists' online identity, I wanted to share a quick, low-friction win you can act on today. Setting up a professional domain email (for example hello@fleurfloristbelper.co.uk) and aligning it with SPF and DKIM improves deliverability and trust with customers.\n\nA simple path to start:\n- Create a couple of branded inboxes (info@, bookings@, hello@) to keep inquiries organized.\n- Use your domain in every customer touchpoint — from receipts to replies — for consistency.\n- Add a short, friendly auto-reply to confirm receipt of orders and bookings, plus a clear next-step.\n\nIf you’d like, I can handle the setup end-to-end so you can focus on the blooms. And to make it easy to test, we’re offering the first 3 months for £1 a month using code 1EMAIL.\n\nReply with “Setup” and I’ll arrange a quick 15-minute call to tailor this to Fleur Florists.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
246	50	25	sent	2025-08-25 00:04:25.324411	0	0	40943a26-27fc-41f1-8125-7895ed352949	2025-08-25 00:04:36.330814	A small branded boost for Don Gay’s Florist	Hi there,\n\nI wanted to follow up on my previous notes about a domain-branded email for Don Gay’s Florist Bristol and the branding tweaks I mentioned for your site. Your floral work remains standout, and a simple email-branding upgrade can reinforce that impression every time a customer reaches out or browses online.\n\nTwo quick ideas to add value today:\n- Use an email address that matches your domain (for example hello@dongaysflorist.co.uk) and a consistent signature. This builds trust, improves deliverability, and makes it easy for customers to contact you.\n- Align your homepage and contact pages with a single clear call to action, like “Order flowers online,” so new visitors can convert with little friction.\n\nTo make trying this easy, We Get You Online is offering the first 3 months for £1 a month using code 1EMAIL. It’s a low-risk way to test the impact on inquiries and orders.\n\nIf you’d like, I can set up a quick pilot: branded email + starter templates for reply and signature.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
247	49	25	sent	2025-08-25 00:04:25.324411	0	0	1dece249-5710-4af1-9d0f-df4b331ae020	2025-08-25 00:05:58.880542	Boost trust with a domain email	Hi there,\n\nFollowing up on my notes about domain-branded emails for Edith Wilmot Bristol Florist, I know you’re busy. Here’s a simple, low-friction plan you can try this week to boost trust and speed up replies:\n\n- Set up a primary domain inbox, such as hello@edithwilmot.co.uk, and reference it across your site, Google listing, and social profiles.\n- Create a couple of role addresses (enquiries@, orders@) that forward to the right person while keeping branding consistent.\n- Update contact forms and signature blocks on your site to use the new address, and run a quick inbox test to ensure messages land in inboxes (not spam).\n\nIf you’d like, I can draft a starter setup and two ready-to-use reply templates tailored to your floristry. The aim is to keep conversations clear and professional, from first inquiry to order follow-up.\n\nWe’re offering the first 3 months for £1 a month using code 1EMAIL.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
248	48	25	sent	2025-08-25 00:04:25.324411	0	0	d6cc7eeb-ac04-4f48-a73b-4f4e99061ef9	2025-08-25 00:07:48.526016	A practical next step for Flowers By Alla	Hi there,\n\nFollowing my earlier notes on branded domain emails, I wanted to share a quick, finish-this-week win you can act on without changing everything at once.\n\nWhy it matters: a consistent domain (e.g., hello@flowersbyalla.com) strengthens trust, improves deliverability, and makes orders and inquiries look more professional—key for a busy florist with a personal touch.\n\nHere's a simple 3-step path you can implement this week:\n1) Create a branded email (hello@flowersbyalla.com) and set it as your primary contact.\n2) Update your signature to include the site URL and a courteous CTA (e.g., “View latest arrangements”).\n3) Set up a basic automated welcome/thank-you email to new inquiries or orders that reinforces your brand and invites a follow-up.\n\nIf you want to test the impact with minimal risk, We Get You Online is offering the first 3 months at £1 per month when you use code 1EMAIL.\n\nIf helpful, I can share a ready-to-use draft for your welcome email or guide you through the setup in 15 minutes—just reply with what would be useful.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
249	85	35	sent	2025-08-25 12:15:35.280366	0	0	25f50cd0-c951-4100-b8d7-1cd3c409b1f3	2025-08-25 12:15:44.287686	A few ideas for 75Hudson Photography	Hi there,\n\nFollowing up on my last note about We Get You Online and 75Hudson Photography, I took another look at your site and your storytelling approach. I wanted to share a few practical tweaks that can improve client experience and bookings without overhauling what you already do well.\n\n- Clarify your homepage value: a concise hero statement paired with a signature image so visitors immediately grasp what makes 75Hudson different.\n- Organize the portfolio by mood or occasion (elopements, family, portraits) to guide clients to the stories most relevant to them.\n- Simplify the inquiry-to-booking path: a short form that captures location, vibe, date, and deliverables, plus an onboarding email that sets expectations early.\n- Elevate search discoverability: add descriptive captions with location keywords to your images.\n- Bridge social and site: a couple of posts that invite followers back to the site for the full story.\n\nIf any of these feel like a good fit, I’d love to do a quick 15-minute walk-through to tailor them to your brand. When would you have 15 minutes this week or next?\n\nBest,\nRyan\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
250	86	35	sent	2025-08-25 12:15:35.280366	0	0	3616c238-7ac8-4686-b86e-459f72816c11	2025-08-25 12:16:49.554961	A simple trust boost for Memory Box Weddings	Hi there,\n\nFollowing up on my earlier note about boosting client trust with a branded email, I took another look at how Memory Box Weddings could turn inquiries into confident bookings. A few practical tweaks can make a big difference without slowing you down.\n\n- Start every reply with a clean, branded template that mirrors your site colors and logo and includes a brief value statement. It signals consistency and care from the first moment.\n\n- Share a clear next-step and proof: include a link to a recent film-style gallery or testimonial, and a concise 48-hour response promise. Clients feel guided and respected when they know what to expect.\n\n- Offer a simple, bite-sized process timeline in the email: initial inquiry → booking proposal → shoot day → gallery delivery. A short map reduces ambiguity and builds trust.\n\nIf you’d like, I can map a quick 3-email sequence tailored to Memory Box Weddings in about 15 minutes, designed to boost reply rates and bookings while staying true to your brand.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
251	84	35	sent	2025-08-25 12:15:35.280366	0	0	e4078066-90c2-4a07-87e7-9e325d9e1c40	2025-08-25 12:18:32.578767	A fresh angle for Elen Studio Photography	Hi there,\n\nFollowing up on my note about Elen Studio Photography’s storytelling and the warmth of natural light, here are two quick ideas to try this month to attract clients who value those moments.\n\nTwo fast wins:\n- Portfolio structure: a “Moments that matter” gallery with small storylines (engagement, candid couple moments, detail shots) to help visitors picture themselves in your work.\n- Social proof on the homepage: a short client quote next to a standout image to build trust fast.\n\nAlso consider a simple UX nudge:\n- A prominent contact CTA on every page and a short 60-second form to capture date range and preferred collection, reducing friction.\n\nIf you’d be open to it, I can also review your site performance data and propose 2–3 micro-optimizations that fit your workflow.\n\nIf you’d like, I can deliver a 1-page quick-win plan tailored to your site and goals. No obligation—just practical ideas to test.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
252	87	35	sent	2025-08-25 12:15:35.280366	0	0	f4341e44-a25b-4b61-a450-58b1ee2aacf9	2025-08-25 12:20:36.402318	Simple updates for Lovell Photography	Hi there,\n\nFollowing up on my note about domain email for Lovell Photography, I wanted to share two practical tweaks that can impact inquiries and bookings.\n\nFirst, using a domain-based contact address (for example, contact@lovellpictures.com) signals professionalism and consolidates messages in one mailbox. If you’d like, I can outline a simple migration and routing plan you can implement in a few hours without downtime.\n\nSecond, a small site refinement can pay off: place a clear "Book a shoot" CTA above the fold and pair it with a concise contact section. Pair that with alt text and meta descriptions that reflect what clients search when choosing a photographer. A lean, fast site reduces friction and boosts inquiry conversion.\n\nIf you’re open to it, I can run a quick audit of your current setup and share a step-by-step plan tailored to Lovell Photography. It’s actionable guidance you can try this week.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
284	71	32	sent	2025-08-27 12:27:00.065711	1	0	5c03d457-1223-4a5c-9863-87dc4686c191	2025-08-27 12:38:28.320359	One last idea for FJK Fitness	Hi there,\n\nI know your time is valuable, and this is our final note about helping FJK Fitness build trust with a branded email. Since my previous messages, I’ve seen trainers gain measurable gains from a small, consistent branded touch that feels personal and professional.\n\nHere are quick actions you can implement this week:\n\n- Use a branded inbox address (for example, info@fjkfitness.co.uk) and align your signature with your site: your name, title, phone, and a link to your services.\n\n- Create a simple welcome/consultation email: when a new inquiry comes in, reply with your core value proposition, a clarifying question, and a clear next step to book a quick chat.\n\n- Include one trust cue in replies: a short client testimonial or a note about results you typically achieve.\n\nTo make this easy, I’m offering a no-commitment, 1-month complimentary trial of our branded email setup on your domain. If you’d like, I’ll handle the setup and provide ready-to-use templates.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
253	91	35	sent	2025-08-25 12:15:35.280366	0	0	68ea8df7-ff4d-4d52-961f-92179c6af5c3	2025-08-25 12:23:18.984354	A fresh angle for Mustard Fox Photography	Hi there,\n\nFollowing up on my note about trust-building through storytelling, I revisited Mustard Fox Photography and your site. Your knack for capturing candid, heartfelt moments clearly sets you apart in a crowded field. A few practical tweaks can help visitors see themselves in your work within seconds and feel confident reaching out.\n\nThree quick wins to test this week:\n- Clarify the hero with a concise line such as: “We craft portraits that tell your story, fearlessly and beautifully.”\n- Add a simple 3-step client journey on the homepage: Inquiry → Shoot Day → Deliverables.\n- Include a short FAQ addressing booking steps, locations, deliverables, and timelines to reduce back-and-forth.\n- Place a clear “Book a chat” CTA above the fold to invite inquiry without friction.\n\nIf you’re open, I can share a brief 60-minute audit outline and a practical implementation checklist tailored to your site and socials. This is about clarity and flow that supports your storytelling—and more inquiries that feel right from the first moment.\n\nHappy to tailor these ideas to weddings, families, or portraits specifically.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
255	90	35	sent	2025-08-25 12:15:35.280366	0	0	2904a9ae-e572-4743-8f70-2dce6384a59d	2025-08-25 12:27:10.464466	A quick follow-up for Front Row Cardiff	Hi there,\n\nFollowing up on my note about a trusted touch for Front Row Photography Cardiff, I wanted to share a few practical moves you can test quickly to turn more site visitors into clients.\n\n- Clarify your value on the homepage: a single line that states who you serve, what you deliver, and a clear “Book a session” button. A strong hero can lift inquiries.\n- Simplify the inquiry path: a short form (name, email, event date, location) plus an auto-reply. Less friction = more completed inquiries.\n- Add social proof: 2-3 testimonials or a concise “Story Gallery” featuring recent weddings/portraits with client quotes.\n- Local focus: ensure Cardiff is included in page titles and image alt text; consider a dedicated “Weddings in Cardiff” portfolio page to capture local search.\n\nIf any of these ideas feel useful, I can draft copy or a quick 2-week test plan to implement with minimal setup.\n\nWarm regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
256	83	35	sent	2025-08-25 12:15:35.280366	0	0	481dc711-785b-4a01-85a2-a9decb94b602	2025-08-25 12:29:41.354686	Helpful follow-up for Gem Photography	Hi there,\n\nI wanted to follow up on my note about Gem Photography. The timeless, warm storytelling in your portfolio stands out, and I understand that many clients choose a photographer as much for trust as for technique.\n\nHere are a few quick, practical ideas that can help attract more inquiries without adding work:\n\n- Speed and mobile: optimize hero images, enable lazy loading for galleries, and keep the critical path lean so visitors see your work fast on mobile.\n\n- Portfolio structure: organize galleries into clear categories (Weddings, Portraits, Families) and pair each with a short client note or testimonial. A behind-the-scenes line can reinforce the connection you build with clients.\n\n- Simple lead capture: a single, easy inquiry form on every page and a straightforward next step (e.g., book a 15-minute call). A prompt reply in 24 hours can dramatically improve conversion.\n\nIf it would be useful, I can prepare a quick 60-minute audit focused on Gem Photography's top pages and ideas you can implement this month. Happy to tailor it to your schedule.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
257	89	35	sent	2025-08-25 12:15:35.280366	0	0	d388c185-0b12-42df-89c2-b83ab1180de3	2025-08-25 12:31:43.40408	A quick idea to boost Balance's trust	Hi there,\n\nFollowing up on my note about Balance Photography Studio and your emphasis on natural light and genuine moments, here are three quick, low-effort ideas you could test this quarter without adding workload.\n\n- A “Behind the Shoot” snippet in your portfolio: one standout natural-light image paired with a short caption about how you help clients feel at ease.\n- A couple of client quotes on the About or Portfolio pages to reinforce trust.\n- A concise 60-second intro video or captioned slide show that clearly states your value: balanced storytelling, authentic moments, unobtrusive direction.\n\nIf you’d prefer, I can tailor these ideas to a particular portfolio shot or client type you want to attract. If any resonate, I can draft a simple 1-page plan with copy and image prompts you could share with a designer. Happy to tailor to Balance’s style and audience.\n\nThanks for your time. I’m here if you’d like to discuss.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
258	100	35	sent	2025-08-25 12:37:13.097528	0	0	7fff0fc6-b4fb-42c9-8fbd-301e3d6196ad	2025-08-25 12:37:22.104366	Quick ideas for Marek Bomba Photography	Hi Marek,\n\nFollowing up on my previous note about elevating client trust, I revisited mbomba.com. Your portfolio captures those quiet, authentic moments beautifully. To convert more visitors into inquiries, here are a few quick, practical tweaks you could implement in a week:\n\n- Add a “What to expect” section on the homepage outlining 4 steps from inquiry to final delivery. Clarity here reduces hesitation and speeds decision-making.\n- Spotlight client stories or testimonials near the portfolio, with a brief note on the project type (wedding, portrait, branding). Real quotes boost credibility.\n- Create a simple “Process & Packages” page or a clear packages section so buyers understand options without needing a call first.\n- Improve mobile load times and add alt text to images to aid SEO and accessibility.\n\nIf helpful, I can prepare a 1-page mockup or run a quick 15-minute review to tailor these ideas to Marek Bomba Photography. Happy to help you implement the ones that fit your style.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
259	99	35	sent	2025-08-25 12:37:13.097528	0	0	672ff0f7-3139-4d61-997d-a7b5b87695b3	2025-08-25 12:39:00.038425	A fresh angle for Harvey Mills Photography	Hi Harvey,\n\nSince my last note, I revisited Harvey Mills Photography and your portfolio still resonates with clean, timeless storytelling. Photographers like you are trusted with meaningful moments, and a thoughtful email approach can help you connect with more clients who value that craft.\n\nTwo quick, low-friction ideas to try this month:\n\n- Add a simple “Inquire” CTA on the homepage that links to a short form and a sample client story. A clear path from first glance to inquiry usually lifts qualified leads without changing your site’s look.\n\n- Create a light 3-email post-inquiry sequence: (1) thank-you with a featured story, (2) a short testimonial and package options, (3) a calendar link or booking note. It keeps momentum without feeling pushy.\n\nIf helpful, I can put together a concise implementation plan or run a 15-minute audit of your site and emails to align with your storytelling. Happy to chat this week if you’re open to it.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
260	94	35	sent	2025-08-25 12:37:13.097528	0	0	5f1b8c0a-d9f7-4fd9-b6d1-23e1b2bab152	2025-08-25 12:40:39.78181	Branding tweaks for Gemma Poyzer Photography	Hi Gemma,\n\nFollowing up on my note about building trust through branding, I revisited gemmapoyzer.co.uk and your work. Your storytelling shines—moments of joy, calm, and connection—and a few small tweaks could help visitors feel that instantly.\n\nThree quick ideas you could test:\n- Above-the-fold clarity: a single line that states who you serve and the feeling you deliver (e.g., “Photographs that capture your family’s everyday magic”).\n- Simple inquiry path: make the contact/booking option easy to find on mobile with one tap.\n- Relevant social proof: add a short client story or testimonial near a standout image to highlight real outcomes.\n\nIf you’d like, I can share a compact branding snapshot for photographers—about a 10-point checklist you can apply to your site and socials. No obligation, just practical, refreshable ideas you can act on this quarter.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
261	96	35	sent	2025-08-25 12:37:13.097528	0	0	71f7e682-cb61-44d0-88fe-f89cbff9335f	2025-08-25 12:42:18.537632	A quick idea for Alex Mills Photographic	Hi Alex,\n\nFollowing up on my last note about how your storytelling and client experience stand out, I took another look at alexmillsphotographic.com. I found a simple, practical way to convert more visitors into inquiries without changing your vibe.\n\n- Add a brief “Your Experience” gallery with 3–4 projects and a short caption about the client moment and outcome.\n- Place a clear contact CTA on the homepage and after each gallery—something like “Tell me about your moment” with a lightweight form or calendar link.\n- Surface 2–3 strong testimonials near the contact area and link to a concise case study that demonstrates results.\n\nThese tweaks are designed to fit your brand and can be implemented in a few days. They reinforce your storytelling, feel authentic, and help turn thoughtful browsers into inquiries without feeling salesy.\n\nIf you’re open, I can do a quick 15-minute site-first audit to identify these quick wins tailored to your audience, plus a simple 60-day plan to lift inquiries.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
262	92	35	sent	2025-08-25 12:37:13.097528	0	0	705196ad-582f-4e64-a7fd-95cd11e2b6b1	2025-08-25 12:44:32.698666	Clive, quick branding tweaks	Hi Clive,\n\nFollowing up on my note about boosting client trust with a branded email, I’ve taken a closer look at how Clive Stapleton Photography communicates online. Your portfolio already conveys warmth and a timeless feel—perfect foundations for guiding clients through the booking journey.\n\nHere are a few quick, practical moves you can try this week:\n\n- Brand consistency in every reply: add a concise tagline under your logo in emails and use a clean, uniform signature with your website. Example tagline: “Timeless, natural moments.” Include a direct link to your latest gallery.\n\n- Efficient inquiry-to-booking flow: send a short 2-step reply—1) warm acknowledgment and a link to 3-4 standout shoots, 2) a simple calendar snapshot with available dates and next steps.\n\n- Social proof and storytelling: include one client quote or a link to a short story near the end of inquiry emails to reinforce trust.\n\nIf you’d like, I can draft 2-3 ready-to-send templates tailored to Clive Stapleton Photography in under 15 minutes.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
263	93	35	sent	2025-08-25 12:37:13.097528	0	0	66c1f874-fe51-4ff7-81a6-49bfbb270c40	2025-08-25 12:46:42.166303	Kamila, a quick branding boost	Hi Kamila,\n\nFollowing up on my note about boosting trust with branded email, I revisited Kamila Malitka Photography. Your portfolio radiates warmth and authentic connection—great foundation for branded client communications.\n\nHere are three quick, easy tweaks you can implement this week to turn inquiries into bookings, without changing your voice:\n\n- Use a short, branded inquiry reply (about 4 sentences) that previews your process. Example: "Thanks for reaching out to Kamila Malitka Photography. Your session will feel relaxed and natural, with a focus on candid moments in warm light. Next steps: share your preferred date, review my packages here: https://kamilamalitkaphotography.com/ and we’ll schedule a quick call if you’d like to chat."\n\n- Include a single client line in replies to pre-build trust (e.g., "Clients say sessions feel effortless and joyful").\n\n- Standardize your signature to include your business name and a direct link to your portfolio and contact.\n\nIf you’d like, I can tailor a ready-to-paste template and a short 3-email nurture sequence for inquiries—delivered in about 15 minutes.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
264	95	35	sent	2025-08-25 12:37:13.097528	0	0	cb227895-5751-4a08-b62b-404670c1f052	2025-08-25 12:49:19.647713	A practical idea for Ryan Hall Studios	Hi Ryan,\n\nFollowing up on my note about Ryan Hall Studios' beauty product and personal branding photography, I wanted to share a practical angle you could test in the next quarter.\n\nPortfolio clarity: group work into three pillars—Beauty Product Details, Brand Stories, and Personal Branding. For each project, add a concise problem statement, your approach, and the outcome. This helps potential clients quickly evaluate fit and ROI.\n\nContent rhythm: commit to four short behind-the-scenes reels or carousel posts per month that show lighting, styling, and retouch. A steady cadence builds familiarity and trust with brands looking for consistent results.\n\nCase studies: add one or two lightweight pages that outline the client goal, how your photography solved it, and any measurable impact on launch speed or engagement. I can draft a simple template if helpful.\n\nOn-site optimization: refresh image metadata and alt text with keywords like beauty product photography, personal branding photography, and your location to improve discoverability.\n\nIf any of this resonates, I’d be happy to outline a tailored 1-page plan or share a sample outline.\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
287	66	32	sent	2025-08-27 12:48:47.335385	0	0	fe26cbb4-077f-49fd-9bc7-2b1059fd7890	2025-08-27 12:49:09.341631	Branding win for ZiaFitLife—trial offer	Hi Anastazia,\n\nFollowing my earlier notes about branded emails to deepen trust (Email #1) and the onboarding ideas I mentioned (Email #2), I’d like to offer a low-risk way to test the impact for ZiaFitLife.\n\nI’m proposing a no-commitment 1-month complimentary trial of a branded email kit and onboarding flow tailored to your coaching style. It includes:\n- A cohesive welcome/onboarding sequence (3 emails) that clearly outlines goals, next steps, and how you measure progress.\n- Automated weekly check-ins and progress updates that feel personal, not generic.\n- A branded email template set (header, signature, CTAs) to boost recognition and trust.\n\nThree quick wins you can implement today: \n1) Personalize onboarding by prompting clients to share their top goals within the first 48 hours. \n2) Add a short progress update after week 1 with one tangible result. \n3) Use consistent branding to reinforce credibility across touchpoints.\n\nIf you’re open, we can start the trial this month. If not, I’m glad to tailor or skip.\n\nWarmly,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
265	98	35	sent	2025-08-25 12:37:13.097528	0	0	997eba3c-6625-4d1c-b17e-75142d496ad7	2025-08-25 12:52:10.533501	Branding tips for Marie Carden Photography	Hi Marie,\n\nFollowing up on my note about Marie Carden Photography, I took another look at your site and wanted to offer a few practical tweaks that can help convert more inquiries without changing your photography style.\n\nThree quick, doable improvements you can tackle this week:\n- Lead with a clear value statement in the hero: use a short line like "Authentic, naturally lit portraits that tell your story," followed by a simple CTA such as "View portfolios." This reduces guesswork for first-time visitors.\n- Tidy the portfolio flow: arrange galleries to reflect the client journey (e.g., engagement, family, portrait sessions) with concise captions that highlight the emotion you capture and the outcome clients feel.\n- Add social proof near the contact area: include 2–3 brief testimonials and ensure the contact/booking CTA is easy to find. Pair a testimonial with a photo where possible to boost credibility.\n\nIf you’d like, I can map these into a one-page plan tailored to your current site and audience, plus provide a draft hero line you can test.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
266	97	35	sent	2025-08-25 12:37:13.097528	0	0	02ec9ae8-5d87-4a66-90d1-3bc797eff32b	2025-08-25 12:55:15.888475	Follow-up: Branding for Kate Davey Photography	Hi Kate,\n\nI took another look at Kate Davey Photography and your portfolio—your ability to capture genuine moments with warmth is compelling. I wanted to share a small, practical tweak that could help convert browsers into bookings without a full revamp.\n\n1) Clarify your core offer on the homepage: in one line, what makes a session with you unique? For example: "Authentic portraits that feel like a trusted conversation." Place this near the hero so first-time visitors get your value instantly.\n\n2) Add a client story section: a short before/after or a testimonial that highlights trust and natural light. Real words from clients go a long way.\n\n3) Short, branded inquiry flow: a single-step form or a prominent "Check availability" button that links to a simple calendar or intake form. A clean, consistent look signals professionalism.\n\nIf helpful, I can perform a quick 15-minute brand touchpoint audit and share three tailored improvements—no obligation. I’m glad to chat about how We Get You Online could support a lightweight, branded email and landing page setup that fits your pace.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
288	80	32	sent	2025-08-27 12:48:47.335385	0	0	c7326d17-62af-42f7-91bd-7f2aaf40dbf8	2025-08-27 12:51:07.565598	Fresh ideas to boost trust at Dedicated Coaching	Hi Lee,\n\nI know your time is precious, so I’ll keep this concise. Following up on my earlier notes about boosting client trust with branded emails, and the quick steps from Email #2, I wanted to offer a fresh angle you can test this month.\n\nInstead of only onboarding flows, try mapping the client journey and aligning messaging with outcomes that matter to busy clients: consistent training, tangible progress, and real, shareable results.\n\nHere’s a simple 3-part approach you can implement this week:\n- Welcome & goal-setting email: one clear ask (share 2-3 goals and any injuries/constraints) plus a branded “plan at a glance” resource.\n- Weekly progress spotlight: a short template that celebrates a milestone, includes a simple progress metric, and invites a short testimonial after 4 weeks.\n- Month-end social-proof nudge: a concise case-study style highlight you can share on social and in emails.\n\nIf you’d like to test this with zero risk, I can set up a no-commitment 1-month complimentary trial of our branded onboarding and progress-update templates for Dedicated Coaching.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
289	61	32	sent	2025-08-27 12:48:47.335385	0	0	db039b08-6faa-4620-9118-19f156884002	2025-08-27 12:53:06.669341	Cordell: Try a 1-month branding trial	Hi Cordell,\n\nFollowing my notes from Email #1 about elevating client trust with branded email, and the quick branding tweaks from Email #2, I want to offer a concrete, low-risk way to test the impact on your client engagement.\n\nHere’s a no-commitment option: a 1-month complimentary branding trial for Cordell Wilson Personal Training. We’ll provide a ready-to-send branded email template tailored to your fitness audience, plus two follow-up templates aligned with your site messaging. Also included is a simple one-page guide on optimizing subject lines and CTAs to boost inquiries and class signups. You can keep or discard at the end of the month.\n\nTwo practical tweaks you can implement this week:\n- Add a brief client testimonial snippet with a headshot to your next email to build trust quickly.\n- Include a clear, one-click booking CTA in your email signature for convenience.\n\nIf this sounds helpful, reply yes and I’ll set it up. If not, this will be my final note and I won’t reach out again.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
269	108	35	sent	2025-08-25 13:00:43.580014	0	0	7d7742cb-f277-42bd-8e0f-fe0eb3fd0082	2025-08-25 13:04:55.538882	A fresh idea for Beau-Louise Photography	Hi Jane,\n\nFollowing up on my note about Beau-Louise Photography, I keep thinking about how your wedding and portrait work feels intimate and cinematic—it's exactly the kind of storytelling that converts browsers into clients when paired with a simple, clear path to booking.\n\nHere are a few quick, low-effort ideas you could test this month to drive leads without changing your style:\n\n- Refine a 'Love Stories' gallery: 3–5 case studies that spotlight real moments and quotes from couples. Short captions about the emotion you captured can deepen trust.\n\n- Add a lightweight lead magnet: a 4-page 'Couple's Guide to a Calm Wedding Day' downloadable in exchange for an email. This helps you build a qualified email list and creates a reason for couples to reach out.\n\n- Create a short 4-email welcome sequence: (1) your approach and what makes Beau-Louise unique, (2) BTS moments, (3) typical timelines & deliverables, (4) booking next steps.\n\nIf any of these resonate, I can draft a tailored plan for Beau-Louise in under an hour.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
274	102	35	sent	2025-08-25 13:00:43.580014	1	0	de787fec-602d-4ca4-95ee-7287dc8ce7cd	2025-08-25 13:16:51.181425	Next steps for Matt Gutteridge Photography	Hi Matt,\n\nFollowing up on my note about elevating trust with a branded email, I revisited Matt Gutteridge Photography and kept noticing how your genuine moments and calm storytelling create a strong trust baseline. A branded email system can protect that trust at every touchpoint—from inquiry to gallery delivery.\n\nHere's a practical 3-step plan you can start this week:\n\n- Brand-aligned templates: deploy one simple email template that uses your site colors, a clean typeface, and a short tagline like “capturing genuine moments with calm storytelling.” This consistency reduces friction for potential clients.\n\n- Quick inquiry intro: reply within 24 hours with a brief overview of your process, expected timeline, and what you need from them to begin (date, location, brief mood). A clear ask shortens cycles.\n\n- Post-inquiry journey: after you share a gallery link, follow with a personal note that references a specific moment in a photo and outlines next steps toward booking, contract, and deposit.\n\nIf you’d like, I can draft a ready-to-use branded email kit tailored to your site and images, plus a 5-minute branding audit checklist.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
272	105	35	sent	2025-08-25 13:00:43.580014	1	0	c4be94f3-1842-4002-8297-0a1cdcedc3c2	2025-08-25 13:11:32.189785	A quick idea to boost Roz Pike Photography	Hi Roz,\n\nFollowing up on my note about how Roz Pike Photography captures intimate wedding and portrait moments, I keep thinking about ways your site can convert more browsers into inquiries without a full redesign.\n\nHere are a few quick, practical tweaks that many photographers find impactful:\n\n- Clarify your value upfront on the homepage with a short headline next to your hero image (for example: Intimate weddings and family portraits told with warmth and calm). Pair it with a clear CTA like View my work or Check availability.\n\n- Simplify inquiries: add a 3-field form (date, location, approximate package) and an auto-reply that promises a response within 24 hours.\n\n- Use recent client stories: add 3 recent weddings to your portfolio with one-line captions that describe the vibe and location; feature a couple of short testimonials in a prominent sidebar.\n\nIf you’d like, I can do a quick 15-minute review of your Roz Pike Photography homepage and gallery to pinpoint the fastest wins.\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
270	106	35	sent	2025-08-25 13:00:43.580014	1	0	a31b3cfb-0f56-4f60-bb26-58a4565db182	2025-08-25 13:06:46.939998	Rosalyn: a fresh angle on client trust	Hi Rosalyn,\n\nI revisited Rosalyn Jay Photography after my last note about elevating client trust with email. Your emphasis on storytelling and natural light stands out, and small refinements to how inquiries are nurtured can convert that trust into bookings without adding complexity.\n\nThree quick ideas you can test this month:\n- Inquiry welcome: a one-page email that acknowledges the client’s story and outlines what happens next, with a link to a recent client story.\n- Pre-shoot prep guide: a concise PDF or page with what to bring, how you use natural light, and your typical timeline.\n- Social proof in flow: feature 2-3 recent testimonials on your contact page and weave a short testimonial into your follow-ups.\n\nIf you’d like, I can tailor a two-email sequence and a short page draft specifically for Rosalyn Jay Photography. I’m happy to share a draft when you’re ready.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
290	77	32	sent	2025-08-27 12:48:47.335385	0	0	962f6037-8c71-49eb-996a-b91e8c2f1beb	2025-08-27 12:54:34.148669	No-commitment 1-month branded email trial	Hi Jack,\n\nFollowing up on my notes about boosting client trust with a branded email and the quick plan I shared, I want to offer something tangible you can test this week—without risk.\n\nI’ve put together a ready-to-use branded email kit for Jack Williamson PT: five templates designed for personal trainers—welcome and onboarding, weekly progress check-in, habit/commitment reminder, client success story highlight, and a re-engagement nudge. Each template emphasizes your focus on accountability, clear progress, and direct client communication, with space for your logo and a direct link to your site.\n\nTo make this easy, I’m including a simple one-click customization and a lightweight 1-page guide on tone and messaging that matches your brand.\n\nNo-commitment: you can trial this for one month at no cost. If it resonates, we can discuss next steps; if not, you’re free to discontinue.\n\nIf you’re open, I can schedule a 20-minute call to tailor the templates to your voice and start the trial as early as next week.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
273	103	35	sent	2025-08-25 13:00:43.580014	0	0	b483ae82-906f-45c0-92eb-4990a609c857	2025-08-25 13:14:06.880081	Quick ways to boost client trust	Hi Danielle,\n\nFollowing up on my note about elevating D&J Photography's client trust, I revisited dandjphotography.co.uk and I’m still impressed by your storytelling approach. To turn browsers into inquiries with minimal effort, here are three quick tweaks:\n\n1) Add a concise client-voice block on the homepage: 2–3 quotes plus a brief context about the shoot. Real words from clients build credibility fast.\n\n2) Create bite-sized case stories: 1-page posts (300–350 words) that outline a challenge, your approach, and the result, with 1 image. Publish quarterly to reinforce your method and improve SEO around terms clients search.\n\n3) Streamline the next step: include a simple scheduling link on the contact page or in the header so prospects can book a call without emailing.\n\nIf you’d like, I can draft ready-to-use templates for testimonials and a lightweight 1-page case story outline you can drop into your site in under an hour.\n\nThanks for your time, Danielle. I’m happy to tailor these to your style.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
271	101	35	sent	2025-08-25 13:00:43.580014	1	0	2c1df2be-7d64-4a3d-94a8-0cfca4e8fce7	2025-08-25 13:09:30.65801	Practical ways to grow Shaun Henry Photography bookings	Hi Shaun,\n\nFollowing up on my note about elevating Shaun Henry Photography’s client trust, I took another look at shaunhenryphotography.uk and wanted to offer a few tangible, low-effort tweaks that can move inquiries toward bookings.\n\n- Showcase client stories: add 2-3 brief case studies or testimonials near the top of the homepage to anchor trust early.\n- Add a simple lead capture: a lightweight inquiry form with a couple of qualifying questions (event type, location, date) to reduce back-and-forth.\n- Streamline the portfolio: organize galleries by storytelling goals (wedding, portrait, editorial) with captions that highlight client objectives and outcomes.\n- Build social proof: a rotating testimonials module or a short client video reel on the homepage.\n- Local SEO at a glance: update page titles and image alt text with location keywords to improve search visibility.\n\nIf you'd like, I can draft a 1-page “shoot process” outline and a quick homepage copy tweak to test these ideas—no long commitment required.\n\nBest,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
254	88	35	sent	2025-08-25 12:15:35.280366	1	0	95e12682-cfd0-46c8-888c-2c2e58245f29	2025-08-25 12:25:13.681606	A smarter email touch for Nuria Serna	Hi there,\n\nI appreciated a quick look at Nuria Serna Photography again. Your portfolio clearly conveys a warm, storytelling approach that helps clients feel seen in life’s moments. Building on my last note about branding, I wanted to share a practical, low-effort tweak that can boost inquiry-to-book conversion.\n\nConsider adding a small, branded “Client Journey” card on your Contact page. It’s a simple, visually consistent template that thanks visitors for reaching out, sets expectations for next steps, and invites them to share a few details about their story. It can reduce back-and-forth and help you tailor your follow-up. Quick outline:\n\n- 2–3 sentence process snapshot (from inquiry to final gallery)\n- A featured gallery link to spark inspiration\n- A clear next-step CTA to schedule a discovery call\n\nIf you’d like, I can draft a lightweight, conversion-focused email sequence aligned to your tone and site, so every touchpoint feels like a natural continuation of your storytelling.\n\nHappy to chat when you have a moment.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
232	31	25	sent	2025-08-24 20:57:15.78522	1	0	79e1c466-0802-4748-b68e-f878d09ffb45	2025-08-24 21:04:45.102444	Boost AFS trust with a branded email	Hi there,\n\nFollowing up on my previous notes about adding a domain-branded email to AFS Artificial Floral Supplies. In a busy florist supplier landscape, the first impression—your inbox address—matters as much as your product range. A consistent, domain-based email builds trust, even before a customer opens your message, and helps your emails land in inboxes rather than spam.\n\nHere’s a quick way to get value fast:\n- Align your contact points under one domain (sales@, info@, support@) to streamline inquiries from wholesale buyers and retailers.\n- Ensure SPF/DKIM are configured for deliverability, so your messages reach customers without delay.\n- Create a simple 1-2 inbox setup to reduce back-and-forth and improve response time.\n\nAs a final nudge, we’re offering the first 3 months for £1 per month with code 1EMAIL, making this a low-risk upgrade for AFS. If you’d like, we can handle a painless, 30-minute setup with minimal disruption and deliver a ready-to-use configuration.\n\nWould you have 15 minutes for a quick chat next week?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
291	79	32	sent	2025-08-27 12:48:47.335385	0	0	6509a7c5-dbb9-48cc-8b4a-fb7dac36d2b3	2025-08-27 12:55:43.099684	A fresh onboarding boost for Kimmy	Hi Kimmy,\n\nI’m circling back after Email #1 and Email #2 to offer a practical, no-nonsense angle that aligns with Get Fit with Kimmy’s focus on personalized coaching and real client transformations. A well-crafted onboarding flow can turn first inquiries into committed clients who show up consistently for coaching and accountability.\n\nHere's a simple path you can test: a 3-part onboarding email sequence that mirrors your coaching rhythm—Welcome and your approach, the first 30 days plan with quick wins, and a progress check-in featuring a client success story. I’d pair each with clear next steps and a light calendar reminder to boost accountability without feeling pushy.\n\nTo make this easy, I’m offering a no-commitment 1-month complimentary trial of branded onboarding emails and a lightweight setup. You’ll get the template set, a short coaching-tone copy, and a basic performance dashboard to track replies and activation.\n\nIf you’re open, tell me 2 times you’re available for a 20-minute call this week and I’ll tailor a starter sequence for Get Fit with Kimmy.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
292	78	32	sent	2025-08-27 12:48:47.335385	0	0	fe7ded69-5126-4cc0-bb55-d929e59b8ac0	2025-08-27 12:57:44.344728	Stuart, one month trial for branded emails	Hi Stuart,\n\nFollowing up on my earlier notes about boosting trust with a branded email for Motiv8 Personal Training, I wanted to share a practical, low-friction plan you can start this week. The aim is to reinforce your client-first approach without adding workload.\n\nHere’s a simple 3-part setup:\n- Consistent header and color cues: keep your logo and Motiv8 colors in every email.\n- Quick-progress snapshot: a one-line client win on the left, a coaching tip on the right.\n- Personal touch: a short, goal-aligned sentence that makes each client feel seen.\n\nTo make this easy, I’m offering a no-commitment, 1-month complimentary trial of a branded email package. It includes ready-to-use templates (welcome, progress update, and recap), a straightforward deployment guide, and a quick alignment call to tailor tone to Motiv8.\n\nIf you’d like, I can draft the first version tailored to Motiv8 and have it ready for your review by early next week.\n\nWarm regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
293	63	32	sent	2025-08-27 12:48:47.335385	0	0	beb51ef7-173c-41f5-8f61-ca20c07c7281	2025-08-27 12:59:45.924036	Coaching-first emails for 223ROC	Hi there,\n\nI’m following up on my prior notes about branding 223ROC Boxing with a coaching-first messaging approach. If you’re aiming to convert interest into sign-ups, the next step is to demonstrate clear outcomes, authentic coaching, and a simple path to training.\n\nHere are 3 actionable tweaks you can implement now:\n- Lead lines that promise coaching-driven results: “From warm-up to knockout power—coached sessions built around your schedule.”\n- A micro-story: a one-line client outcome or progress note.\n- A clear, no-pressure CTA linking to a “Try it free” path.\n\nNo commitment 1 month complimentary trial: I’m offering a no-commitment, 1-month complimentary trial of updated, branded emails to test how this resonates with your audience. I can set up 3-4 emails and a short guide to measure engagement.\n\nIf you’d like, we can jump on a 20-minute call to tailor this to 223ROC Boxing’s voice and your goals.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
349	140	37	failed	\N	0	0	\N	2025-08-28 05:45:03.01674	\N	\N
350	140	37	failed	\N	0	0	\N	2025-08-28 05:50:43.28442	\N	\N
351	140	37	failed	\N	0	0	\N	2025-08-28 05:56:25.967114	\N	\N
352	140	37	failed	\N	0	0	\N	2025-08-28 06:02:02.454141	\N	\N
353	140	37	failed	\N	0	0	\N	2025-08-28 06:07:36.972499	\N	\N
354	140	37	failed	\N	0	0	\N	2025-08-28 06:13:28.713832	\N	\N
355	140	37	failed	\N	0	0	\N	2025-08-28 06:19:23.261808	\N	\N
297	65	32	sent	2025-08-27 13:10:39.304089	0	0	c7374611-6314-4827-834e-84d36ac79f3d	2025-08-27 13:12:19.117293	A tailored next step for Jane Cox Fitness	Hi Jane,\n\nFollowing our earlier messages about branding Jane Cox Fitness and growing online, I’ve been thinking about a practical step that fits your emphasis on personalised training and measurable progress.\n\nA simple, high-impact move is a branded landing page with a client-story section that clearly shows outcomes and progress tracking. When visitors see real journeys and tangible metrics under your brand, trust rises and inquiries improve.\n\nTo remove risk, we’re offering a no-commitment, 1-month complimentary trial to test the approach. It includes:\n- A refreshed, brand-aligned hero and value proposition on your site\n- A short client-progress story reel and testimonial snippet\n- A straightforward enquiry funnel and basic analytics to measure visits, signups, and inquiry rate\n\nIf you’d like, I can tailor this plan specifically to Jane Cox Fitness and share a quick 60-minute walkthrough. No pressure—just a clear, low-friction way to validate impact.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
298	64	32	sent	2025-08-27 13:10:39.304089	0	0	9c45b0b0-fa97-4dda-b976-d3f2580503ea	2025-08-27 13:14:00.688509	Practical branding nudge for Phil Lea PT	Hi Phil,\n\nFollowing Email #1 and Email #2 on boosting client trust with branded emails, here’s a more practical path for Phil Lea Personal Training.\n\nTwo quick steps you can deploy this month:\n- A 3-part welcome/engagement series highlighting workouts, milestones, and client stories.\n- Branded templates that preserve your tone and speed up post-session follow-ups.\n\nThis approach tends to lift engagement and trust by reinforcing progress, turning health checks into ongoing coaching conversations that drive inquiries and sign-ups.\n\nNo-commitment one-month complimentary trial: I’d like to offer a no-commitment one-month complimentary trial of a branded email sequence designed for your business. It includes three ready-to-send emails, a lightweight style guide aligned with your site, and a 30-minute customization call.\n\nIf this feels useful, reply with a start date and I’ll draft the first sequence for your review.\n\nYou’ve built a strong foundation—this can help scale results with less ongoing effort.\n\nAppreciate your time, Phil.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
299	67	32	sent	2025-08-27 13:10:39.304089	0	0	820b43e6-97c7-4407-aba1-d389dce957c6	2025-08-27 13:15:43.342121	A practical next step for Addis Lifestyle	Hi James,\n\nI know you’re busy, so I’ll keep this tight. Building on Email #1’s focus on trust through branded coaching and Email #2’s practical onboarding idea, here’s a concrete, low-risk plan you can test this month.\n\n- Create a 3-part branded welcome sequence: 1) warm intro tied to personalised coaching; 2) a short client journey snapshot with a clear milestone; 3) a simple next-steps email inviting goal details and preferred contact.\n\n- Keep visuals consistent with Addis: logo, color, clean layout to build trust quickly.\n\n- Run a two-week pilot with current contacts and new inquiries, measuring opens, clicks, and messages from prospects.\n\nFor a no-commitment 1-month complimentary trial, I’ll set this branded sequence up for Addis and share the results with you. If it resonates, we can discuss a longer-term approach.\n\nIf you’d like a quick call to confirm timing, I’m available this week.\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
300	120	37	sent	2025-08-28 02:29:44.162783	0	0	89ccf7bd-9094-4258-8fcc-d2104d652134	2025-08-28 02:30:35.176933	Sport Massage Therapy Cymru: branded email boost	Hi there,\n\nI took a look at Sport Massage Therapy Cymru on sporttherapycymru.com and was impressed by your focus on helping athletes recover and perform at their best through tailored massage. In this field, the trust between therapist and client is the foundation for progress—clear communication, consistent care, and visible professionalism.\n\nOne simple way to reinforce that trust online is with a branded domain email. When your practice uses an email that matches your website (for example hello@sporttherapycymru.com), clients see a credible, cohesive brand from first contact to post-session follow-up. It reduces emails getting redirected to spam, improves recall, and feels more personal and professional than a generic address.\n\nFrom my experience working with massage therapists, the impact is measurable: higher reply rates for bookings, clearer consent and aftercare instructions, and stronger client confidence in safety and privacy.\n\nIf you’d like, we can map a quick plan to implement a domain-based email with minimal disruption. You can explore options at wegetyouonline.co.uk/domain-email, or reply here and I’ll tailor a next-step for your practice.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
301	114	37	sent	2025-08-28 02:29:44.162783	0	0	9a3f03d8-daeb-4206-9339-b892635167a0	2025-08-28 02:31:56.472422	Branded email to strengthen client trust	Hi there,\n\nI recently explored Sarah Davies Therapies and was drawn to your warm, client-first approach—from clear service descriptions to easy online booking. That focus sets a solid foundation for trust with every visitor and client you serve.\n\nIn massage therapy, every client touchpoint matters. A domain-branded email (for example hello@sarahdaviestherapies.com) communicates professionalism and care at every inbox interaction—whether you’re sending appointment reminders, post-visit notes, or follow-ups. It helps you present Sarah Davies Therapies consistently, not as a generic inbox.\n\nA branded domain also reduces the chance a message is mistaken for spam, boosts recognition, and establishes a confident tone before the client even opens the message. It’s a small change that reinforces the trusted, personal care you already provide in person.\n\nIf you’re curious, I’d love to show how we can enable a domain-based email for your practice with minimal setup, while keeping your brand front and center. Learn more at wegetyouonline.co.uk/domain-email and reply to this email to start a quick conversation.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
302	119	37	sent	2025-08-28 02:29:44.162783	0	0	d76a2b45-59b8-442d-947b-8cc1a57490f6	2025-08-28 02:33:29.372771	Boost trust for Yurt in the City	Hi there,\n\nI spent a moment exploring Yurt in the City and love how your portable yurts create calm, private spaces right in the heart of urban events. That emphasis on trust and comfort resonates with how clients choose massage therapists. A domain-branded email is a simple, practical way to reinforce that trust from the first greeting—making inquiries, consent notes, and follow-ups feel professional and cohesive.\n\nWith a branded email, clients see your business name clearly in the sender address, which reduces doubt and can improve open rates. It also helps you manage bookings and reminders in one recognizable mailbox, supporting a smoother, more personal client experience.\n\nI can tailor a domain email setup to fit your workflow, whether you host on-site massage pop-ups or wellness workshops. If you’d like to explore how this could work for Yurt in the City, check out wegetyouonline.co.uk/domain-email. I’d be happy to tailor options to your branding and booking tools. Would you be up for a quick 15-minute chat this week?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
303	112	37	sent	2025-08-28 02:29:44.162783	0	0	ed1d49d8-f6fd-4a02-ad99-4e14e063ed3b	2025-08-28 02:35:34.381512	A branded email for Siam Therapy Cardiff	Hi there,\n\nI recently explored Siam Therapy Cardiff and was impressed by your traditional Thai massage approach and the calm, welcoming space you offer in Cardiff. A core truth in massage therapy is the trust between therapist and client, built from the first hello and the emails that follow. My quick observation: when communications come from a domain that matches your brand, clients feel more confident booking and sharing details.\n\nWe Get You Online helps therapists adopt domain-branded emails that align with your website, reinforcing professionalism and trust in every message. Instead of a generic address, you could use names@siamtherapy-cardiff.co.uk or bookings@siamtherapy-cardiff.co.uk, which makes reminders, aftercare tips, and follow-ups feel personal and legitimate.\n\nIf you’re curious, I can outline a simple pilot for Siam Therapy Cardiff with minimal effort and cost. Learn more at wegetyouonline.co.uk/domain-email.\n\nWould you be open to a brief chat this week to tailor a plan?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
304	117	37	sent	2025-08-28 02:29:44.162783	0	0	b53616b9-ceb7-452b-911b-9083a6452031	2025-08-28 02:38:00.067946	Elevate trust for Prawanna Thai Therapy	Hi there,\n\nI recently came across Prawanna Thai Therapy and was drawn to your commitment to authentic Thai massage and client care. In massage therapy, the trust you build with each client is everything—clear communication, consistent scheduling, and a personal, attentive touch all along the client journey.\n\nOne simple way to strengthen that trust is through a branded email on your own domain. A prawannathaitherapy.co.uk email address signals legitimacy, reduces confusion from generic emails, and makes it easier for clients to recognize you in their inbox. It also ensures appointment confirmations, post-session tips, and follow-ups feel like a seamless extension of your brand, not a random message.\n\nIf you’re open to it, I can show how a dedicated domain email can fit with your current website and booking flow, including options for consistent signatures, branding, and direct booking links. This small change can boost trust and encourage repeat visits.\n\nYou can learn more at wegetyouonline.co.uk/domain-email and see how this could benefit a practice like yours.\n\nBest regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
356	140	37	failed	\N	0	0	\N	2025-08-28 06:25:29.742915	\N	\N
357	140	37	failed	\N	0	0	\N	2025-08-28 06:31:40.072639	\N	\N
358	140	37	failed	\N	0	0	\N	2025-08-28 06:37:35.830804	\N	\N
359	140	37	failed	\N	0	0	\N	2025-08-28 06:43:24.365112	\N	\N
360	140	37	failed	\N	0	0	\N	2025-08-28 06:49:44.438697	\N	\N
361	140	37	failed	\N	0	0	\N	2025-08-28 06:55:42.836093	\N	\N
362	140	37	failed	\N	0	0	\N	2025-08-28 07:01:05.504913	\N	\N
363	140	37	failed	\N	0	0	\N	2025-08-28 07:07:17.399938	\N	\N
364	140	37	failed	\N	0	0	\N	2025-08-28 07:13:25.015008	\N	\N
365	140	37	failed	\N	0	0	\N	2025-08-28 07:19:23.104103	\N	\N
366	140	37	failed	\N	0	0	\N	2025-08-28 07:25:00.013189	\N	\N
367	140	37	failed	\N	0	0	\N	2025-08-28 07:30:47.976211	\N	\N
368	140	37	failed	\N	0	0	\N	2025-08-28 07:36:58.294635	\N	\N
369	140	37	failed	\N	0	0	\N	2025-08-28 07:43:03.808798	\N	\N
370	140	37	failed	\N	0	0	\N	2025-08-28 07:49:23.445619	\N	\N
305	118	37	sent	2025-08-28 02:29:44.162783	0	0	0b6d40b1-0b61-4946-8435-86f6237fbe84	2025-08-28 02:39:30.199467	Boost trust with a branded email	Hi there,\n\nI’m Ryan, founder of We Get You Online. I took a moment to explore 7 Sunny Thai Massage and was drawn to your warm branding and your emphasis on authentic Thai massage. In a field where trust is earned with every touch, the way you communicate with clients matters as much as the service you provide.\n\nA professional domain email can strengthen that trust. Instead of a generic address, a branded email signals consistency and credibility across booking confirmations, appointment reminders, and aftercare notes. Clients are more likely to respond and stay engaged when messages come from a recognizable, domain-based address they can verify.\n\nWe can help you set up a domain email that fits with your site, keeping things simple and privacy-friendly for your clients. The result is a smoother customer experience and a higher perceived value for your services.\n\nIf you’d like to see how this could work for 7 Sunny Thai Massage, learn more at wegetyouonline.co.uk/domain-email. I’d be glad to connect for a quick 15-minute chat this week.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
306	116	37	sent	2025-08-28 02:29:44.162783	0	0	859c0a7d-5892-4afe-a67f-62dac1005b68	2025-08-28 02:42:17.05521	Boost client trust with branded email	Hi there,\n\nI’m Ryan, founder of We Get You Online. I spent a moment on Dakota Therapies’ site and was struck by your patient-centered approach to healing. The way you tailor sessions to each client signals trust and long-term care—precisely the relationship clients value before they book their next appointment.\n\nA simple but powerful upgrade is a professional domain-branded email. When clients see messages from your practice’s domain, it reinforces the credibility and consistency they’ve come to rely on. It reduces confusion, builds familiarity, and supports your care-first promise—whether you’re confirming an appointment, sharing self-care tips, or following up after a session.\n\nAt We Get You Online, we help massage practices like Dakota Therapies adopt a professional domain email quickly and securely, with easy management and brand-consistent communication.\n\nIf you’re open to it, I’d love to show you how this can fit your schedule. You can learn more at wegetyouonline.co.uk/domain-email or reply here and we’ll set up a quick, no-pressure chat.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
307	113	37	sent	2025-08-28 02:29:44.162783	0	0	b3d988bf-d4b9-4954-9ab4-9d7c95d04418	2025-08-28 02:44:09.432476	Brand your emails to build trust	Hi there,\n\nI recently visited Massage & Hot Stone and was impressed by your calm, client-centered approach to wellness in Wales. Your site communicates a commitment to a restorative experience, which relies on trust between therapist and client.\n\nOne simple way to reinforce that trust in every email a client receives is using a branded domain email. When your messages come from hello@massageinwales.com or bookings@massageinwales.com, clients immediately recognize you, feel confident the message is legitimate, and remember your brand after their session.\n\nBeyond credibility, branded emails improve consistency across booking confirmations, appointment reminders, post-visit follow-ups, and testimonials requests. It also protects you from spoofed emails, and aligns your communications with your website.\n\nIf you’re curious how this could fit Massage & Hot Stone, I invite you to explore our domain-email solution at wegetyouonline.co.uk/domain-email. I can share a quick, tailored plan to fit your workflows and client journey.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
308	115	37	sent	2025-08-28 02:29:44.162783	0	0	f7d8d1c5-2a4f-48b4-b4b7-1214d14b5e47	2025-08-28 02:46:52.690628	Strengthen client trust for SoulTree Therapies	Hi there,\n\nI recently visited SoulTree Therapies and was drawn to your calm, client-centered approach to holistic wellbeing. In massage practice, trust is the foundation of repeat bookings and referrals, and small details can have a big impact—like the emails your clients receive after a session.\n\nA professional, domain-based email (for example name@soultreetherapies.co.uk) signals credibility and care, reinforcing your brand every time you communicate—from booking confirmations to post-session check-ins. It also helps clients feel confident that messages are legitimate and confidential, which matters when discussing comfort, preferences, or aftercare.\n\nWith a branded email, you can create consistent reminders, notes, and follow-ups that align with your in-studio experience and website. It’s a simple change that strengthens trust and can improve open rates and client recall.\n\nIf you’d like to see how this could work for SoulTree Therapies, I invite you to explore our domain-email solution at wegetyouonline.co.uk/domain-email. Are you available for a quick 15-minute chat this week to discuss a tailored plan?\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
309	125	37	sent	2025-08-28 02:52:23.888118	0	0	40919e2a-3b11-463c-8ccf-0404e64aab58	2025-08-28 02:53:17.895765	Boost client trust with branded emails	Hi there,\n\nI came across Massage Therapy Winchester and was struck by your focus on client well-being and a calming experience, both in your website and services. That trust starts with every touchpoint, including how you follow up after a session.\n\nAt We Get You Online, we help therapists like you elevate that trust with a professional, domain-branded email. A consistent address (for example, hello@massagetherapywinchester.com or bookings@massagetherapywinchester.com) signals credibility, improves deliverability, and makes it easier for clients to reach you reliably—long after their last appointment.\n\nBranded emails also support retention. When reminders, care notes, or tips come from your domain, clients feel confident your messages are from the same trusted practice, not a generic inbox.\n\nIf you’d like, you can explore how this works at wegetyouonline.co.uk/domain-email. It’s a straightforward upgrade that aligns with your website and patient-first approach.\n\nWould you be open to a quick 10-minute chat to discuss options that fit Massage Therapy Winchester?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
310	123	37	sent	2025-08-28 02:52:23.888118	0	0	570f6af8-f17d-444d-af74-edc4e5227939	2025-08-28 02:54:00.235088	Build trust with branded emails	Hi there,\n\nI came across Sports Massage Cardiff at Cardiff Sports Clinic and was impressed by your focus on helping athletes stay in peak form and recover efficiently. The clear, practical approach you offer—tailored treatment plans, injury rehab pathways, and guidance for aftercare—speaks to the trust clients place in you.\n\nAs founder of We Get You Online, I help therapists strengthen that trust with a simple upgrade: a professional domain email. A branded email (for example, yourname@cardiffsportsclinic.co.uk) signals legitimacy and continuity, especially when you follow up after sessions, send care instructions, or share prep tips for their next visit. Clients feel more confident knowing they’re emailing your clinic, not a generic inbox.\n\nA few quick ideas you can apply right away:\n- Use a consistent domain email in all communications to reinforce your clinic’s brand.\n- Route appointment reminders and aftercare tips through your domain to improve deliverability and trust.\n- Share patient-friendly resources from a branded domain to support ongoing care.\n\nIf you’d like to explore how this could work for Sports Massage Cardiff, visit wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
311	128	37	sent	2025-08-28 02:52:23.888118	0	0	49a2ce57-c665-4d04-ac90-fb5673410ae0	2025-08-28 02:55:49.213253	Branded emails to deepen trust at Yew Hill	Hi there,\n\nI spent a moment on Yew Hill Therapy’s site and was struck by your focused approach to Bowen and Soft Tissue Therapy. It’s clear you put client comfort and long-term recovery at the heart of what you do, which naturally builds trust between therapist and client.\n\nOne practical way to reinforce that trust online is through a domain-branded email that mirrors your clinic’s name. When a prospective client receives an email from you with a consistent, professional address, it signals legitimacy and care—two things clients look for before booking an appointment.\n\nOur domain-email solution helps therapists maintain that professional, cohesive presence across all messages—from initial outreach to follow-ups after a session. It’s simple to set up, and it keeps your communications aligned with your brand and your care philosophy.\n\nIf you’d like to see how branded emails can work specifically for Yew Hill Therapy, you can explore our domain-email options at wegetyouonline.co.uk/domain-email. It’s a quick way to start boosting client confidence with every reply.\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
312	127	37	sent	2025-08-28 02:52:23.888118	0	0	9a72bdb0-a94f-4fea-a992-21b1409c9223	2025-08-28 02:57:27.658734	Brand your emails for BodyBest Winchester	Hi there,\n\nI recently visited BodyBest Chiropractic Winchester and was impressed by your patient-first approach and clear care plans. Those values naturally build trust between a massage therapist and client, especially in a clinic that blends chiropractic care with hands-on therapy.\n\nFor therapists who work with clinics like yours, a professional, domain-branded email can boost that trust from the first hello. When clients see an address that matches your brand, they feel more confident in follow-ups, reminders, and post-session guidance.\n\nA branded domain also reduces confusion and reinforces consistency across booking confirmations, appointment reminders, and care notes. Practical steps you can start with: create a dedicated therapist alias, enable an auto-responder for new inquiries, and add a simple signature with your logo and contact details.\n\nIf you’d like to explore how a tailored domain email could fit BodyBest Winchester, you can learn more at wegetyouonline.co.uk/domain-email.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
313	124	37	sent	2025-08-28 02:52:23.888118	0	0	83810995-9dcf-4948-8093-7bafd8c9d842	2025-08-28 02:59:51.472961	Boost Attiva's client trust with branded email	Hi Attiva Massage Therapy team,\n\nI found Attiva's Fresha listing for 18 Norbury Road in Cardiff. It shows you’re making booking simple and approachable, which helps build trust before the first treatment.\n\nThe real trust starts in how you communicate after the session. A branded domain email—such as hello@attivamassage.co.uk—looks professional, protects your brand, and makes confirmations, aftercare tips, and follow-ups feel consistent.\n\nWe Get You Online helps small clinics like yours set up a domain-branded email quickly and securely, with guidance to fit your Cardiff brand. Learn more at wegetyouonline.co.uk/domain-email. If helpful, I can share a simple 2-step plan to start using a branded email that resonates with your clients.\n\nWould you be open to a 15-minute chat this week? If yes, reply with a time or say “Tell me more” and I’ll send details.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
314	126	37	sent	2025-08-28 02:52:23.888118	0	0	1996a0dc-1e82-49d6-81e1-5041fb0c2e79	2025-08-28 03:01:43.820335	Boost trust with branded email for Zoe	Hi there,\n\nI took a look at Zoe Holistic Massage and was really drawn to your focus on holistic well-being and personalised care for every client. In massage therapy, the trust you build in the treatment room starts well before the first session—through every email, booking reply, and follow-up message. A domain-branded email can reinforce that trust from the very first impression.\n\nUsing your own domain (for example, yourname@zoe-holisticmassage.co.uk) signals professionalism and protects client confidence, especially when you're coordinating appointments, sharing aftercare advice, or sending intake forms. A consistent, clear signature with your contact details and a booking link can improve reply rates and reduce friction for new clients exploring your practice.\n\nIf you’d like, I can outline a simple, low-friction plan to move Zoe Holistic Massage to a branded email setup that fits your existing branding. Learn more at wegetyouonline.co.uk/domain-email, and we can tailor a step-by-step path that suits your schedule.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
315	129	37	sent	2025-08-28 02:52:23.888118	0	0	898a4dce-050d-426e-8f0a-803c4a5363dc	2025-08-28 03:04:32.774894	Calmpalms: trust with branded email	Hi there,\n\nI recently learned about Calmpalms Infant Massage and was impressed by how you guide families through gentle, confidence-building infant massage. Your focus on trust, safety, and meaningful parent-child connections is exactly what parents look for when choosing classes.\n\nOne insight I’ve seen with massage practices is that trust is built in every interaction—from the first inquiry to the final follow-up. A branded domain email strengthens that trust from the moment a family sees your message. It signals professionalism, reduces confusion, and makes it easier for clients to reach you for bookings, questions, or consent details.\n\nWe help massage therapists like you establish a professional domain email that aligns with your brand and calmpalms.co.uk presence. The result is clearer communications, better deliverability, and a more consistent experience for clients.\n\nIf you’d like to see how this could work for Calmpalms, take a look at wegetyouonline.co.uk/domain-email. I’d be happy to share a quick example tailored to your practice.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
316	121	37	sent	2025-08-28 02:52:23.888118	0	0	e732edc1-831d-4bc0-b808-1d94f23add7d	2025-08-28 03:07:34.820479	Thicha Thai Cardiff: branded email trust	Hi there,\n\nI recently visited Thicha Thai Beauty Massage Cardiff and was impressed by the emphasis you place on a calming, traditional Thai massage experience for clients in Cardiff. In massage, trust is built from first contact through aftercare, and your online presence plays a big part in that.\n\nA branded domain email can reinforce that trust in three practical ways: it signals credibility from the first outreach, improves email deliverability, and keeps all client communications consistently on-brand—from bookings and confirmations to follow-ups.\n\nSwitching to a domain-based address (for example, your name@thichathai.co.uk) allows you to stay professional and memorable without losing your current setup. It also helps protect against phishing and shows clients you’re serious about their privacy and safety.\n\nIf you’d like, I can share a tailored plan for Thicha Thai Beauty Massage Cardiff with concrete steps to get started. Learn more about the service at wegetyouonline.co.uk/domain-email, and I can tailor the approach to your schedule and tools.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
317	122	37	sent	2025-08-28 02:52:23.888118	0	0	ba34fc38-4840-40e8-8715-efc15b6007df	2025-08-28 03:10:51.565681	A trust-building email for Diva Thai Massage	Hi there,\n\nI spent a moment on Diva Thai Massage & Beauty's website and was struck by your clear focus on well-being and a calm, inviting client journey. Your Thai massage and beauty services are positioned to help guests unwind, which naturally depends on trust between the therapist and the client.\n\nA branded domain email can amplify that trust from the first moment a client sees your message. When booking confirmations, reminders, or follow-up tips come from a branded divathaimassage.co.uk address, clients perceive professionalism, privacy, and consistency—factors that boost appointment bookings and repeat visits. It also helps your messages land in inboxes rather than get lost in spam filters, preserving the care-first experience you promise.\n\nIf you’d like to explore how a professional domain email could fit Diva Thai Massage & Beauty, you can learn more at wegetyouonline.co.uk/domain-email. I’d be happy to draft a quick, brand-aligned welcome or booking-follow-up example to show how it could feel in real customer touchpoints.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
318	133	37	sent	2025-08-28 03:16:26.629877	0	0	7104ba99-4bd7-4955-a304-400302fc6199	2025-08-28 03:17:01.63589	Boost client trust with branded email	Hi there,\n\nI recently explored Jamie Gough Soft Tissue Massage and was impressed by your focus on helping clients recover faster through targeted soft tissue therapy and sports massage. Your site communicates care and expertise, which is essential for clients seeking relief and confidence in their therapist.\n\nA branded domain email helps reinforce that trust from the first point of contact. When clients see emails coming from a professional domain, it signals privacy, reliability, and a consistent brand experience across booking confirmations, follow-ups, and post-session tips. It reduces hesitation at the moment of scheduling and strengthens the therapist-client relationship built on clarity and care.\n\nA simple step you can take now is to align all client communications under a single, domain-branded email. It’s not just about appearance—it's about trust, reducing confusion, and improving response rates.\n\nIf you’d like to explore how domain email can work for your practice, you can see more at wegetyouonline.co.uk/domain-email.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
319	138	37	sent	2025-08-28 03:16:26.629877	0	0	f761958b-1f0f-4902-927f-13abfac2d50f	2025-08-28 03:18:42.269751	Boost client trust with branded email for Chom	Hi there,\n\nI spent a moment on Chom Traditional Thai Massage Therapy’s site and was struck by your commitment to authentic Thai techniques and a serene, welcoming experience. That focus on trust—between practitioner and client—shines through in the care you provide.\n\nFrom what I saw, your approach centers on comfort, clear communication, and respect for tradition. A branded domain email fits beautifully into that trust-building, because it signals professionalism from the first hello and through every follow-up—from appointment reminders to aftercare tips.\n\nWith a branded email (for example yourname@chommassage.co.uk) you create a consistent, credible brand voice. Clients feel safer clicking links, replying to reminders, and booking again when your emails come from your own domain rather than a generic provider.\n\nI’d love to show you how a branded domain email can slot into your current workflow, with simple steps to implement and a rollout that preserves your authentic voice.\n\nWould you like to explore options? Learn more at wegetyouonline.co.uk/domain-email\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
371	140	37	failed	\N	0	0	\N	2025-08-28 08:04:03.843182	\N	\N
372	140	37	failed	\N	0	0	\N	2025-08-28 08:10:26.637615	\N	\N
373	140	37	failed	\N	0	0	\N	2025-08-28 08:15:54.670589	\N	\N
374	140	37	failed	\N	0	0	\N	2025-08-28 08:22:06.397676	\N	\N
375	140	37	failed	\N	0	0	\N	2025-08-28 08:27:43.366248	\N	\N
376	140	37	failed	\N	0	0	\N	2025-08-28 08:33:52.317038	\N	\N
377	140	37	failed	\N	0	0	\N	2025-08-28 08:39:44.585586	\N	\N
378	140	37	failed	\N	0	0	\N	2025-08-28 08:45:39.365289	\N	\N
379	140	37	failed	\N	0	0	\N	2025-08-28 08:51:00.449248	\N	\N
380	140	37	failed	\N	0	0	\N	2025-08-28 08:56:28.639282	\N	\N
381	140	37	failed	\N	0	0	\N	2025-08-28 09:01:54.436369	\N	\N
382	140	37	failed	\N	0	0	\N	2025-08-28 09:08:07.84438	\N	\N
383	140	37	failed	\N	0	0	\N	2025-08-28 09:14:14.488478	\N	\N
384	140	37	failed	\N	0	0	\N	2025-08-28 09:19:45.539076	\N	\N
385	140	37	failed	\N	0	0	\N	2025-08-28 09:25:32.954532	\N	\N
320	134	37	sent	2025-08-28 03:16:26.629877	0	0	1a14bde4-d446-4476-93e3-27f2b5624ffd	2025-08-28 03:19:58.997533	A branded email for Winchester Spine Centre	Hi there,\n\nI checked Winchester Spine Centre's site and noticed your emphasis on patient-first care and long-term pain management for back and neck issues. In conversations with massage therapists and chiropractors, I hear how crucial trust is in your client relationships. A professional domain branded email—like hello@winchesterchiropractor.com or a similar branded address—helps reinforce that trust every time a client reads your message, books an appointment, or follows up after a treatment.\n\nWe find branded domain emails improve perceived professionalism, privacy, and consistency, which is essential when you discuss treatment plans or aftercare. With a domain email, you can also route messages to your preferred inbox, set up appointment confirmations, and maintain brand coherence across your website, social, and communications. Practical steps: set up a domain alias for bookings, ensure secure email with TLS, and craft a warm, concise signature that includes a call to action.\n\nIf you’re exploring, you can learn more at wegetyouonline.co.uk/domain-email.\n\nThank you for your time.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
321	130	37	sent	2025-08-28 03:16:26.629877	0	0	85d30a40-4296-4fc5-a958-cd7e3d6f2d9d	2025-08-28 03:21:12.826366	Boost client trust with branded email	Hi Hayden Therapies team,\n\nI’ve been looking at haydentherapies.com and was impressed by your focus on personalized care and helping clients feel at ease from their first visit. That trust you build—through listening, consistent sessions, and a calming space—starts even before the appointment, with how you communicate. A branded domain email strengthens that trust further. Clients see you as a professional and stable business when every message comes from info@haydentherapies.com or bookings@haydentherapies.com, not a generic address. It reduces hesitation, makes it easier to confirm bookings, and reinforces the relationship you cultivate in each session.\n\nIf you’re exploring ways to enhance client confidence online, I can help with a simple branded email solution designed for service providers like you. It’s easy to set up, ensures consistency across messages, invoices, and reminders, and directs clients to the right contact path.\n\nWould you be open to a quick chat to explore how this could fit Hayden Therapies? You can learn more at wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\n\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
322	136	37	sent	2025-08-28 03:16:26.629877	0	0	15c11c99-a673-43b1-a2cb-0a9b12be2e74	2025-08-28 03:23:42.114304	Branded email for WintonLake Massage Bournemouth	Hi there,\n\nI spent a moment on WintonLake Massage Therapy Bournemouth and was struck by your calm, client-centered approach in Bournemouth. The way you tailor sessions shows trust is built through consistency—before, during, and after a treatment.\n\nA professional domain-branded email reinforces that trust at every touchpoint. When booking confirmations, reminders, and follow-ups come from a single address that matches your online presence, clients see credibility and care. In a service where clients share sensitive wellbeing details, a recognizable domain also signals privacy and reliability. This consistency lowers friction, improves replies, and avoids confusion with generic addresses.\n\nIf you’re open, I can show how a domain email fits with your booking tools and simple templates for initial contact and follow-up. Learn more at wegetyouonline.co.uk/domain-email. I can tailor the setup to your existing branding and help you craft a consistent sender name and signature.\n\nWould you be up for a quick 10-minute chat to explore options?\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
323	132	37	sent	2025-08-28 03:16:26.629877	0	0	68517a98-af0f-4be9-a3a0-4e6c0cfd479a	2025-08-28 03:25:52.235138	Trustworthy email branding for Thai Massage	Hi there,\n\nFrom Thai Massage by Gussanova, I can see a clear focus on a calming, traditional Thai massage experience that helps clients unwind and restore balance. That emphasis on a trusted, personal connection between therapist and client is the foundation of great care—and it starts before the session and continues after.\n\nA professionally branded domain email is a simple, powerful way to reinforce that trust every time you reach out. When clients receive messages from an address on thaimassagebygussanova.co.uk, it signals credibility, consistency, and care—crucial elements in building comfort before, during, and after a session.\n\nWith branded email you can: 1) present a cohesive brand in every message, 2) improve legitimacy for appointment requests and follow-ups, and 3) create a smoother client journey from booking to aftercare tips.\n\nI’d be glad to show you how we can set this up for your business at wegetyouonline.co.uk/domain-email, including friendly auto-replies and a clean signature that reflects your massage practice.\n\nWould you be open to a quick 10-minute chat to explore options?\n\nBest,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
324	131	37	sent	2025-08-28 03:16:26.629877	0	0	fb960f00-0aa9-47b3-961a-231f29dd1223	2025-08-28 03:28:22.20027	Brand your emails for client trust	Hi there,\n\nI was looking at Revive Clinical Massage and Sports Massage Therapy and I was impressed by how you position your practice at the crossroads of clinical care and athletic recovery. Your focus on helping clients move from injury toward performance suggests a deep commitment to trust, privacy, and clear communication—qualities that matter as soon as a new client opens your email.\n\nA professional, domain-branded email can reinforce that trust from the first message. When your replies and appointment reminders come from a Revive-branded address, clients feel they are in safe hands and can share sensitive details about pain and recovery with confidence. It also makes your communications look consistent and credible in a busy inbox.\n\nIf you’re curious, we can tailor a domain email for Revive Clinical Massage and Sports Massage Therapy that reflects your brand and protects client privacy. You can explore how this works at wegetyouonline.co.uk/domain-email and see practical steps you can take today.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
325	135	37	sent	2025-08-28 03:16:26.629877	0	0	795b165d-ddb9-4e64-b3c8-f40c984a701a	2025-08-28 03:30:59.130036	Build trust with a branded email	Hi PB Sports Therapy team,\n\nI recently visited pb-sportsmassage.co.uk and was impressed by your athlete-focused approach to sports massage and rehabilitation. Your emphasis on tailored treatment plans for runners, team players, and active individuals shows a clear commitment to real results and ongoing care. That kind of personalized, hands-on approach is exactly what builds lasting trust between a therapist and client.\n\nA professional domain-branded email can reinforce that trust at every touchpoint. Using an address that matches your website (for example, hello@pb-sportsmassage.co.uk or bookings@pb-sportsmassage.co.uk) signals legitimacy and consistency, from intake forms to appointment confirmations and post-visit care notes. It helps clients feel they’re in capable hands, not juggling multiple inboxes.\n\nWe can help you set up a clean, secure domain email that aligns with PB Sports Therapy, along with a concise signature that links back to your site and booking page. If you’d like to see how this could work for you, explore our domain email solution here: wegetyouonline.co.uk/domain-email.\n\nWould you be open to a quick 10-minute chat this week to discuss options and next steps?\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
327	140	37	failed	\N	0	0	\N	2025-08-28 03:39:30.482663	\N	\N
329	140	37	failed	\N	0	0	\N	2025-08-28 03:46:59.75988	\N	\N
330	140	37	failed	\N	0	0	\N	2025-08-28 03:53:18.279692	\N	\N
331	140	37	failed	\N	0	0	\N	2025-08-28 03:59:09.194728	\N	\N
332	140	37	failed	\N	0	0	\N	2025-08-28 04:05:16.950451	\N	\N
333	140	37	failed	\N	0	0	\N	2025-08-28 04:10:47.731593	\N	\N
334	140	37	failed	\N	0	0	\N	2025-08-28 04:16:40.833051	\N	\N
335	140	37	failed	\N	0	0	\N	2025-08-28 04:22:14.685502	\N	\N
336	140	37	failed	\N	0	0	\N	2025-08-28 04:27:39.221213	\N	\N
337	140	37	failed	\N	0	0	\N	2025-08-28 04:33:25.883177	\N	\N
338	140	37	failed	\N	0	0	\N	2025-08-28 04:39:36.804914	\N	\N
339	140	37	failed	\N	0	0	\N	2025-08-28 04:45:52.411174	\N	\N
340	140	37	failed	\N	0	0	\N	2025-08-28 04:51:39.367142	\N	\N
341	140	37	failed	\N	0	0	\N	2025-08-28 04:57:56.426163	\N	\N
342	140	37	failed	\N	0	0	\N	2025-08-28 05:04:12.430872	\N	\N
343	140	37	failed	\N	0	0	\N	2025-08-28 05:10:03.14967	\N	\N
344	140	37	failed	\N	0	0	\N	2025-08-28 05:15:30.375953	\N	\N
345	140	37	failed	\N	0	0	\N	2025-08-28 05:21:36.990236	\N	\N
346	140	37	failed	\N	0	0	\N	2025-08-28 05:27:54.295464	\N	\N
347	140	37	failed	\N	0	0	\N	2025-08-28 05:33:49.746646	\N	\N
348	140	37	failed	\N	0	0	\N	2025-08-28 05:39:13.283717	\N	\N
328	139	37	sent	2025-08-28 03:39:21.476541	1	0	da8918ca-0a26-451a-96aa-472626baf4e7	2025-08-28 03:39:50.676438	Elevate Soul Serenity’s client trust	Hi there,\n\nI’ve spent time exploring Soul Serenity the Crystal Spa and love how you blend holistic therapies with a crystal shop and a training centre. An insight that stood out is your commitment to trusted, transformative experiences—your clients’ journey from session to aftercare is clearly important to you.\n\nA branded domain email helps you reinforce that trust from the first hello. When clients see a professional email from your domain, it signals reliability, consistency, and care — key factors in the massage-client relationship. It also reduces confusion, improves inbox deliverability, and creates a seamless extension of your brand across bookings, aftercare, and education materials.\n\nIf you’re open to it, I can show how a tailored domain email (for example on soulserenityspa.co.uk) can streamline client communications and boost post-session bookings. You’ll be able to share class schedules, workshop notices, and aftercare tips with the same trusted tone.\n\nFor a quick look, visit wegetyouonline.co.uk/domain-email and see how this could work for Soul Serenity.\n\nBest regards,\n\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
326	137	37	sent	2025-08-28 03:16:26.629877	1	0	e6828ab6-658c-457c-8920-3b7dbe892130	2025-08-28 03:33:54.170586	Touch Of Thai Massage: Elevate client trust	Hi there,\n\nI recently visited touchofthai.co.uk and was impressed by your focus on authentic Thai massage to relieve stress and restore balance. In a field where clients entrust their well-being to your hands, the trust you build starts with clear, professional communication—right from the moment you reach out by email.\n\nA branded domain email (for example hello@touchofthai.co.uk) signals legitimacy, consistency, and care. It helps clients feel confident choosing you, and it makes appointment confirmations, post-session care tips, and follow-ups feel more personal and reliable.\n\nFrom what I gathered, your clients value a calm, professional experience—tying that to your brand in every touchpoint, including email, can strengthen loyalty.\n\nI’d love to show you a simple way to start using a professional domain email that aligns with Touch Of Thai Massage, with minimal setup and maximum impact. If you’re curious, you can explore options at wegetyouonline.co.uk/domain-email.\n\nWarm regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
168	89	34	sent	2025-08-22 12:12:39.966876	1	0	b7f28096-d138-4d39-be1a-316f1ea5f199	2025-08-22 12:13:17.976244	Branded email to boost Balance's trust	Hi there,\n\nI visited Balance Photography Studio and was impressed by how your work centers on natural light and genuine moments. That focus on balanced, authentic storytelling is a powerful trust signal to clients choosing someone to document their most important days.\n\nA simple way to reinforce that trust from the first email is a professional domain-branded address. Using your own domain rather than a generic inbox helps clients feel confident and seen, even before meeting you. It also keeps your communications consistent with your calm, timeless aesthetic.\n\nBranded email supports clearer inquiries, smoother bookings, and a more personal, high-trust client experience overall. It’s one small upgrade that can improve retention and referrals as clients share galleries and details with family and friends.\n\nIf Balance Photography Studio is curious to explore this, you can learn more at wegetyouonline.co.uk/domain-email. I’d be glad to tailor the setup to your branding and workflow.\n\nBest regards,\nRyan\nFounder\nWe Get You Online\nryan@wegetyouonline.co.uk
\.


--
-- Data for Name: sequence_steps; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.sequence_steps (id, sequence_id, step_number, name, ai_prompt, delay_days, delay_hours, is_active, created_at, subject, template, include_previous_emails) FROM stdin;
1	2	1	Initial Outreach	We are WeGetYou.Online a business focused on empowering small businesses online and giving them the tools they need to compete and be seen online. Many small business open a free gmail account when they start up. What they dont know is that this free email account is likely hurting their reputation and turning customers away. A recent study found that 80% of people would decide to not contact a company of they had a free gmail account like gmail, outlook or yahoo. They believed it made the company less professional and less trust worthy. In a competitive online  market, first impressions are everything.\n\nYour task is to help me write a compelling, engaging cold outreach email to leads with the intention of them purchasing an email plan from us. Companies like google charge per user but we are different. we charge for the storage used and you can have unlimited accounts. This makes it a very attractive proposition for a budget conscious small business.\n\nYou must include a call to action to click on my link https://wegetyou.online/domain-email	0	0	t	2025-08-13 12:13:06.444553			f
2	2	2	Follow-up 2	We are WeGetYou.Online a business focused on empowering small businesses online and giving them the tools they need to compete and be seen online. Many small business open a free gmail account when they start up. What they dont know is that this free email account is likely hurting their reputation and turning customers away. A recent study found that 80% of people would decide to not contact a company of they had a free gmail account like gmail, outlook or yahoo. They believed it made the company less professional and less trust worthy. In a competitive online  market, first impressions are everything.\n\nThe lead did not reply to my previous email adveritising out services. Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didnt respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	0	1	t	2025-08-13 12:13:06.444556			f
4	4	1	Initial Outreach	We are WeGetYou.Online a business focused on empowering small businesses online and giving them the tools they need to compete and be seen online. Many small business open a free gmail account when they start up. What they dont know is that this free email account is likely hurting their reputation and turning customers away. A recent study found that 80% of people would decide to not contact a company of they had a free email address like gmail, outlook or yahoo. They believed it made the company less professional and less trust worthy. In a competitive online  market, first impressions are everything.\n\nYour task is to help me write a compelling, engaging cold outreach email to leads with the intention of them purchasing an email plan from us. Companies like google charge per user but we are different. we charge for the storage used and you can have unlimited accounts. This makes it a very attractive proposition for a budget conscious small business.\n\nYou must include a call to action to click on my link https://wegetyou.online/domain-email	0	0	t	2025-08-15 11:04:11.904484	\N	\N	f
5	4	2	Follow-up 2	\nThe lead did not reply to my previous email adveritising out services. Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	0	1	t	2025-08-15 11:04:11.904487	\N	\N	f
6	5	1	Initial Outreach	We are WeGetYou.Online a business focused on empowering small businesses online and giving them the tools they need to compete and be seen online. Many small business open a free gmail account when they start up. What they dont know is that this free email account is likely hurting their reputation and turning customers away. A recent study found that 80% of people would decide to not contact a company of they had a free email address like gmail, outlook or yahoo. They believed it made the company less professional and less trust worthy. In a competitive online  market, first impressions are everything.\n\nYour task is to help me write a compelling, engaging cold outreach email to leads with the intention of them purchasing an email plan from us. Companies like google charge per user but we are different. we charge for the storage used and you can have unlimited accounts. This makes it a very attractive proposition for a budget conscious small business.\n\nYou must include a call to action to click on my link https://wegetyou.online/domain-email	0	0	t	2025-08-15 11:06:47.756813	\N	\N	f
7	5	2	Follow-up 2	\nThe lead did not reply to my previous email adveritising out services. Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	0	1	t	2025-08-15 11:06:47.756815	\N	\N	f
8	6	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-16 06:53:11.495319	\N	\N	f
9	6	2	Follow-up 2	Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	3	1	t	2025-08-16 06:53:11.495322	\N	\N	t
10	7	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-16 12:43:41.961235	\N	\N	f
11	7	2	Follow-up 2	Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	0	1	t	2025-08-16 12:43:41.961237	\N	\N	t
12	8	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-18 08:37:48.511712	\N	\N	f
13	8	2	Follow-up 2	Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	0	1	t	2025-08-18 08:37:48.511714	\N	\N	t
14	9	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-18 09:54:59.185898	\N	\N	f
15	9	2	Follow-up 2	Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	3	0	t	2025-08-18 09:54:59.1859	\N	\N	t
16	10	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-18 10:47:27.264302	\N	\N	f
17	11	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-18 11:27:04.689011	\N	\N	f
18	12	1	Initial Outreach	We are WeGetYou.Online a business focused on empowering small businesses online and giving them the tools they need to compete and be seen online. Many small business open a free gmail account when they start up. What they dont know is that this free email account is likely hurting their reputation and turning customers away. A recent study found that 80% of people would decide to not contact a company of they had a free email address like gmail, outlook or yahoo. They believed it made the company less professional and less trust worthy. In a competitive online  market, first impressions are everything.\n\nYour task is to help me write a compelling, engaging cold outreach email to leads with the intention of them purchasing an email plan from us. Companies like google charge per user but we are different. we charge for the storage used and you can have unlimited accounts. This makes it a very attractive proposition for a budget conscious small business.\n\nYou must include a call to action to click on my link https://wegetyou.online/domain-email\n\n\nWrite a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-18 11:56:55.518463	\N	\N	f
19	12	2	Follow-up 2	The lead did not reply to my previous email adveritising our professional email services. Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.\n\nWrite a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	0	1	t	2025-08-18 11:56:55.518465	\N	\N	t
20	13	1	Initial Outreach	We are WeGetYou.Online a business focused on empowering small businesses online and giving them the tools they need to compete and be seen online. Many small business open a free gmail account when they start up. What they dont know is that this free email account is likely hurting their reputation and turning customers away. A recent study found that 80% of people would decide to not contact a company of they had a free email address like gmail, outlook or yahoo. They believed it made the company less professional and less trust worthy. In a competitive online  market, first impressions are everything.\n\nYour task is to help me write a compelling, engaging cold outreach email to leads with the intention of them purchasing an email plan from us. Companies like google charge per user but we are different. we charge for the storage used and you can have unlimited accounts. This makes it a very attractive proposition for a budget conscious small business.\n\nYou must include a call to action to click on my link https://wegetyou.online/domain-email	0	0	t	2025-08-18 14:08:53.005389	\N	\N	f
21	14	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-18 14:49:44.563657	\N	\N	f
22	15	1	Initial Outreach	I run a business called wegetyou.online. At my business we sell domain branded email like info@yourcompany.co.uk. we are reaching out to prospective clients. Please do research on the client and provide them with information about how domain branded email could help them\n\nWrite a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-18 15:01:56.71326	\N	\N	f
23	16	1	Initial Outreach	Write a professional, personalized cold email that introduces our professional domain branded email. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyou.online/domain-email. Visit my site and choose value for the customer. \n\nInclude a call to action for wegetyou.online/domain-email 	0	0	t	2025-08-18 20:23:16.209149	\N	\N	f
24	16	2	Follow-up 2	Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach about domain branded email, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	3	0	t	2025-08-18 20:23:16.209151	\N	\N	t
25	16	3	Follow-up 3	Write a professional follow-up email for step 3 of the sequence. This is the final email. Reference the previous emails in the conversation naturally. The recipient hasn't responded yet, so try a different approach or provide more value. Keep it concise and respectful. Create an engaging subject line that stands out. We shall also offer the first 3 months for £1 a month using code 1EMAIL	3	0	t	2025-08-18 20:23:16.209151	\N	\N	t
26	17	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-19 14:29:54.625244	\N	\N	f
27	18	1	Initial Outreach	Write a professional, personalized cold email that introduces our professional domain branded email. We are focussing on personal trainers. Focus on the relationship of trust between a pt and a clinet. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyou.online/domain-email. Visit my site and choose value for the customer. Include a call to action for wegetyou.online/domain-email 	0	0	t	2025-08-20 05:53:21.522728	\N	\N	f
28	19	1	Initial Outreach	Write a professional, personalized cold email that introduces our professional domain branded email. We are focussing on personal trainers. Focus on the relationship of trust between a pt and a clinet. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyou.online/domain-email. Visit my site and choose value for the customer. Include a call to action for wegetyou.online/domain-email 	0	0	t	2025-08-20 07:38:01.924454	\N	\N	f
29	20	1	Initial Outreach	Write a professional, personalized cold email that introduces our professional domain branded email. we are targeting personal trainers. We should focus on the trust relationship between personal trainer and client and how branded email can enhance that. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyouonline.co.uk/domain-email. Visit my site and choose value for the customer. Include a call to action for wegetyouonline.co.uk/domain-email 	0	0	t	2025-08-20 08:20:24.223953	\N	\N	f
30	21	1	Initial Outreach	First research the company through their website and then write a highly personalized cold email that introduces our professional domain branded email. include at least one insight about the company we are targeting personal trainers. We should focus on the trust relationship between personal trainer and client and how branded email can enhance that. Keep it engaging. Use the lead's name and company naturally. Create an intriguing unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyouonline.co.uk/domain-email. Visit my site and choose value for the customer. Include a call to action for wegetyouonline.co.uk/domain-email 	0	0	t	2025-08-20 13:38:02.250479	\N	\N	f
31	21	2	Follow-up 2	Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	3	0	t	2025-08-20 13:38:02.250481	\N	\N	t
32	21	3	Follow-up 3	Write a professional follow-up email for step 3 of the sequence. Reference the previous emails in the conversation naturally. The recipient hasn't responded yet and this is our last attempt, so try a different approach or provide more value. Also mention a no commitment 1 month complimentary trial. Keep it concise and respectful. Create an engaging subject line that stands out.	3	0	t	2025-08-20 13:38:02.250481	\N	\N	t
33	22	1	Initial Outreach	Write a professional, personalized cold email that introduces our services. Keep it concise and engaging. Use the lead's name and company naturally. Create a witty, unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression.	0	0	t	2025-08-20 19:57:42.801331	\N	\N	f
34	23	1	Initial Outreach	First research the company through their website and then write a highly personalized cold email that introduces our professional domain branded email. include at least one insight about the company. we are targeting photographers. We should focus on the trust relationship between photographer and client and how branded email can enhance that. Photographers are often counted on to capture the most important moments in people's lives. Keep it engaging. Use the lead's name and company naturally. Create an intriguing unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyouonline.co.uk/domain-email. Visit my site and choose value for the customer. Include a call to action for wegetyouonline.co.uk/domain-email 	0	0	t	2025-08-22 12:10:55.611122	\N	\N	f
35	23	2	Follow-up 2	Write a professional follow-up email. Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach, so provide additional value or a different angle. Keep it concise and helpful. Create an engaging subject line.	3	0	t	2025-08-22 12:10:55.611124	\N	\N	t
36	23	3	Follow-up 3	Write a professional follow-up email for step 3 of the sequence. Reference the previous emails in the conversation naturally. The recipient hasn't responded yet and this is our last attempt, so try a different approach or provide more value. Also mention a no commitment 1 month complimentary trial. Keep it concise and respectful. Create an engaging subject line that stands out.	3	0	t	2025-08-22 12:10:55.611127	\N	\N	t
37	24	1	Initial Outreach	First research the company through their website and then write a highly personalized cold email that introduces our professional domain branded email. include at least one insight about the company. we are targeting massage therapists. \n\nWe should focus on the trust relationship between massage therapist and client and how branded email can enhance that.\n\n Keep it engaging. Use the lead's name and company naturally. Create an intriguing unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyouonline.co.uk/domain-email. Visit my site and choose value for the customer. Include a call to action for wegetyouonline.co.uk/domain-email 	0	0	t	2025-08-28 02:27:44.050417	\N	\N	f
38	24	2	Follow-up 2	Write a professional follow-up email.  Do not mention step 2 in the email Reference the previous email naturally without being pushy. The recipient didn't respond to the initial outreach. This time let's focus in on the value added to their business from branded professional email. Also mention the affordability of our service. A takeaway coffee every month will cost more.  Create an engaging subject line. Include a call to action for wegetyouonline.co.uk/domain-email 	3	0	t	2025-08-28 02:27:44.05042	\N	\N	t
39	24	3	Follow-up 3	Write a professional follow-up email for step 3 of the sequence.  DO not mention step 3 in the email. Reference the previous emails in the conversation naturally. The recipient hasn't responded yet and this is our last attempt and our final push. Be more direct but remain focused on our professional email product. Mention a no commitment 1 month complimentary trial if they respond to the email. Also compare ourselves to competitors. Google charge per user, however we charge for the storage used and you can have unlimited accounts (sales@, bookings@, info@ etc). Focus on how this pricing model benefits small businesses. Keep it concise and respectful. Create an engaging subject line that stands out.	3	0	t	2025-08-28 02:27:44.05042	\N	\N	t
40	25	1	Initial Outreach	First research the company through their website and then write a highly personalized cold email that introduces our professional domain branded email. include at least one insight about the company. we are targeting massage therapists. We should focus on the trust relationship between massage therapist and client and how branded email can enhance that. Keep it engaging. Use the lead's name and company naturally. Create an intriguing unique subject line that grabs attention without being spammy. This is the first email in a sequence, so focus on making a great first impression. You can find out more about my service at wegetyouonline.co.uk/domain-email. Visit my site and choose value for the customer. Include a call to action for wegetyouonline.co.uk/domain-email 	0	0	t	2025-08-28 17:16:42.244026	\N	\N	f
\.


--
-- Data for Name: tracking_events; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.tracking_events (id, campaign_lead_id, event_type, event_data, ip_address, user_agent, created_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.users (id, email, username, full_name, hashed_password, is_active, is_superuser, created_at, updated_at) FROM stdin;
1	admin@example.com	admin	System Administrator	$2b$12$pxGA4IzRhqvZfEUKZpfbReTsLMV1rJSpnyGVfW4YoyUwPN8eQscPy	t	t	2025-08-13 20:23:44.104909+00	\N
2	test@test.com	test	\N	$2b$12$IPjSAGB3UMThCkqE.zvkd.6FCIDHKlS2LHF8eAg54yIikRHEoVzxO	t	f	2025-08-13 20:30:18.074229+00	\N
3	newuser@example.com	newuser	New User	$2b$12$RX.6AfOUY1A66rBTP/gpne41RjDi0wtPABeO/UUdJ5PSqLPoNCJji	t	f	2025-08-13 20:30:56.069676+00	\N
4	ryan@vezra.co.uk	ryan	Ryan Ellis	$2b$12$Gwd9Q2wR4Wlfmkw1WTg7yuzTh9T4XjhjEyH7L/7j.Hjesq7gfwg3O	t	t	2025-08-16 06:00:10.091884+00	\N
\.


--
-- Name: api_keys_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.api_keys_id_seq', 1, true);


--
-- Name: campaign_leads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.campaign_leads_id_seq', 17, true);


--
-- Name: campaigns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.campaigns_id_seq', 16, true);


--
-- Name: email_open_analysis_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.email_open_analysis_id_seq', 1, false);


--
-- Name: email_replies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.email_replies_id_seq', 1, false);


--
-- Name: email_sequences_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.email_sequences_id_seq', 25, true);


--
-- Name: email_tracking_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.email_tracking_events_id_seq', 1, false);


--
-- Name: lead_group_memberships_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.lead_group_memberships_id_seq', 135, true);


--
-- Name: lead_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.lead_groups_id_seq', 22, true);


--
-- Name: lead_sequences_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.lead_sequences_id_seq', 165, true);


--
-- Name: leads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.leads_id_seq', 339, true);


--
-- Name: link_clicks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.link_clicks_id_seq', 1, true);


--
-- Name: sending_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.sending_profiles_id_seq', 2, true);


--
-- Name: sequence_emails_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.sequence_emails_id_seq', 452, true);


--
-- Name: sequence_steps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.sequence_steps_id_seq', 40, true);


--
-- Name: tracking_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.tracking_events_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: user
--

SELECT pg_catalog.setval('public.users_id_seq', 4, true);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: campaign_leads campaign_leads_campaign_id_lead_id_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_campaign_id_lead_id_key UNIQUE (campaign_id, lead_id);


--
-- Name: campaign_leads campaign_leads_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_pkey PRIMARY KEY (id);


--
-- Name: campaign_leads campaign_leads_tracking_pixel_id_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_tracking_pixel_id_key UNIQUE (tracking_pixel_id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: daily_stats daily_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.daily_stats
    ADD CONSTRAINT daily_stats_pkey PRIMARY KEY (date);


--
-- Name: email_open_analysis email_open_analysis_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_open_analysis
    ADD CONSTRAINT email_open_analysis_pkey PRIMARY KEY (id);


--
-- Name: email_open_analysis email_open_analysis_tracking_id_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_open_analysis
    ADD CONSTRAINT email_open_analysis_tracking_id_key UNIQUE (tracking_id);


--
-- Name: email_replies email_replies_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_replies
    ADD CONSTRAINT email_replies_pkey PRIMARY KEY (id);


--
-- Name: email_sequences email_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_sequences
    ADD CONSTRAINT email_sequences_pkey PRIMARY KEY (id);


--
-- Name: email_tracking_events email_tracking_events_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_tracking_events
    ADD CONSTRAINT email_tracking_events_pkey PRIMARY KEY (id);


--
-- Name: lead_group_memberships lead_group_memberships_lead_id_group_id_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_group_memberships
    ADD CONSTRAINT lead_group_memberships_lead_id_group_id_key UNIQUE (lead_id, group_id);


--
-- Name: lead_group_memberships lead_group_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_group_memberships
    ADD CONSTRAINT lead_group_memberships_pkey PRIMARY KEY (id);


--
-- Name: lead_groups lead_groups_name_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_groups
    ADD CONSTRAINT lead_groups_name_key UNIQUE (name);


--
-- Name: lead_groups lead_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_groups
    ADD CONSTRAINT lead_groups_pkey PRIMARY KEY (id);


--
-- Name: lead_sequences lead_sequences_lead_id_sequence_id_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_sequences
    ADD CONSTRAINT lead_sequences_lead_id_sequence_id_key UNIQUE (lead_id, sequence_id);


--
-- Name: lead_sequences lead_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_sequences
    ADD CONSTRAINT lead_sequences_pkey PRIMARY KEY (id);


--
-- Name: leads leads_email_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_email_key UNIQUE (email);


--
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (id);


--
-- Name: link_clicks link_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.link_clicks
    ADD CONSTRAINT link_clicks_pkey PRIMARY KEY (id);


--
-- Name: sending_profiles sending_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sending_profiles
    ADD CONSTRAINT sending_profiles_pkey PRIMARY KEY (id);


--
-- Name: sequence_emails sequence_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_emails
    ADD CONSTRAINT sequence_emails_pkey PRIMARY KEY (id);


--
-- Name: sequence_emails sequence_emails_tracking_pixel_id_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_emails
    ADD CONSTRAINT sequence_emails_tracking_pixel_id_key UNIQUE (tracking_pixel_id);


--
-- Name: sequence_steps sequence_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_steps
    ADD CONSTRAINT sequence_steps_pkey PRIMARY KEY (id);


--
-- Name: sequence_steps sequence_steps_sequence_id_step_number_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_steps
    ADD CONSTRAINT sequence_steps_sequence_id_step_number_key UNIQUE (sequence_id, step_number);


--
-- Name: tracking_events tracking_events_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.tracking_events
    ADD CONSTRAINT tracking_events_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_campaign_leads_campaign_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_campaign_leads_campaign_id ON public.campaign_leads USING btree (campaign_id);


--
-- Name: idx_campaign_leads_lead_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_campaign_leads_lead_id ON public.campaign_leads USING btree (lead_id);


--
-- Name: idx_campaign_leads_sent_at; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_campaign_leads_sent_at ON public.campaign_leads USING btree (sent_at);


--
-- Name: idx_campaign_leads_status; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_campaign_leads_status ON public.campaign_leads USING btree (status);


--
-- Name: idx_campaign_leads_tracking_pixel; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_campaign_leads_tracking_pixel ON public.campaign_leads USING btree (tracking_pixel_id);


--
-- Name: idx_campaigns_created_at; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_campaigns_created_at ON public.campaigns USING btree (created_at);


--
-- Name: idx_campaigns_status; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_campaigns_status ON public.campaigns USING btree (status);


--
-- Name: idx_daily_stats_date; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_daily_stats_date ON public.daily_stats USING btree (date);


--
-- Name: idx_email_open_analysis_confidence; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_email_open_analysis_confidence ON public.email_open_analysis USING btree (confidence_score);


--
-- Name: idx_email_open_analysis_tracking_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_email_open_analysis_tracking_id ON public.email_open_analysis USING btree (tracking_id);


--
-- Name: idx_email_replies_lead_sequence; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_email_replies_lead_sequence ON public.email_replies USING btree (lead_id, sequence_id);


--
-- Name: idx_email_sequences_status; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_email_sequences_status ON public.email_sequences USING btree (status);


--
-- Name: idx_email_tracking_events_event_type; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_email_tracking_events_event_type ON public.email_tracking_events USING btree (event_type);


--
-- Name: idx_email_tracking_events_timestamp; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_email_tracking_events_timestamp ON public.email_tracking_events USING btree ("timestamp");


--
-- Name: idx_email_tracking_events_tracking_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_email_tracking_events_tracking_id ON public.email_tracking_events USING btree (tracking_id);


--
-- Name: idx_lead_group_memberships_group_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_lead_group_memberships_group_id ON public.lead_group_memberships USING btree (group_id);


--
-- Name: idx_lead_group_memberships_lead_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_lead_group_memberships_lead_id ON public.lead_group_memberships USING btree (lead_id);


--
-- Name: idx_lead_groups_name; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_lead_groups_name ON public.lead_groups USING btree (name);


--
-- Name: idx_lead_sequences_lead_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_lead_sequences_lead_id ON public.lead_sequences USING btree (lead_id);


--
-- Name: idx_lead_sequences_next_send_at; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_lead_sequences_next_send_at ON public.lead_sequences USING btree (next_send_at);


--
-- Name: idx_lead_sequences_sequence_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_lead_sequences_sequence_id ON public.lead_sequences USING btree (sequence_id);


--
-- Name: idx_lead_sequences_status; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_lead_sequences_status ON public.lead_sequences USING btree (status);


--
-- Name: idx_leads_company; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_leads_company ON public.leads USING btree (company);


--
-- Name: idx_leads_created_at; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_leads_created_at ON public.leads USING btree (created_at);


--
-- Name: idx_leads_email; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_leads_email ON public.leads USING btree (email);


--
-- Name: idx_leads_industry; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_leads_industry ON public.leads USING btree (industry);


--
-- Name: idx_leads_status; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_leads_status ON public.leads USING btree (status);


--
-- Name: idx_link_clicks_campaign_lead; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_link_clicks_campaign_lead ON public.link_clicks USING btree (campaign_lead_id);


--
-- Name: idx_link_clicks_clicked_at; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_link_clicks_clicked_at ON public.link_clicks USING btree (clicked_at);


--
-- Name: idx_link_clicks_sequence_email; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_link_clicks_sequence_email ON public.link_clicks USING btree (sequence_email_id);


--
-- Name: idx_link_clicks_tracking_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_link_clicks_tracking_id ON public.link_clicks USING btree (tracking_id);


--
-- Name: idx_link_clicks_url; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_link_clicks_url ON public.link_clicks USING btree (original_url);


--
-- Name: idx_sending_profiles_is_default; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_sending_profiles_is_default ON public.sending_profiles USING btree (is_default);


--
-- Name: idx_sending_profiles_sender_email; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_sending_profiles_sender_email ON public.sending_profiles USING btree (sender_email);


--
-- Name: idx_sequence_emails_lead_sequence_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_sequence_emails_lead_sequence_id ON public.sequence_emails USING btree (lead_sequence_id);


--
-- Name: idx_sequence_emails_status; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_sequence_emails_status ON public.sequence_emails USING btree (status);


--
-- Name: idx_sequence_emails_tracking_pixel; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_sequence_emails_tracking_pixel ON public.sequence_emails USING btree (tracking_pixel_id);


--
-- Name: idx_sequence_steps_sequence_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_sequence_steps_sequence_id ON public.sequence_steps USING btree (sequence_id);


--
-- Name: idx_sequence_steps_step_number; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_sequence_steps_step_number ON public.sequence_steps USING btree (sequence_id, step_number);


--
-- Name: idx_tracking_events_campaign_lead_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_tracking_events_campaign_lead_id ON public.tracking_events USING btree (campaign_lead_id);


--
-- Name: idx_tracking_events_event_type; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_tracking_events_event_type ON public.tracking_events USING btree (event_type);


--
-- Name: idx_tracking_events_type; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX idx_tracking_events_type ON public.tracking_events USING btree (event_type);


--
-- Name: ix_api_keys_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX ix_api_keys_id ON public.api_keys USING btree (id);


--
-- Name: ix_api_keys_key; Type: INDEX; Schema: public; Owner: user
--

CREATE UNIQUE INDEX ix_api_keys_key ON public.api_keys USING btree (key);


--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: user
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: ix_users_id; Type: INDEX; Schema: public; Owner: user
--

CREATE INDEX ix_users_id ON public.users USING btree (id);


--
-- Name: ix_users_username; Type: INDEX; Schema: public; Owner: user
--

CREATE UNIQUE INDEX ix_users_username ON public.users USING btree (username);


--
-- Name: campaign_leads update_campaign_stats_trigger; Type: TRIGGER; Schema: public; Owner: user
--

CREATE TRIGGER update_campaign_stats_trigger AFTER INSERT OR UPDATE ON public.campaign_leads FOR EACH ROW EXECUTE FUNCTION public.update_campaign_stats();


--
-- Name: api_keys api_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: campaign_leads campaign_leads_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaign_leads campaign_leads_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaign_leads
    ADD CONSTRAINT campaign_leads_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: campaigns campaigns_sending_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_sending_profile_id_fkey FOREIGN KEY (sending_profile_id) REFERENCES public.sending_profiles(id);


--
-- Name: email_open_analysis email_open_analysis_campaign_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_open_analysis
    ADD CONSTRAINT email_open_analysis_campaign_lead_id_fkey FOREIGN KEY (campaign_lead_id) REFERENCES public.campaign_leads(id) ON DELETE SET NULL;


--
-- Name: email_open_analysis email_open_analysis_lead_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_open_analysis
    ADD CONSTRAINT email_open_analysis_lead_sequence_id_fkey FOREIGN KEY (lead_sequence_id) REFERENCES public.lead_sequences(id) ON DELETE SET NULL;


--
-- Name: email_open_analysis email_open_analysis_sequence_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_open_analysis
    ADD CONSTRAINT email_open_analysis_sequence_email_id_fkey FOREIGN KEY (sequence_email_id) REFERENCES public.sequence_emails(id) ON DELETE SET NULL;


--
-- Name: email_replies email_replies_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_replies
    ADD CONSTRAINT email_replies_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: email_replies email_replies_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_replies
    ADD CONSTRAINT email_replies_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.email_sequences(id) ON DELETE CASCADE;


--
-- Name: email_sequences fk_email_sequences_sending_profile; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.email_sequences
    ADD CONSTRAINT fk_email_sequences_sending_profile FOREIGN KEY (sending_profile_id) REFERENCES public.sending_profiles(id) ON DELETE SET NULL;


--
-- Name: lead_group_memberships lead_group_memberships_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_group_memberships
    ADD CONSTRAINT lead_group_memberships_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.lead_groups(id) ON DELETE CASCADE;


--
-- Name: lead_group_memberships lead_group_memberships_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_group_memberships
    ADD CONSTRAINT lead_group_memberships_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: lead_sequences lead_sequences_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_sequences
    ADD CONSTRAINT lead_sequences_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE CASCADE;


--
-- Name: lead_sequences lead_sequences_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.lead_sequences
    ADD CONSTRAINT lead_sequences_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.email_sequences(id) ON DELETE CASCADE;


--
-- Name: link_clicks link_clicks_lead_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.link_clicks
    ADD CONSTRAINT link_clicks_lead_sequence_id_fkey FOREIGN KEY (lead_sequence_id) REFERENCES public.lead_sequences(id) ON DELETE SET NULL;


--
-- Name: link_clicks link_clicks_sequence_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.link_clicks
    ADD CONSTRAINT link_clicks_sequence_email_id_fkey FOREIGN KEY (sequence_email_id) REFERENCES public.sequence_emails(id) ON DELETE CASCADE;


--
-- Name: sequence_emails sequence_emails_lead_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_emails
    ADD CONSTRAINT sequence_emails_lead_sequence_id_fkey FOREIGN KEY (lead_sequence_id) REFERENCES public.lead_sequences(id) ON DELETE CASCADE;


--
-- Name: sequence_emails sequence_emails_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_emails
    ADD CONSTRAINT sequence_emails_step_id_fkey FOREIGN KEY (step_id) REFERENCES public.sequence_steps(id) ON DELETE CASCADE;


--
-- Name: sequence_steps sequence_steps_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.sequence_steps
    ADD CONSTRAINT sequence_steps_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.email_sequences(id) ON DELETE CASCADE;


--
-- Name: tracking_events tracking_events_campaign_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.tracking_events
    ADD CONSTRAINT tracking_events_campaign_lead_id_fkey FOREIGN KEY (campaign_lead_id) REFERENCES public.campaign_leads(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict YMz9PydSDM5C1XnVQmm72J0srODEqJgAIn7USnSAlkFOyB9WYW0wqMg2WKcsxdr

