# =============================================================================
# AI Codebase Audit Runner - DevContainer Edition
# =============================================================================
# Built on Anthropic's official devcontainer base with multi-language support
#
# Base: node:20 (from Anthropic's official devcontainer)
# Extended with:
#   - Java (SDKMAN: 21 + 17)
#   - Python (pyenv: 3.12 + 3.11)
#   - .NET (side-by-side: 8 + 6)
#   - 15+ static analysis tools (pre-installed for security)
#
# Version managers:
#   Java    → SDKMAN   (sdk install java X | sdk use java X)
#   Node.js → nvm      (nvm install X | nvm use X)
#   Python  → pyenv    (pyenv install X | pyenv global X)
#   .NET    → dotnet-install.sh side-by-side (pin via global.json)
#
# Pre-installed language versions:
#   Node.js 20 LTS       + 18 LTS (from base + nvm)
#   Java    21 (Temurin) + 17 (Temurin)
#   Python  3.12         + 3.11
#   .NET    8            + 6
# =============================================================================

FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive

# =============================================================================
# 1. System Dependencies (Anthropic's base + multi-language build tools)
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
  # Anthropic's devcontainer tools
  less git procps sudo fzf zsh man-db unzip gnupg2 gh \
  iptables ipset iproute2 dnsutils aggregate jq nano vim \
  # Multi-language build dependencies
  bash build-essential bzip2 ca-certificates curl \
  libbz2-dev libffi-dev liblzma-dev libncursesw5-dev libreadline-dev \
  libsqlite3-dev libssl-dev libxml2-dev libxmlsec1-dev \
  tini tk-dev wget xz-utils zip zlib1g-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 1b. Copy version manager initialization script
# =============================================================================
COPY .devcontainer/init-env.sh /opt/init-env.sh
RUN chmod +x /opt/init-env.sh

# =============================================================================
# 2. SDKMAN + Java
# =============================================================================
ENV SDKMAN_DIR=/opt/sdkman
ENV JAVA_HOME=/opt/sdkman/candidates/java/current
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN curl -s "https://get.sdkman.io" | bash

RUN bash -c "source ${SDKMAN_DIR}/bin/sdkman-init.sh \
    && sdk install java 21.0.5-tem \
    && sdk default java 21.0.5-tem" \
 && java -version

RUN bash -c "source ${SDKMAN_DIR}/bin/sdkman-init.sh \
    && sdk install java 17.0.13-tem"

# =============================================================================
# 3. nvm + Node.js (additional versions beyond base node:20)
# =============================================================================
ENV NVM_DIR=/opt/nvm

RUN mkdir -p "${NVM_DIR}" \
 && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh \
    | NVM_DIR="${NVM_DIR}" bash

# Install Node 20 (already available from base, but also via nvm for consistency)
RUN bash -c "source ${NVM_DIR}/nvm.sh \
    && nvm install 20 \
    && nvm alias default 20"

# Install Node 18 as additional version
RUN bash -c "source ${NVM_DIR}/nvm.sh && nvm install 18"

# =============================================================================
# 4. pyenv + Python
# =============================================================================
ENV PYENV_ROOT=/opt/pyenv
ENV PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"

RUN git clone --depth=1 https://github.com/pyenv/pyenv.git "${PYENV_ROOT}"

RUN pyenv install 3.12 && pyenv global 3.12 && python --version
RUN pyenv install 3.11

# =============================================================================
# 5. .NET side-by-side
# =============================================================================
ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${DOTNET_ROOT}:${PATH}"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

RUN mkdir -p "${DOTNET_ROOT}" \
 && wget -qO /opt/dotnet-install.sh https://dot.net/v1/dotnet-install.sh \
 && chmod +x /opt/dotnet-install.sh \
 && /opt/dotnet-install.sh --channel 8.0 --install-dir "${DOTNET_ROOT}" \
 && /opt/dotnet-install.sh --channel 6.0 --install-dir "${DOTNET_ROOT}" \
 && dotnet --version

# =============================================================================
# 6. Python packages for orchestration
# =============================================================================
# Pin setuptools<70 because pkg_resources was removed in setuptools 70+
# Note: NOT installing claude-agent-sdk (using npm version instead per Q3)
RUN pip install --no-cache-dir 'setuptools<70' wheel pyyaml tenacity

# =============================================================================
# 6b. Static Analysis Tools (Pre-installed for security)
# =============================================================================
# Rationale: Pre-installing tools eliminates the security risk of auto-install
# scripts executing arbitrary code during skill execution. All tools are
# installed from verified sources during Docker build with pinned versions.

