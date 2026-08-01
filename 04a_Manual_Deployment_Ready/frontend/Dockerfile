# Use Node.js 18 runtime as a parent image
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /app

# Install pnpm globally
RUN npm install -g pnpm

# Copy package files
COPY package*.json ./

# Copy lockfile if it exists (using wildcard to make it optional)
COPY pnpm-lock.yaml* ./

# Install dependencies
# Use --no-frozen-lockfile to allow regenerating lockfile if needed
# This is more flexible for development and CI environments
RUN pnpm install --no-frozen-lockfile

# Copy the rest of the application code
COPY . .

# Accept build argument for backend URL
ARG NEXT_PUBLIC_BACKEND_URL

# Set the environment variable for build
ENV NEXT_PUBLIC_BACKEND_URL=${NEXT_PUBLIC_BACKEND_URL}

# Build the Next.js application
RUN pnpm build

# Expose port 3000
EXPOSE 3000

# Start the application
CMD ["pnpm", "start"]
