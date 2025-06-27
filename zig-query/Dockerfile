FROM alpine:latest as zig-builder

# Install build dependencies including GCC for C compilation
RUN apk add --no-cache \
    wget \
    tar \
    xz \
    gcc \
    musl-dev \
    libc-dev

# Install Zig
RUN wget -O zig.tar.xz https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz && \
    tar -xf zig.tar.xz && \
    mv zig-linux-x86_64-0.11.0 /opt/zig && \
    rm zig.tar.xz

WORKDIR /app
COPY . .

ENV PATH="/opt/zig:${PATH}"
# Build with release optimization, compatible CPU target
RUN zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl

FROM alpine:latest
RUN apk --no-cache add ca-certificates libc6-compat
WORKDIR /root/

COPY --from=zig-builder /app/zig-out/bin/query-engine .

EXPOSE 8080
CMD ["./query-engine"] 