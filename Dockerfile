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
    && nvm alias default 20" \
 && node --version && npm --version

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
# 6. Python runner packages
# =============================================================================
RUN pip install --no-cache-dir claude-agent-sdk pyyaml tenacity

# =============================================================================
# 6b. Static Analysis Tools (Pre-installed for security)
# =============================================================================
# Rationale: Pre-installing tools eliminates the security risk of auto-install
# scripts executing arbitrary code during skill execution. All tools are
# installed from verified sources during Docker build with pinned versions.

# Semgrep - SAST tool for security analysis (all languages)
RUN pip install --no-cache-dir semgrep==1.95.0

# Snyk CLI - Dependency vulnerability scanner (all languages)
RUN bash -c "source ${NVM_DIR}/nvm.sh && npm install -g snyk@1.1293.1"

# Trivy - Container and dependency scanner (all languages)
RUN wget -qO- https://github.com/aquasecurity/trivy/releases/download/v0.58.1/trivy_0.58.1_Linux-64bit.tar.gz \
    | tar -xzf - -C /usr/local/bin trivy \
 && chmod +x /usr/local/bin/trivy

# Python-specific tools
RUN pip install --no-cache-dir \
    bandit==1.7.10 \
    safety==3.2.11 \
    pylint==3.3.2 \
    mypy==1.13.0 \
    radon==6.0.1

# JavaScript/TypeScript tools
RUN bash -c "source ${NVM_DIR}/nvm.sh && npm install -g \
    eslint@9.16.0 \
    @typescript-eslint/parser@8.18.0 \
    @typescript-eslint/eslint-plugin@8.18.0"

# .NET tools (installed as global dotnet tools)
RUN dotnet tool install --global dotnet-outdated-tool --version 4.6.4 \
 && dotnet tool install --global security-scan --version 5.6.7

# Verify all tools are accessible
RUN semgrep --version \
 && snyk --version \
 && trivy --version \
 && bandit --version \
 && safety --version \
 && pylint --version \
 && mypy --version \
 && radon --version \
 && bash -c "source ${NVM_DIR}/nvm.sh && eslint --version" \
 && dotnet tool list --global

# =============================================================================
# 7. Source version managers in all bash sessions
# =============================================================================
# Source the consolidated initialization script from .bashrc
RUN echo 'source /opt/init-env.sh' >> /root/.bashrc

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

WORKDIR /workdir

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]
