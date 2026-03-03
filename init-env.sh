#!/bin/bash
# =============================================================================
# /opt/init-env.sh
# =============================================================================
# Consolidated initialization script for all language version managers.
#
# This script is sourced by:
# - /root/.bashrc (interactive shells)
# - entrypoint.sh (container startup)
# - Any RUN commands in Dockerfile that need version managers
#
# Version managers:
#   Java    → SDKMAN
#   Node.js → nvm
#   Python  → pyenv
#   .NET    → dotnet (no version switcher, side-by-side SDKs)
# =============================================================================

# SDKMAN (Java)
export SDKMAN_DIR="/opt/sdkman"
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"

# nvm (Node.js)
export NVM_DIR="/opt/nvm"
[[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"

# pyenv (Python)
export PYENV_ROOT="/opt/pyenv"
export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"
command -v pyenv > /dev/null && eval "$(pyenv init -)"

# .NET (side-by-side SDKs)
export DOTNET_ROOT="/opt/dotnet"
export PATH="${DOTNET_ROOT}:${PATH}"
