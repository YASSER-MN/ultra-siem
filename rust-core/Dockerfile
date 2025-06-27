FROM rust:1.75-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    gcc \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files first for better layer caching
COPY Cargo.toml Cargo.lock ./

# Pre-build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy actual source code
COPY src/ ./src/

# Build with optimizations
RUN cargo build --release --locked

# Production stage
FROM debian:bookworm-slim

# Install runtime dependencies and create non-root user
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r siem && useradd -r -g siem siem

# Copy binary with proper permissions
COPY --from=builder /app/target/release/siem-rust-core /usr/local/bin/siem-core
RUN chmod +x /usr/local/bin/siem-core

# Switch to non-root user
USER siem

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD siem-core --health || exit 1

EXPOSE 8080

CMD ["siem-core"] 