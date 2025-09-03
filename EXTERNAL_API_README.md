# External API Documentation

This document describes the external API endpoints for the Email Automation System, designed for integrating with external systems and third-party applications.

## Authentication

All external API endpoints require authentication using an API key. The API key must be provided in the request header:

```
X-API-Key: your_api_key_here
```

### Getting an API Key

1. **Login to your Email Automation System**
2. **Navigate to API Keys**: Click "More" → "API Keys" in the header
3. **Create New Key**: Click "Create API Key" button
4. **Name Your Key**: Give it a descriptive name (e.g., "My Website Integration")
5. **Copy & Save**: **Important!** Copy the full API key immediately - you'll only see it once

API keys are associated with your user account and inherit your permissions.

## Base URL

All external API endpoints are prefixed with:
```
https://your-domain.com/api/external
```

**Important:** Make sure to include `/api` in the path. The correct format is:
- ✅ `https://your-domain.com/api/external/leads`
- ❌ `https://your-domain.com/external/leads` (missing `/api`)

## Rate Limits

- **Default**: 1000 requests per hour per API key
- **Burst**: Up to 10 requests per second

## Endpoints

### 1. API Status Check

**GET** `/api/external/status`

Check if the API is operational and validate your API key.

**Headers:**
```
X-API-Key: your_api_key_here
```

