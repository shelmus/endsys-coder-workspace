FROM ubuntu:24.04

ARG NODE_VERSION=22
ARG KUBECTL_VERSION=1.32.3
ARG HELM_VERSION=3.17.3
ARG YQ_VERSION=4.45.1
ARG K9S_VERSION=0.50.6

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# System packages
RUN apt-get update && apt-get install -y \
    git \
    git-lfs \
    zsh \
    curl \
    wget \
    unzip \
    jq \
    ripgrep \
    fd-find \
    fzf \
    openssh-client \
    ca-certificates \
    gnupg \
    sudo \
    locales \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    htop \
    tmux \
    vim \
    less \
    tree \
    dnsutils \
    iputils-ping \
    netcat-openbsd \
    && locale-gen en_US.UTF-8 \
    && ln -sf /usr/bin/fdfind /usr/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Node.js via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Gemini CLI
RUN npm install -g @google/gemini-cli

# Bitwarden Secrets Manager CLI
RUN BWS_VERSION="1.0.0" \
    && curl -fsSLo /tmp/bws.zip \
    "https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-x86_64-unknown-linux-gnu-${BWS_VERSION}.zip" \
    && unzip -o /tmp/bws.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/bws \
    && rm /tmp/bws.zip

# kubectl
RUN curl -fsSLo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# Helm
RUN curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    | tar xz -C /usr/local/bin --strip-components=1 linux-amd64/helm

# yq
RUN curl -fsSLo /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
    && chmod +x /usr/local/bin/yq

# k9s
RUN curl -fsSL https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz \
    | tar xz -C /usr/local/bin k9s

# Create coder user
RUN useradd -m -s /bin/zsh -u 1000 -G sudo coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder

# Oh My Zsh for coder user
USER coder
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

WORKDIR /home/coder
USER coder
