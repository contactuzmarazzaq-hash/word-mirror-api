# Use a lightweight Node.js image
FROM node:18-slim

# Set working directory
WORKDIR /app

# Copy package files first (for better layer caching)
COPY package*.json ./

# Install only production dependencies
RUN npm install --production

# Copy rest of the application code
COPY . .

# Expose the app port
EXPOSE 4004

# Start the server
CMD ["node", "server.js"]