**Response:**
```json
{
  "status": "active",
  "message": "External API is operational",
  "authenticated_user": "user@example.com",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 2. Create Single Lead

**POST** `/api/external/leads`

Create a single lead and optionally assign it to a campaign.

**Headers:**
```
X-API-Key: your_api_key_here
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "lead@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "company": "Example Corp",
  "title": "Marketing Director",
  "phone": "+1-555-0123",
  "website": "https://example.com",
  "industry": "Technology",
  "campaign_id": 1
}
```

**Fields:**
- `email` (required): Lead's email address
- `first_name` (optional): First name
- `last_name` (optional): Last name
- `company` (optional): Company name
- `title` (optional): Job title
- `phone` (optional): Phone number
- `website` (optional): Website URL
- `industry` (optional): Industry sector
- `campaign_id` (optional): ID of campaign to enroll lead in

**Response:**
```json
{
  "id": 123,
  "email": "lead@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "company": "Example Corp",
  "title": "Marketing Director",
  "phone": "+1-555-0123",
  "website": "https://example.com",
  "industry": "Technology",
  "status": "active",
  "created_at": "2024-01-15T10:30:00.000Z"
}
```

### 3. Create Multiple Leads (Bulk)

**POST** `/api/external/leads/bulk`

Create multiple leads in a single request.

**Headers:**
```
X-API-Key: your_api_key_here
Content-Type: application/json
```

**Request Body:**
```json
[
  {
    "email": "lead1@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "company": "Example Corp",
    "campaign_id": 1
  },
  {
    "email": "lead2@example.com",
    "first_name": "Jane",
    "last_name": "Smith",
    "company": "Another Corp",
    "campaign_id": 2
  }
]
```

**Response:**
```json
{
  "created": 2,
  "errors": [],
  "leads": [
    {
      "id": 124,
      "email": "lead1@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "company": "Example Corp",
      "status": "active",
      "created_at": "2024-01-15T10:30:00.000Z"
    },
    {
      "id": 125,
      "email": "lead2@example.com",
      "first_name": "Jane",
      "last_name": "Smith",
      "company": "Another Corp",
      "status": "active",
      "created_at": "2024-01-15T10:30:00.000Z"
    }
  ]
}
```

## Campaign Management

### 4. List All Campaigns

**GET** `/api/external/campaigns`

Get a list of campaigns with full details including all steps.

**Headers:**
```
X-API-Key: your_api_key_here
```

**Query Parameters:**
- `status` (optional): Filter by campaign status (`active`, `inactive`). Defaults to all campaigns.

**Response:**
```json
[
  {
    "id": 1,
    "name": "Product Demo Follow-up",
    "description": "3-step sequence for demo prospects",
    "status": "active",
    "created_at": "2024-01-10T09:00:00.000Z",
    "steps": [
      {
        "id": 1,
        "step_number": 1,
        "name": "Initial Follow-up",
        "subject": "Thanks for your interest in {{company_name}}",
        "template": "Hi {{first_name}}, thanks for checking out our demo...",
        "ai_prompt": "Write a friendly follow-up email",
        "delay_days": 0,
        "delay_hours": 0,
        "is_active": true,
        "include_previous_emails": false
      },
      {
        "id": 2,
        "step_number": 2,
        "name": "Second Touch",
        "subject": "Quick question about {{company_name}}",
        "template": "Hi {{first_name}}, I wanted to follow up...",
        "ai_prompt": "Write a helpful second touch email",
        "delay_days": 3,
        "delay_hours": 0,
        "is_active": true,
        "include_previous_emails": true
      }
    ]
  }
]
```

### 5. Get Single Campaign

**GET** `/api/external/campaigns/{campaign_id}`

Get detailed information about a specific campaign including all steps.

**Headers:**
```
X-API-Key: your_api_key_here
```

**Response:**
```json
{
  "id": 1,
  "name": "Product Demo Follow-up",
  "description": "3-step sequence for demo prospects",
  "status": "active",
  "created_at": "2024-01-10T09:00:00.000Z",
  "steps": [
    {
      "id": 1,
      "step_number": 1,
      "name": "Initial Follow-up",
      "subject": "Thanks for your interest in {{company_name}}",
      "template": "Hi {{first_name}}, thanks for checking out our demo...",
      "ai_prompt": "Write a friendly follow-up email",
      "delay_days": 0,
      "delay_hours": 0,
      "is_active": true,
      "include_previous_emails": false
    }
  ]
}
```

### 6. Create Campaign

**POST** `/api/external/campaigns`

Create a new email campaign with multiple steps.

**Headers:**
```
X-API-Key: your_api_key_here
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "New Product Launch Sequence",
  "description": "3-step sequence to introduce our new product",
  "sending_profile_id": 1,
  "steps": [
    {
      "step_number": 1,
      "name": "Introduction",
      "subject": "Introducing our new solution for {{company_name}}",
      "ai_prompt": "Write an exciting product introduction email. Focus on how our solution can help companies like {{company_name}} in the {{industry}} space. Keep it friendly but professional, mention that we'd love to show them a quick demo.",
      "delay_days": 0,
      "delay_hours": 0,
      "include_previous_emails": false
    },
    {
      "step_number": 2,
      "name": "Benefits Follow-up",
      "subject": "Quick question about {{company_name}}'s workflow",
      "ai_prompt": "Write a follow-up email that builds on the first email. Ask a thoughtful question about their current workflow or challenges in the {{industry}} industry. Mention 2-3 specific benefits our solution could provide. Keep it conversational and helpful.",
      "delay_days": 3,
      "delay_hours": 0,
      "include_previous_emails": true
    }
  ]
}
```

**Fields:**
- `name` (required): Campaign name
- `description` (optional): Campaign description
- `sending_profile_id` (optional): ID of sending profile to use
- `steps` (required): Array of campaign steps (minimum 1)

**Step Fields:**
- `step_number` (required): Step order (must be sequential starting from 1)
- `name` (required): Step name
- `subject` (optional): Email subject template (supports variables like {{first_name}})
- `ai_prompt` (required): AI prompt that describes what the email should say and accomplish
- `delay_days` (optional): Days to wait after previous step (default: 0)
- `delay_hours` (optional): Hours to wait after previous step (default: 0)
- `include_previous_emails` (optional): Include previous emails in thread (default: false)
- `template` (optional): Static email template - **deprecated, use ai_prompt instead**

**Note:** This system uses AI to generate personalized emails based on your `ai_prompt`. The AI will create unique, personalized content for each lead using their company information and context.

**Response:**
```json
{
  "id": 5,
  "name": "New Product Launch Sequence",
  "description": "3-step sequence to introduce our new product",
  "status": "active",
  "created_at": "2024-01-15T14:30:00.000Z"
}
```

### 7. Update Campaign

**PUT** `/api/external/campaigns/{campaign_id}`

Update an existing campaign. This replaces all steps with the new ones provided.

**Headers:**
```
X-API-Key: your_api_key_here
Content-Type: application/json
```

**Request Body:** Same format as Create Campaign

**Response:**
```json
{
  "id": 5,
  "name": "Updated Product Launch Sequence",
  "description": "Updated 3-step sequence to introduce our new product",
  "status": "active",
  "created_at": "2024-01-15T14:30:00.000Z"
}
```

### 8. Pause Campaign

**POST** `/api/external/campaigns/{campaign_id}/pause`

Pause a campaign to stop all email sending. Paused campaigns will not send any emails until resumed.

**Headers:**
```
X-API-Key: your_api_key_here
```

**Response:**
```json
{
  "message": "Campaign paused successfully",
  "campaign_id": 5,
  "status": "paused"
}
```

### 9. Resume Campaign

**POST** `/api/external/campaigns/{campaign_id}/unpause`

Resume a paused campaign to continue email sending.

**Headers:**
```
X-API-Key: your_api_key_here
```

**Response:**
```json
{
  "message": "Campaign unpaused successfully",
  "campaign_id": 5,
  "status": "active"
}
```

### 10. Delete Campaign

**DELETE** `/api/external/campaigns/{campaign_id}`

Delete a campaign (soft delete - sets status to inactive). Cannot delete campaigns with active leads enrolled.

**Headers:**
```
X-API-Key: your_api_key_here
```

**Response:**
```json
{
  "message": "Campaign deleted successfully",
  "campaign_id": 5,
  "status": "inactive"
}
```

## Campaign Assignment

When creating leads, you can optionally assign them to an email campaign by including the `campaign_id` field. This will:

1. Enroll the lead in the specified campaign
2. Schedule the first email to be sent in the next batch run (within 5 minutes)
3. Start the email sequence automatically

If no `campaign_id` is provided, the lead will be created but not enrolled in any campaigns.

## Error Responses

The API returns standard HTTP status codes and detailed error messages:

### 400 Bad Request
```json
{
  "detail": "Lead with email user@example.com already exists"
}
```

### 401 Unauthorized
```json
{
  "detail": "Invalid API key"
}
```

### 403 Forbidden
```json
{
  "detail": "User account is inactive"
}
```

### 404 Not Found
```json
{
  "detail": "Campaign 123 not found or inactive"
}
```

### 500 Internal Server Error
```json
{
  "detail": "Internal server error while creating lead"
}
```

## Integration Examples

### Python

```python
import requests

