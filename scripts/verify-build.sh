#!/bin/bash
# =============================================================================
# verify-build.sh — Verify DevContainer Image Build
# =============================================================================
# Verifies that all tools are installed correctly in the built devcontainer image.
#
# Usage:
#   ./scripts/verify-build.sh [image-tag]
#
# Arguments:
#   image-tag  Optional Docker image tag (default: audit-runner:local)
#
# Exit codes:
#   0 - All tools verified successfully
#   1 - One or more tools missing or version mismatch
#   2 - Docker image not found
# =============================================================================

set -euo pipefail

IMAGE_TAG="${1:-audit-runner:local}"

echo "============================================================"
echo "DevContainer Image Verification"
echo "============================================================"
echo "Image: $IMAGE_TAG"
echo "============================================================"
echo ""

# Check if image exists
if ! docker image inspect "$IMAGE_TAG" &>/dev/null; then
    echo "ERROR: Image $IMAGE_TAG not found"
    echo ""
    echo "Build the image first:"
    echo "  docker build -f .devcontainer/Dockerfile -t $IMAGE_TAG ."
    echo ""
    exit 2
fi

echo "✓ Image exists: $IMAGE_TAG"
echo ""

# Run verification inside container
docker run --rm "$IMAGE_TAG" bash -c "
set -e

echo '=== Verifying Language Runtimes ==='
echo ''

# Java
if command -v java &>/dev/null; then
    echo '✓ Java:    '\"$(java -version 2>&1 | head -1)\"
else
    echo '✗ Java: NOT FOUND'
    exit 1
fi

# Node.js
if command -v node &>/dev/null; then
    echo '✓ Node.js: '\"$(node --version)\"
else
    echo '✗ Node.js: NOT FOUND'
    exit 1
fi

# Python
if command -v python &>/dev/null; then
    echo '✓ Python:  '\"$(python --version)\"
else
    echo '✗ Python: NOT FOUND'
    exit 1
fi

# .NET
if command -v dotnet &>/dev/null; then
    echo '✓ .NET:    '\"$(dotnet --version)\"
else
    echo '✗ .NET: NOT FOUND'
    exit 1
fi

# git
if command -v git &>/dev/null; then
    echo '✓ git:     '\"$(git --version)\"
else
    echo '✗ git: NOT FOUND'
    exit 1
fi

# Claude CLI
if command -v claude &>/dev/null; then
    echo '✓ Claude:  installed'
else
    echo '✗ Claude: NOT FOUND'
    exit 1
fi

echo ''
echo '=== Verifying Static Analysis Tools ==='
echo ''

# Core tools
if command -v semgrep &>/dev/null; then
    echo '✓ Semgrep: '\"$(semgrep --version 2>&1 | head -1)\"
else
    echo '✗ Semgrep: NOT FOUND'
    exit 1
fi

if command -v snyk &>/dev/null; then
    echo '✓ Snyk:    '\"$(snyk --version 2>&1)\"
else
    echo '✗ Snyk: NOT FOUND'
    exit 1
fi

if command -v trivy &>/dev/null; then
    echo '✓ Trivy:   '\"$(trivy --version 2>&1 | head -1)\"
else
    echo '✗ Trivy: NOT FOUND'
    exit 1
fi

# Python tools
if command -v bandit &>/dev/null; then
    echo '✓ Bandit:  '\"$(bandit --version 2>&1 | head -1)\"
else
    echo '✗ Bandit: NOT FOUND'
    exit 1
fi

if command -v pylint &>/dev/null; then
    echo '✓ Pylint:  '\"$(pylint --version 2>&1 | head -1)\"
else
    echo '✗ Pylint: NOT FOUND'
    exit 1
fi

if command -v mypy &>/dev/null; then
    echo '✓ Mypy:    '\"$(mypy --version 2>&1)\"
else
    echo '✗ Mypy: NOT FOUND'
    exit 1
fi

# JavaScript tools
if npx eslint --version &>/dev/null; then
    echo '✓ ESLint:  '\"$(npx eslint --version 2>&1)\"
else
    echo '✗ ESLint: NOT FOUND'
    exit 1
fi

# .NET tools
if dotnet tool list --global | grep -q dotnet-outdated; then
    echo '✓ dotnet-outdated: installed'
else
    echo '✗ dotnet-outdated: NOT FOUND'
    exit 1
fi

if dotnet tool list --global | grep -q security-scan; then
    echo '✓ security-scan: installed'
else
    echo '✗ security-scan: NOT FOUND'
    exit 1
fi

echo ''
echo '=== Verifying Version Managers ==='
echo ''

# SDKMAN
if [ -d '/opt/sdkman' ]; then
    echo '✓ SDKMAN:  installed'
else
    echo '✗ SDKMAN: NOT FOUND'
    exit 1
fi

# nvm
if [ -d '/opt/nvm' ]; then
    echo '✓ nvm:     installed'
else
    echo '✗ nvm: NOT FOUND'
    exit 1
fi

# pyenv
if command -v pyenv &>/dev/null; then
    echo '✓ pyenv:   '\"$(pyenv --version)\"
else
    echo '✗ pyenv: NOT FOUND'
    exit 1
fi

# .NET installer
if [ -f '/opt/dotnet-install.sh' ]; then
    echo '✓ dotnet-install.sh: exists'
else
    echo '✗ dotnet-install.sh: NOT FOUND'
    exit 1
fi

echo ''
echo '=== Verifying User and Permissions ==='
echo ''

if [ \"\$(whoami)\" = 'node' ]; then
    echo '✓ Running as: node (non-root)'
else
    echo '✗ Running as: '\"\$(whoami)\" '(expected: node)'
    exit 1
fi

if [ -w '/workspace' ]; then
    echo '✓ Workspace: writable'
else
    echo '✗ Workspace: NOT WRITABLE'
    exit 1
fi

echo ''
echo '=== Verifying Entrypoint ==='
echo ''

if [ -f '/app/devcontainer-entrypoint.sh' ]; then
    echo '✓ Entrypoint: /app/devcontainer-entrypoint.sh exists'
else
    echo '✗ Entrypoint: NOT FOUND'
    exit 1
fi

if [ -x '/app/devcontainer-entrypoint.sh' ]; then
    echo '✓ Entrypoint: executable'
else
    echo '✗ Entrypoint: NOT EXECUTABLE'
    exit 1
fi

echo ''
echo '=== All Verifications Passed ==='
"

EXIT_CODE=$?

echo ""
echo "============================================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Verification PASSED"
    echo "============================================================"
    echo ""
    echo "Image $IMAGE_TAG is ready for use."
    echo ""
else
    echo "✗ Verification FAILED"
    echo "============================================================"
    echo ""
    echo "One or more tools are missing or incorrectly configured."
    echo "Rebuild the image: docker build -f .devcontainer/Dockerfile -t $IMAGE_TAG ."
    echo ""
    exit 1
fi
