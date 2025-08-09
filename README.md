# Email Automation System

A simple, scalable cold email automation system built with FastAPI, Next.js, and PostgreSQL.

## Features

- ✅ Send max 30 emails per day (configurable)
- ✅ Gmail Business Suite integration
- ✅ AI-powered email personalization with OpenAI
- ✅ Email tracking (opens and clicks)
- ✅ Clean dashboard interface
- ✅ Lead management
- ✅ Campaign management

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone <your-repo>
   cd email-automation
   cp .env.example .env
   ```

2. **Configure your .env file**:
   - Add your Gmail API credentials
   - Add your OpenAI API key
   - Update database settings

3. **Start with Docker**:
   ```bash
   docker-compose up -d
   ```

4. **Initialize database**:
   ```bash
   docker-compose exec -T db psql -U user -d email_automation < database/schema.sql
   ```

5. **Access the app**:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - API Docs: http://localhost:8000/docs

## Gmail API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Gmail API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs
6. Generate refresh token

## Development

### Backend (FastAPI)
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### Frontend (Next.js)
```bash
cd frontend
npm install
npm run dev
```

## Usage

1. **Import leads** via CSV or API
2. **Create a campaign** with AI prompt
3. **Send daily batch** (max 30 emails)
4. **Monitor progress** on dashboard

## Scaling

This MVP is designed to be easily scalable:
- Add email sequences
- Enhanced tracking
- Better analytics
- A/B testing
- Advanced lead scoring

## Tech Stack

- **Backend**: FastAPI, SQLAlchemy, PostgreSQL
- **Frontend**: Next.js 14, TypeScript, Tailwind CSS
- **APIs**: Gmail API, OpenAI API
- **Infrastructure**: Docker, PostgreSQL

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Submit pull request

## License

MIT License
