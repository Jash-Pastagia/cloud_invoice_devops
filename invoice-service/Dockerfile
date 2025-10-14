# invoice-service/Dockerfile
FROM node:24-alpine

# Create app directory
WORKDIR /app

# Copy package.json and install deps for invoice-service only
COPY invoice-service/package*.json ./invoice-service/
RUN cd invoice-service && npm ci --only=production

# Install kafkajs at root level so /app/lib/kafka.js can find it
RUN npm install kafkajs@2.2.4

# Copy service source and the shared lib into the image
COPY invoice-service/ ./invoice-service/
COPY lib/ ./lib/

# Set working dir to where your index.js expects it, or keep /app and run invoice-service/index.js
WORKDIR /app/invoice-service

# Environment variables
ENV PORT=5050
ENV NODE_ENV=production
ENV JWT_SECRET=supersecretdevops
ENV DB_HOST=postgres
ENV DB_PORT=5432
ENV DB_NAME=invoicedb
ENV DB_USER=postgres
ENV DB_PASSWORD=postgres

EXPOSE 5050

CMD ["node", "index.js"]
