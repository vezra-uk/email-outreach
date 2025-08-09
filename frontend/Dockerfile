FROM node:18-alpine

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy all source files
COPY . .

# Create postcss.config.js if it doesn't exist
RUN echo 'module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } }' > postcss.config.js

# Expose port
EXPOSE 3000

# Start the development server
CMD ["npm", "run", "dev"]
