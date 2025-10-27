FROM node:24-slim
WORKDIR /app

# Install python and build tools for native modules
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

COPY auth-service/package*.json ./
# Clean install without using host node_modules or package-lock
RUN rm -rf node_modules package-lock.json || true
RUN npm cache clean --force
RUN npm install --production
# Rebuild bcrypt to ensure it matches the container's architecture
RUN npm rebuild bcrypt --build-from-source

COPY auth-service/ .

# Environment variables - only defaults, will be overridden by K8s secrets
ENV PORT=4000
ENV NODE_ENV=production

EXPOSE 4000
CMD ["node", "index.js"]
