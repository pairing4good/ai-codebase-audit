# =============================================================================
# Claude Parallel Skill Runner
# =============================================================================
# Version managers:
#   Java    → SDKMAN   (sdk install java X | sdk use java X)
#   Node.js → nvm      (nvm install X | nvm use X)
#   Python  → pyenv    (pyenv install X | pyenv global X)
#   .NET    → dotnet-install.sh side-by-side (pin via global.json)
#
# Pre-installed:
#   Java    21 (Temurin) + 17 (Temurin)
#   Node.js 20 LTS       + 18 LTS
#   Python  3.12         + 3.11
#   .NET    8            + 6
# =============================================================================

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# =============================================================================
# 1. Base packages
# =============================================================================
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      bash build-essential bzip2 ca-certificates curl git gnupg \
      libbz2-dev libffi-dev liblzma-dev libncursesw5-dev libreadline-dev \
      libsqlite3-dev libssl-dev libxml2-dev libxmlsec1-dev \
      tini tk-dev unzip wget xz-utils zip zlib1g-dev \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 1b. Copy version manager initialization script
# =============================================================================
COPY init-env.sh /opt/init-env.sh
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
# 3. nvm + Node.js
# =============================================================================
ENV NVM_DIR=/opt/nvm
ENV PATH="${NVM_DIR}/versions/node/v20/bin:${PATH}"

RUN mkdir -p "${NVM_DIR}" \
 && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh \
    | NVM_DIR="${NVM_DIR}" bash

RUN bash -c "source ${NVM_DIR}/nvm.sh \
    && nvm install 20 \
    && nvm alias default 20 \
    && node --version && npm --version"

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
# 6. Python runner packages & setuptools (required for pkg_resources)
# =============================================================================
# Pin setuptools<70 because pkg_resources was removed in setuptools 70+
RUN pip install --no-cache-dir 'setuptools<70' wheel claude-agent-sdk pyyaml tenacity

# =============================================================================
# 6b. Static Analysis Tools (Pre-installed for security)
# =============================================================================
# Rationale: Pre-installing tools eliminates the security risk of auto-install
# scripts executing arbitrary code during skill execution. All tools are
# installed from verified sources during Docker build with pinned versions.

# Semgrep - SAST tool for security analysis (all languages)
# Note: Verify setuptools, then install semgrep
RUN python -c "import pkg_resources; print('pkg_resources found')" && \
    pip install --no-cache-dir semgrep==1.100.0 && \
    python -c "import pkg_resources; print('pkg_resources still available after semgrep install')"

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

# Verify all tools are accessible (except .NET tools, which need to be installed per-user)
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
# 7. Source version managers in all bash sessions
# =============================================================================
# (Will be configured for claude user in step 10)

# =============================================================================
# 8. Environment + git config
# =============================================================================
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    GIT_DISCOVERY_ACROSS_FILESYSTEM=1

RUN git config --global safe.directory '*' \
 && git config --global core.fileMode false

# =============================================================================
# 9. App files
# =============================================================================
RUN mkdir -p /app
COPY entrypoint.sh /app/entrypoint.sh
COPY run_skills.py /app/run_skills.py
RUN chmod +x /app/entrypoint.sh

# =============================================================================
# 10. Create non-root user (required for bypassPermissions mode)
# =============================================================================
# Claude Agent SDK refuses to run --dangerously-skip-permissions as root
RUN useradd -m -u 1000 -s /bin/bash claude \
 && mkdir -p /workdir \
 && chown -R claude:claude /workdir /app \
 && chown -R claude:claude ${SDKMAN_DIR} ${NVM_DIR} ${PYENV_ROOT} ${DOTNET_ROOT} \
 && echo 'source /opt/init-env.sh' >> /home/claude/.bashrc

USER claude

# .NET global tools must be installed as the user that will run them
RUN dotnet tool install --global dotnet-outdated-tool --version 4.6.4 \
 && dotnet tool install --global security-scan --version 5.6.7

# Add .NET tools to PATH for claude user
ENV PATH="/home/claude/.dotnet/tools:${PATH}"

WORKDIR /workdir

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
