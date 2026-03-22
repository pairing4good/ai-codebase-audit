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

# SDKMAN (Java) - disable strict mode temporarily for sourcing
export SDKMAN_DIR="/opt/sdkman"
if [[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
    set +u  # Temporarily disable unbound variable errors
    source "${SDKMAN_DIR}/bin/sdkman-init.sh"
    set -u  # Re-enable if it was set
fi

# nvm (Node.js)
export NVM_DIR="/opt/nvm"
if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    set +u  # Temporarily disable unbound variable errors
    source "${NVM_DIR}/nvm.sh"
    set -u  # Re-enable if it was set
fi

# pyenv (Python)
export PYENV_ROOT="/opt/pyenv"
export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"
command -v pyenv > /dev/null && eval "$(pyenv init -)"

# .NET (side-by-side SDKs)
export DOTNET_ROOT="/opt/dotnet"
export PATH="${DOTNET_ROOT}:${PATH}"

# .NET tools (installed globally)
export PATH="${PATH}:/root/.dotnet/tools"
