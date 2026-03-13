# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o /k6-dashboard .

# Runtime stage
FROM grafana/k6:latest

# Switch to root to install additional tools
USER root

# Copy the dashboard binary
COPY --from=builder /k6-dashboard /usr/local/bin/k6-dashboard

# Create app directory
WORKDIR /app

# Copy scripts (will be embedded, but also available for reference)
COPY scripts/ /app/scripts/

# Expose port
EXPOSE 8080

# Run the dashboard
ENTRYPOINT ["/usr/local/bin/k6-dashboard"]
