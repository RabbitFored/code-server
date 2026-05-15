# ==========================================
# STAGE 2: The Final App Image
# Runs your freshly compiled custom editor on Ubuntu
# ==========================================
FROM ubuntu:22.04

# Prevent timezone/region prompts from freezing the Ubuntu package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install standard tools, Java, Flutter prerequisites, and CA Certificates
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

# Create a non-root 'coder' user for security (using useradd for Ubuntu compatibility)
RUN useradd -m -s /bin/bash coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Download and configure the Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter \
    && chown -R coder:coder /usr/local/flutter

# Add Flutter AND your new CapRover host mapping to the system PATH
ENV PATH="$PATH:/usr/local/flutter/bin:/home/coder/host_cmds"

# Copy ONLY your custom compiled app from the builder stage
COPY --from=builder /src/release-standalone /usr/local/lib/code-server

# Make the binary executable and link it globally
RUN chmod +x /usr/local/lib/code-server/bin/code-server \
    && ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server

USER coder
# Ensure this matches your CapRover Persistent Directory mapping!
WORKDIR /home/coder/workspace

EXPOSE 8080

# Health check (helps CapRover monitor your custom build)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080 || exit 1

# Start your custom server AND fix CapRover volume permissions on boot
CMD ["sh", "-c", "sudo chown -R coder:coder /home/coder/workspace && code-server --bind-addr 0.0.0.0:8080 ."]
