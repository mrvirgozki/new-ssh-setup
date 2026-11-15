# ==============================================================================
# VIRGOZKI SSH-WS (OPTIMIZED FOR CLOUD RUN)
# ==============================================================================

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# SYSTEM PACKAGES (Minimal & Clean)
# ------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    nginx \
    python3 \
    python3-minimal \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# SSH DIRECTORIES
# ------------------------------------------------------------------------------
RUN mkdir -p /run/sshd /var/run/sshd /var/log/ssh

# ------------------------------------------------------------------------------
# SSH USER
# ------------------------------------------------------------------------------
RUN useradd --create-home --shell /bin/bash virgozki \
    && echo 'virgozki:virgozki' | chpasswd

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------
RUN printf '%s\n' \
    'PermitRootLogin no' \
    'PasswordAuthentication yes' \
    'PubkeyAuthentication yes' \
    'UseDNS no' \
    'TCPKeepAlive yes' \
    'ClientAliveInterval 60' \
    'ClientAliveCountMax 2' \
    'MaxSessions 20' \
    'Compression no' \
    'X11Forwarding no' \
    'AllowTcpForwarding yes' \
    'Banner /etc/ssh/banner.txt' \
    >> /etc/ssh/sshd_config

# ------------------------------------------------------------------------------
# COPY APPLICATION FILES
# ------------------------------------------------------------------------------
COPY banner.txt /etc/ssh/banner.txt
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh

# ------------------------------------------------------------------------------
# PERMISSIONS + CONFIG VALIDATION
# ------------------------------------------------------------------------------
RUN chmod +x /entrypoint.sh \
    && nginx -t

# ------------------------------------------------------------------------------
# CLOUD RUN
# ------------------------------------------------------------------------------
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
