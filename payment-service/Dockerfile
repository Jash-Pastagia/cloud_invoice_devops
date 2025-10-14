FROM node:24-alpine
WORKDIR /app
COPY payment-service/package*.json ./payment-service/
RUN cd payment-service && npm install --production

# Install kafkajs at root level so /app/lib/kafka.js can find it
RUN npm install kafkajs@2.2.4

COPY payment-service/ ./payment-service/
COPY lib/ ./lib/
WORKDIR /app/payment-service

# Environment variables
ENV PORT=6060
ENV NODE_ENV=production
ENV JWT_SECRET=supersecretdevops
ENV INVOICE_URL=http://invoice-service:5050

EXPOSE 6060
CMD ["node", "index.js"]
