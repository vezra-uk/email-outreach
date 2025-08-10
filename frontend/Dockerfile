FROM node:18-alpine

WORKDIR /app

# Accept build argument
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy all source files
COPY . .

# Create postcss.config.js if it doesn't exist
RUN echo 'module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } }' > postcss.config.js

# Build the app with the environment variable
RUN npm run build

# Expose port
EXPOSE 3000

# Start the production server
CMD ["npm", "start"]
