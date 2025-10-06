# --- Stage 1: Build Stage ---
    FROM node:20-alpine AS build

    WORKDIR /usr/src/app
    
    COPY package*.json ./
    
    RUN npm install
    
    COPY . .
    
    FROM node:20-alpine AS production
    
    WORKDIR /usr/src/app
    
    COPY package*.json ./
    
    RUN npm install --omit=dev
    
    COPY --from=build /usr/src/app ./
    
    ENV NODE_ENV=production
    ENV PORT=5000
    
    EXPOSE 5000
    
    CMD ["npm", "start"]