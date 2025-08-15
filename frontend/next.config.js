// frontend/next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    // Set API URL based on environment (without /api suffix since it's added in components)
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 
      (process.env.NODE_ENV === 'production' 
        ? 'https://outreach.vezra.co.uk'
        : 'http://localhost:8000')
  }
}

module.exports = nextConfig
