FROM node:24-alpine

# Create app directory
WORKDIR /app

# Copy package.json and install dependencies
COPY notification-service/package*.json ./
RUN npm install --production

# Copy service source code
COPY notification-service/ ./

# Copy shared library from repo root
COPY lib/ ./lib/

# Expose port and set environment
EXPOSE 7200
ENV PORT=7200

CMD ["node", "index.js"]