API_KEY = "your_api_key_here"
BASE_URL = "https://your-domain.com/api/external"

headers = {
    "X-API-Key": API_KEY,
    "Content-Type": "application/json"
}

# Create a single lead
lead_data = {
    "email": "prospect@company.com",
    "first_name": "John",
    "last_name": "Doe",
    "company": "Prospect Corp",
    "campaign_id": 1
}

response = requests.post(
    f"{BASE_URL}/leads",
    json=lead_data,
    headers=headers
)

if response.status_code == 200:
    print("Lead created successfully:", response.json())
else:
    print("Error:", response.json())

# Create a new campaign
campaign_data = {
    "name": "Product Demo Follow-up",
    "description": "3-step sequence for demo prospects",
    "steps": [
        {
            "step_number": 1,
            "name": "Initial Contact",
            "subject": "Thanks for your interest!",
            "ai_prompt": "Write a friendly introduction email. Thank them for their interest and briefly explain how our solution can help companies like {{company_name}}. Ask if they'd be open to a quick 15-minute demo.",
            "delay_days": 0,
            "delay_hours": 0
        },
        {
            "step_number": 2,
            "name": "Follow-up",
            "subject": "Quick follow-up",
            "ai_prompt": "Write a helpful follow-up email that references the first email. Share a brief success story or statistic that's relevant to their industry. Ask a thoughtful question about their current process.",
            "delay_days": 3,
            "delay_hours": 0
        }
    ]
}

campaign_response = requests.post(
    f"{BASE_URL}/campaigns",
    json=campaign_data,
    headers=headers
)

if campaign_response.status_code == 200:
    print("Campaign created successfully:", campaign_response.json())
else:
    print("Error:", campaign_response.json())

# List all active campaigns
campaigns_response = requests.get(
    f"{BASE_URL}/campaigns?status=active",
    headers=headers
)

if campaigns_response.status_code == 200:
    campaigns = campaigns_response.json()
    print(f"Found {len(campaigns)} active campaigns")
```

### JavaScript/Node.js

```javascript
const axios = require('axios');

const API_KEY = 'your_api_key_here';
const BASE_URL = 'https://your-domain.com/api/external';

const headers = {
    'X-API-Key': API_KEY,
    'Content-Type': 'application/json'
};

// Create multiple leads
const leadsData = [
    {
        email: 'lead1@company.com',
        first_name: 'Alice',
        company: 'Company A',
        campaign_id: 1
    },
    {
        email: 'lead2@company.com',
        first_name: 'Bob',
        company: 'Company B',
        campaign_id: 1
    }
];

axios.post(`${BASE_URL}/leads/bulk`, leadsData, { headers })
    .then(response => {
        console.log('Bulk creation result:', response.data);
    })
    .catch(error => {
        console.error('Error:', error.response?.data || error.message);
    });
```

### cURL

```bash
# Create a single lead
curl -X POST "https://your-domain.com/api/external/leads" \
  -H "X-API-Key: your_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "prospect@company.com",
    "first_name": "John",
    "last_name": "Doe",
    "company": "Prospect Corp",
    "campaign_id": 1
  }'

