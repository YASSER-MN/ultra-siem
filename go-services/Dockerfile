FROM golang:latest AS builder

# Install git for module resolution and security updates
RUN apt-get update && apt-get install -y git ca-certificates tzdata && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency files and download modules first (layer caching)
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the simple bridge with optimizations and security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w" \
    -trimpath \
    -a \
    -installsuffix cgo \
    -o processor ./bridge

# Production stage with minimal footprint
FROM alpine:latest

# Install runtime dependencies and create non-root user
RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -g 1001 siem && \
    adduser -D -s /bin/sh -u 1001 -G siem siem

# Set up working directory with proper permissions
WORKDIR /app
COPY --from=builder /app/processor .
RUN chown siem:siem /app/processor && chmod +x /app/processor

# Switch to non-root user for security
USER siem

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep -f processor || exit 1

EXPOSE 8080

CMD ["./processor"] 