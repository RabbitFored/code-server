# ==========================================
# STAGE 1: Pure Ubuntu Builder
# Compiles the raw VS Code engine from source
# ==========================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install Python, C++ compilers, build utilities, and the missing Kerberos library
RUN apt-get update && apt-get install -y \
    python3 \
    build-essential \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    libkrb5-dev \
    pkg-config \
    jq \
    rsync \
    curl

# Manually inject Node.js 22 into Ubuntu
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs

# Configure build environment variables
ENV PYTHON=python3
ENV VERSION="0.0.0-custom"

WORKDIR /src
COPY . .

# Run the official build pipeline
RUN npm install
RUN npm run build

# PATCH: Fix the upstream Gulp task naming mismatch in the bleeding-edge script
RUN sed -i 's/compile-copilot-extension-full-build/compile-copilot-extension-build/g' ci/build/build-vscode.sh

RUN npm run build:vscode
RUN npm run release
RUN npm run release:standalone

# ==========================================
# STAGE 2: The Final App Image
# Runs your freshly compiled custom editor on Ubuntu 22.04
# ==========================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install standard tools, Java (for Android SDK), and Flutter prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    curl \
    wget \
    nano \
    vim \
    bash \
    sudo \
    unzip \
    xz-utils \
    zip \
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# Create the secure 'coder' user
RUN useradd -m -s /bin/bash coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Download and configure the Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter \
    && chown -R coder:coder /usr/local/flutter

# Global PATH mapping for Flutter and your mapped Ubuntu host commands
ENV PATH="$PATH:/usr/local/flutter/bin:/home/coder/host_cmds"

# Copy ONLY the compiled, standalone app from the builder stage
COPY --from=builder /src/release-standalone /usr/local/lib/code-server

# Make the binary executable and link it globally
RUN chmod +x /usr/local/lib/code-server/bin/code-server \
    && ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server

USER coder

# The persistent directory where your daily project code will live
WORKDIR /home/coder/workspace

EXPOSE 8080

# Health check (helps CapRover monitor your custom build)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080 || exit 1

# Start the server and fix CapRover volume permissions on boot
CMD ["sh", "-c", "sudo chown -R coder:coder /home/coder/workspace && code-server --bind-addr 0.0.0.0:8080 ."]
