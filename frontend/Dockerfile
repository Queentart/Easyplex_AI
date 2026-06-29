# Use Node.js for development with hot-reloading
FROM node:20-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Expose port 80 (since docker-compose maps 3000:80)
EXPOSE 80

# Run the Vite development server on port 80
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "80"]
