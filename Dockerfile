# syntax=docker/dockerfile:1
# ValzzHost - long-running Ubuntu SSH environment for Railway/Docker.
# Keep the Ubuntu base on the 24.04 LTS line and Node.js on an LTS line.

FROM ubuntu:24.04

ARG NODE_MAJOR=26
ARG PM2_VERSION=6

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color

# Base OS, SSH, developer tools and diagnostics. Keep this in one layer.
RUN set -eux; \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
      sed -i 's/^Components: .*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources; \
    fi; \
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
      bash-completion \
      build-essential \
      ca-certificates \
      curl \
      dnsutils \
      file \
      git \
      gnupg \
      htop \
      iproute2 \
      iputils-ping \
      less \
      locales \
      lsof \
      nano \
      net-tools \
      openssh-server \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      rsync \
      sudo \
      tar \
      tmux \
      tree \
      unzip \
      vim \
      wget \
      zip \
      jq \
      tini; \
    if apt-cache show neofetch >/dev/null 2>&1; then apt-get install -y --no-install-recommends neofetch; fi; \
    locale-gen en_US.UTF-8; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install the chosen Node.js major from NodeSource. Do not upgrade npm to
# "latest" separately; use the npm version shipped with the Node.js package.
RUN set -eux; \
    curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 20 \
      "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" -o /tmp/nodesource_setup.sh; \
    bash /tmp/nodesource_setup.sh; \
    rm -f /tmp/nodesource_setup.sh; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs libatomic1; \
    npm install --global "pm2@${PM2_VERSION}"; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /root/.npm /tmp/* /var/tmp/*; \
    node --version; \
    npm --version; \
    pm2 --version

# The default Ubuntu account is not needed. UID 1000 remains available.
RUN userdel -r ubuntu 2>/dev/null || true

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY valzz-welcome.sh /etc/profile.d/valzz-welcome.sh
COPY valzz-env.sh /etc/profile.d/valzz-env.sh
COPY server-status.sh /usr/local/bin/server-status
COPY backup-data.sh /usr/local/bin/backup-data
COPY ssh-healthcheck.sh /usr/local/bin/ssh-healthcheck

RUN chmod 0755 \
      /usr/local/bin/entrypoint.sh \
      /usr/local/bin/server-status \
      /usr/local/bin/backup-data \
      /usr/local/bin/ssh-healthcheck \
      /etc/profile.d/valzz-welcome.sh \
      /etc/profile.d/valzz-env.sh \
    && mkdir -p /run/sshd /data \
    && chmod 0755 /run/sshd

EXPOSE 22
STOPSIGNAL SIGTERM

# Useful for local Docker health status. Railway's HTTP healthcheck is not
# applicable to this SSH-only service.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["/usr/local/bin/ssh-healthcheck"]

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
