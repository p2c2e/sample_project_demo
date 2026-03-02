FROM node:18-alpine

WORKDIR /app

# Copy dependency files first for layer caching
COPY package.json package-lock.json ./

# Install production dependencies only
RUN npm ci --production

# Copy application code
COPY app.js tracing.js ./
COPY public/ public/

EXPOSE 3000

CMD ["node", "app.js"]
