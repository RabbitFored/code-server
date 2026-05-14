# ==========================================
# STAGE 1: The Builder
# Compiles your custom source code from GitHub
# ==========================================
FROM node:18-bullseye AS builder

# Install system dependencies required for compiling VS Code native C++ modules
RUN apt-get update && apt-get install -y \
    python3 \
    build-essential \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    pkg-config

WORKDIR /src
COPY . .

# Run the official build pipeline using NPM
RUN npm install
RUN npm run build
RUN npm run build:vscode
RUN npm run release
RUN npm run release:standalone

# ==========================================
# STAGE 2: The Final App Image
# Runs your freshly compiled custom editor
# ==========================================
FROM node:18-bullseye-slim

# Install standard terminal tools (incorporating Claude's suggestions)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    nano \
    vim \
    bash \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root 'coder' user for security
RUN adduser --disabled-password --gecos '' coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Copy ONLY your custom compiled app from the builder stage
COPY --from=builder /src/release-standalone /usr/local/lib/code-server

# Make the binary executable and link it globally
RUN chmod +x /usr/local/lib/code-server/bin/code-server \
    && ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server

USER coder
# Ensure this matches your CapRover Persistent Directory mapping!
WORKDIR /home/coder/workspace

EXPOSE 8080

# Health check (helps CapRover monitor if your custom build crashed)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080 || exit 1

# Start your custom server
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "."]