# Create a new campaign
curl -X POST "https://your-domain.com/api/external/campaigns" \
  -H "X-API-Key: your_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Product Demo Sequence",
    "description": "2-step follow-up sequence",
    "steps": [
      {
        "step_number": 1,
        "name": "Initial Follow-up",
        "subject": "Thanks for your demo request",
        "ai_prompt": "Write a friendly follow-up email thanking them for their interest in our demo. Mention that you'll be reaching out to schedule a time that works for them. Keep it warm and professional.",
        "delay_days": 0,
        "delay_hours": 0
      },
      {
        "step_number": 2,
        "name": "Second Touch",
        "subject": "Quick question about {{company_name}}",
        "ai_prompt": "Write a helpful second touch email. Ask a specific question about their current challenges or goals related to our solution. Offer to share a relevant case study or resource.",
        "delay_days": 3,
        "delay_hours": 0
      }
    ]
  }'

# Get all campaigns with full details
curl -X GET "https://your-domain.com/api/external/campaigns" \
  -H "X-API-Key: your_api_key_here"

# Get single campaign
curl -X GET "https://your-domain.com/api/external/campaigns/1" \
  -H "X-API-Key: your_api_key_here"

# Update campaign
curl -X PUT "https://your-domain.com/api/external/campaigns/1" \
  -H "X-API-Key: your_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Demo Sequence",
    "description": "Updated 2-step follow-up sequence",
    "steps": [
      {
        "step_number": 1,
        "name": "Updated Initial Follow-up",
        "subject": "Updated: Thanks for your demo request",
        "template": "Hi {{first_name}}, updated message...",
        "ai_prompt": "Write an updated friendly follow-up email",
        "delay_days": 0,
        "delay_hours": 0
      }
    ]
  }'

# Pause campaign
curl -X POST "https://your-domain.com/api/external/campaigns/1/pause" \
  -H "X-API-Key: your_api_key_here"

# Resume campaign
curl -X POST "https://your-domain.com/api/external/campaigns/1/unpause" \
  -H "X-API-Key: your_api_key_here"

# Delete campaign (soft delete)
curl -X DELETE "https://your-domain.com/api/external/campaigns/1" \
  -H "X-API-Key: your_api_key_here"

# Check API status
curl -X GET "https://your-domain.com/api/external/status" \
  -H "X-API-Key: your_api_key_here"
```

### PHP

```php
<?php
$apiKey = 'your_api_key_here';
$baseUrl = 'https://your-domain.com/api/external';

$headers = [
    'X-API-Key: ' . $apiKey,
    'Content-Type: application/json'
];

// Create a single lead
$leadData = [
    'email' => 'prospect@company.com',
    'first_name' => 'John',
    'last_name' => 'Doe',
    'company' => 'Prospect Corp',
    'campaign_id' => 1
];

$ch = curl_init($baseUrl . '/leads');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($leadData));
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$statusCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($statusCode === 200) {
    echo "Lead created successfully: " . $response;
} else {
    echo "Error: " . $response;
}
?>
```

## Webhooks (Optional)

The system can be configured to send webhooks for certain events:

- Lead created
- Campaign enrollment
- Email sent
- Email opened
- Email clicked
- Lead replied

Contact your system administrator to configure webhook endpoints.

## Support

For technical support or questions about the external API:

1. Check the main application logs for detailed error information
2. Verify your API key is active and valid
3. Ensure your requests match the expected format
4. Contact your system administrator

## Changelog

### Version 1.2.0 (2024-01-15)
- **NEW**: Campaign pause/resume functionality
- **NEW**: Pause campaigns to stop all email sending
- **NEW**: Resume paused campaigns to continue email sending
- **NEW**: Email batch service automatically skips paused campaigns
- **ENHANCED**: Frontend campaign management with pause/resume buttons
- **ENHANCED**: Campaign status indicators (active, paused, inactive)

### Version 1.1.0 (2024-01-15)
- **NEW**: Full campaign CRUD operations
- **NEW**: Create campaigns via API with multiple steps
- **NEW**: Update existing campaigns and replace steps
- **NEW**: Delete campaigns (soft delete to inactive)
- **NEW**: Get single campaign with full step details
- **NEW**: Filter campaigns by status (active/inactive/paused)
- **ENHANCED**: List campaigns endpoint now returns full details including steps
- **ENHANCED**: Comprehensive validation for campaign creation and updates
- **ENHANCED**: Protection against deleting campaigns with active leads

### Version 1.0.0 (2024-01-15)
- Initial release of external API
- Lead creation endpoints (single and bulk)
- Campaign assignment functionality  
- API key authentication
- Basic error handling and logging