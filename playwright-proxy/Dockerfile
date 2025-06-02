FROM node:18-slim

# Install dependencies for Playwright browsers
RUN apt-get update && apt-get install -y \
  wget libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxrandr2 libgbm1 libasound2 libpangocairo-1.0-0 libpango-1.0-0 libxdamage1 libxfixes3 libx11-xcb1 libxcb-dri3-0 libxcb-dri2-0 libxcb-present0 libxcb-sync1 libxshmfence1 libgl1 libgles2

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Install Playwright browsers
RUN npx playwright install --with-deps

ENV PORT=3000

CMD ["node", "index.js"]
