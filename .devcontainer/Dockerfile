# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC
ENV TZ=$TZ

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    aggregate \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    git \
    gh \
    iproute2 \
    ipset \
    iptables \
    jq \
    less \
    nano \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    rsync \
    sudo \
    unzip \
    wget \
    zip \
    zsh \
    fzf \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/npm-global /commandhistory \
 && chown -R vscode:vscode /usr/local/share/npm-global /commandhistory \
 && touch /commandhistory/.bash_history \
 && chown vscode:vscode /commandhistory/.bash_history

RUN ARCH=$(dpkg --print-architecture) \
 && curl -fsSL -o /tmp/git-delta.deb "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" \
 && dpkg -i /tmp/git-delta.deb \
 && rm /tmp/git-delta.deb

COPY scripts /usr/local/share/devcontainer/scripts
RUN chmod +x /usr/local/share/devcontainer/scripts/*.sh \
 && chown -R vscode:vscode /usr/local/share/devcontainer/scripts

RUN mkdir -p \
      /workspaces/default \
      /home/vscode/.claude \
      /home/vscode/.cursor \
      /home/vscode/.codex \
 && chown -R vscode:vscode \
      /workspaces/default \
      /home/vscode/.claude \
      /home/vscode/.cursor \
      /home/vscode/.codex

USER vscode

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/usr/local/share/npm-global/bin:/home/vscode/.local/bin:/home/vscode/.cursor/bin:$PATH
ENV SHELL=/bin/zsh
ENV CLAUDE_CONFIG_DIR=/home/vscode/.claude

RUN npm install -g @anthropic-ai/claude-code@latest @openai/codex@latest
RUN curl -fsS https://cursor.com/install | bash

WORKDIR /workspaces/default
