FROM node:24-alpine

# Create app directory
WORKDIR /app

# Copy package.json and install dependencies for analytics-service
COPY analytics-service/package*.json ./analytics-service/
RUN cd analytics-service && npm install --production

# Install kafkajs at root level so /app/lib/kafka.js can find it
RUN npm install kafkajs@2.2.4

# Copy service source and the shared lib into the image
COPY analytics-service/ ./analytics-service/
COPY lib/ ./lib/

# Set working directory to analytics-service
WORKDIR /app/analytics-service

# Expose port
EXPOSE 7100
ENV PORT=7100

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:7100/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))"

# Start the service
CMD ["node", "index.js"]