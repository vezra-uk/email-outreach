// frontend/next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Only set fallback if environment variable is not already set
  env: process.env.NEXT_PUBLIC_API_URL ? {} : {
    NEXT_PUBLIC_API_URL: 'http://localhost:8000'
  }
}

module.exports = nextConfig
