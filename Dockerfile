# ==========================================
# STAGE 1: The Builder
# Compiles your custom source code
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

# Run the official code-server build pipeline
RUN yarn
RUN yarn build
RUN yarn build:vscode
RUN yarn release
RUN yarn release:standalone

# ==========================================
# STAGE 2: The Final App Image
# Runs the compiled editor
# ==========================================
FROM node:18-bullseye-slim

# Install standard tools you might need inside the IDE terminal
RUN apt-get update && apt-get install -y git curl wget bash sudo && rm -rf /var/lib/apt/lists/*

# Create a non-root 'coder' user for security
RUN adduser --disabled-password --gecos '' coder
RUN echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Copy ONLY the compiled, standalone app from the builder stage
COPY --from=builder /src/release-standalone /usr/local/lib/code-server

# Make the binary executable and link it globally so it can be run
RUN chmod +x /usr/local/lib/code-server/bin/code-server \
    && ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server

USER coder
# This is where your actual daily project code will live
WORKDIR /home/coder/workspace

EXPOSE 8080

# Start your custom server
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "."]