# Semgrep - SAST tool for security analysis (all languages)
RUN python -c "import pkg_resources; print('pkg_resources found')" && \
    pip install --no-cache-dir semgrep==1.100.0

# Snyk CLI - Dependency vulnerability scanner (all languages)
RUN bash -c "source ${NVM_DIR}/nvm.sh && npm install -g snyk@1.1293.1"

# Trivy - Container and dependency scanner (all languages)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        TRIVY_ARCH="ARM64"; \
    else \
        TRIVY_ARCH="64bit"; \
    fi && \
    TRIVY_VERSION="0.69.3" && \
    wget -O /tmp/trivy.tar.gz https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz && \
    tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy && \
    rm /tmp/trivy.tar.gz && \
    chmod +x /usr/local/bin/trivy

# Python-specific tools
RUN pip install --no-cache-dir \
    bandit==1.7.10 \
    'typer<0.15' \
    safety==3.2.11 \
    pylint==3.3.2 \
    mypy==1.13.0 \
    radon==6.0.1

# JavaScript/TypeScript tools
RUN bash -c "source ${NVM_DIR}/nvm.sh && npm install -g \
    eslint@9.16.0 \
    @typescript-eslint/parser@8.18.0 \
    @typescript-eslint/eslint-plugin@8.18.0"

# Verify all tools are accessible
RUN semgrep --version \
 && bash -c "source ${NVM_DIR}/nvm.sh && snyk --version" \
 && trivy --version \
 && bandit --version \
 && safety --version \
 && pylint --version \
 && mypy --version \
 && radon --version \
 && bash -c "source ${NVM_DIR}/nvm.sh && eslint --version"

# =============================================================================
# 7. Anthropic DevContainer: User Setup & Permissions
# =============================================================================
ARG USERNAME=node

# Ensure node user has access to shared directories
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set DEVCONTAINER environment variable
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

# Grant node user ownership of version managers and tools
RUN chown -R node:node ${SDKMAN_DIR} ${NVM_DIR} ${PYENV_ROOT} ${DOTNET_ROOT}

WORKDIR /workspace

# =============================================================================
# 8. Anthropic DevContainer: git-delta (enhanced diff viewer)
# =============================================================================
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# =============================================================================
# 9. Environment + git config
# =============================================================================
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    GIT_DISCOVERY_ACROSS_FILESYSTEM=1

RUN git config --global safe.directory '*' \
 && git config --global core.fileMode false

# =============================================================================
# 10. Switch to non-root user
# =============================================================================
USER node

# =============================================================================
# 11. Anthropic DevContainer: Shell Configuration (zsh + powerline10k)
# =============================================================================
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh
ENV SHELL=/bin/zsh

# Set the default editor
ENV EDITOR=nano
ENV VISUAL=nano

# Install zsh with powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -a "source /opt/init-env.sh" \
  -x

# Also add init-env.sh to bashrc for bash compatibility
RUN echo 'source /opt/init-env.sh' >> /home/node/.bashrc

# =============================================================================
# 12. Anthropic DevContainer: Install Claude Code (npm version)
# =============================================================================
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# =============================================================================
# 13. .NET global tools (must be installed as the user that will run them)
# =============================================================================
RUN dotnet tool install --global dotnet-outdated-tool --version 4.6.4 \
 && dotnet tool install --global security-scan --version 5.6.7

# Add .NET tools to PATH for node user
ENV PATH="/home/node/.dotnet/tools:${PATH}"

# =============================================================================
# 14. App files (simplified for devcontainer architecture)
# =============================================================================
USER root
RUN mkdir -p /app
COPY .devcontainer/devcontainer-entrypoint.sh /app/devcontainer-entrypoint.sh
RUN chmod +x /app/devcontainer-entrypoint.sh && \
  chown node:node /app/devcontainer-entrypoint.sh

# =============================================================================
# 15. Anthropic DevContainer: Firewall Setup
# =============================================================================
COPY .devcontainer/init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

# =============================================================================
# 16. Final setup
# =============================================================================
USER node

# DevContainer metadata labels
LABEL dev.containers.image.vendor="ai-codebase-audit"
LABEL dev.containers.image.version="1.0.0"
LABEL dev.containers.metadata="{\"name\":\"AI Codebase Audit Runner\",\"description\":\"Multi-language code audit runner with Claude Agent SDK based on Anthropic's official devcontainer\"}"

ENTRYPOINT ["/usr/bin/tini", "--", "/app/devcontainer-entrypoint.sh"]
