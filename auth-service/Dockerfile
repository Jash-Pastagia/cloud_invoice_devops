FROM node:24-slim
WORKDIR /app

# Install python and build tools for native modules
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

COPY auth-service/package*.json ./
# Clean install without using host node_modules or package-lock
RUN rm -rf node_modules package-lock.json || true
RUN npm install --production

COPY auth-service/ .

# Environment variables
ENV PORT=4000
ENV NODE_ENV=production
ENV JWT_SECRET=supersecretdevops
ENV DB_HOST=postgres
ENV DB_PORT=5432
ENV DB_NAME=invoicedb
ENV DB_USER=postgres
ENV DB_PASSWORD=postgres

EXPOSE 4000
CMD ["node", "index.js"]
