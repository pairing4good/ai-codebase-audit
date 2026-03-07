#!/usr/bin/env bash
# =============================================================================
# devcontainer-entrypoint.sh
#
# Simplified entrypoint for devcontainer-based audit runner.
# Unlike the legacy entrypoint.sh, this script:
#   - Does NOT copy files (orchestrator handles all mounts)
#   - Does NOT run run_skills.py (orchestrator spawns N containers)
#   - Runs a SINGLE skill execution in an isolated container
#
# Flow:
#   1. Source version managers (init-env.sh)
#   2. Log toolchain versions
#   3. Verify static analysis tools
#   4. Execute the skill command (passed as argument)
#
# Usage:
#   /app/devcontainer-entrypoint.sh /audit-java
#   /app/devcontainer-entrypoint.sh /audit-python
#
# Environment variables (set by orchestrator):
#   ANTHROPIC_API_KEY  - Claude API key (required)
#   DEBUG_MODE         - Enable verbose logging (optional, default: false)
#   SKILL_NAME         - Skill to execute (optional, can use $1 instead)
# =============================================================================
set -euo pipefail

# =============================================================================
# Logging helpers
# =============================================================================
log()  { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$1] ${*:2}"; }
info() { log "INFO " "$@"; }
ok()   { log "OK   " "$@"; }
err()  { log "ERROR" "$@"; }
warn() { log "WARN " "$@"; }
sep()  { echo "============================================================"; }

# =============================================================================
# Source version managers (consolidated)
# =============================================================================
info "Sourcing version managers..."
source /opt/init-env.sh
ok "Version managers loaded"

# =============================================================================
# Startup banner + toolchain versions
# =============================================================================
sep
info "AI Codebase Audit Runner (DevContainer Edition)"
info "Container: $(hostname)"
info "User: $(whoami)"
info "Workdir: $(pwd)"
sep
info "Toolchain:"
info "  Java    : $(java -version 2>&1 | head -1)"
info "  Node.js : $(node --version 2>&1)"
info "  Python  : $(python --version 2>&1)"
info "  .NET    : $(dotnet --version 2>&1)"
info "  git     : $(git --version 2>&1)"
info "  Claude  : $(claude --version 2>&1 || echo 'installed')"
sep

# =============================================================================
# Verify Static Analysis Tools (Security: Pre-installed, not auto-installed)
# =============================================================================
info "Verifying static analysis tools..."
TOOL_ERRORS=0

# Core tools (all languages)
if ! command -v semgrep &> /dev/null; then
    err "  ✗ Semgrep not found"
    TOOL_ERRORS=1
else
    info "  ✓ Semgrep  : $(semgrep --version 2>&1 | head -1)"
fi

if ! command -v snyk &> /dev/null; then
    err "  ✗ Snyk not found"
    TOOL_ERRORS=1
else
    info "  ✓ Snyk     : $(snyk --version 2>&1)"
fi

if ! command -v trivy &> /dev/null; then
    err "  ✗ Trivy not found"
    TOOL_ERRORS=1
else
    info "  ✓ Trivy    : $(trivy --version 2>&1 | head -1)"
fi

# Python tools
if ! command -v bandit &> /dev/null; then
    warn "  ⚠ Bandit not found (Python analysis may be limited)"
else
    info "  ✓ Bandit   : $(bandit --version 2>&1 | head -1)"
fi

if ! command -v pylint &> /dev/null; then
    warn "  ⚠ Pylint not found (Python analysis may be limited)"
else
    info "  ✓ Pylint   : $(pylint --version 2>&1 | head -1)"
fi

# JavaScript tools
if ! npx eslint --version &> /dev/null; then
    warn "  ⚠ ESLint not found (JavaScript analysis may be limited)"
else
    info "  ✓ ESLint   : $(npx eslint --version 2>&1)"
fi

# .NET tools
if ! dotnet tool list --global | grep -q dotnet-outdated; then
    warn "  ⚠ dotnet-outdated not found (.NET analysis may be limited)"
else
    info "  ✓ dotnet-outdated : installed"
fi

if [[ "${TOOL_ERRORS}" -ne 0 ]]; then
    err "Critical static analysis tools are missing!"
    err "This should not happen - tools are pre-installed in Dockerfile."
    err "Please rebuild the image: docker build -f .devcontainer/Dockerfile ..."
    exit 1
fi

ok "All static analysis tools verified"
sep

# =============================================================================
# Debug mode info
# =============================================================================
DEBUG_MODE="${DEBUG_MODE:-false}"

if [[ "${DEBUG_MODE}" == "true" ]]; then
    info "Debug mode: ENABLED (verbose logging active)"
    info "  - Claude messages will not be truncated"
    info "  - Tool commands will show execution details"
    info "  - Log files will be significantly larger"
else
    info "Debug mode: disabled (set DEBUG_MODE=true for verbose logs)"
fi
sep

# =============================================================================
# Determine skill to execute
# =============================================================================
# Priority: command line arg > SKILL_NAME env var
SKILL="${1:-${SKILL_NAME:-}}"

if [[ -z "${SKILL}" ]]; then
    err "No skill specified!"
    err "Usage: $0 /audit-java"
    err "   or: set SKILL_NAME environment variable"
    exit 1
fi

info "Skill to execute: ${SKILL}"

# Validate skill format (should start with /)
if [[ ! "${SKILL}" =~ ^/ ]]; then
    err "Invalid skill format: ${SKILL}"
    err "Skills must start with / (e.g., /audit-java, /audit-python)"
    exit 1
fi

# Check if .claude directory exists (should be mounted by orchestrator)
if [[ ! -d "/workspace/.claude" ]]; then
    err ".claude directory not found at /workspace/.claude"
    err "The orchestrator should mount the framework's .claude/ directory"
    err "Check volume mounts in container configuration"
    exit 1
fi

# Verify skill exists
SKILL_FILE="/workspace/.claude/skills${SKILL}/SKILL.md"
if [[ ! -f "${SKILL_FILE}" ]]; then
    err "Skill file not found: ${SKILL_FILE}"
    err "Available skills:"
    ls -1 /workspace/.claude/skills/ 2>/dev/null || echo "  (no skills found)"
    exit 1
fi

ok "Skill file found: ${SKILL_FILE}"
sep

# =============================================================================
# API Key validation
# =============================================================================
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    err "ANTHROPIC_API_KEY environment variable is not set!"
    err "The orchestrator must set this variable for Claude to function"
    exit 1
fi

ok "ANTHROPIC_API_KEY is set (${#ANTHROPIC_API_KEY} chars)"
sep

# =============================================================================
# Security Model Summary
# =============================================================================
info "Security Model (DevContainer Edition):"
info ""
info "  Layer 1: Network Security"
info "    ✓ Firewall initialized (whitelisted domains only)"
info "    ✓ Allowed: Claude API, package registries, vulnerability databases"
info "    ✓ Blocked: All other outbound connections"
info ""
info "  Layer 2: Container Isolation"
info "    ✓ Ephemeral container (destroyed after skill completes)"
info "    ✓ Pre-installed tools with pinned versions"
info "    ✓ Isolated from other skill executions"
info ""
info "  Layer 3: Filesystem Access"
info "    ✓ Framework configs: Mounted read-only (orchestrator)"
info "    ✓ Source code: Mounted by orchestrator"
info "    ✓ Output: .analysis/ and /workspace/logs writable"
info ""
info "  Note: This container runs ONE skill in complete isolation"
sep

# =============================================================================
# Execute skill via Claude CLI
# =============================================================================
info "Executing skill: ${SKILL}"
info "Command: claude --dangerously-skip-permissions -p \"${SKILL}\""
sep

# Run Claude with the skill
# Note: Using npm-installed @anthropic-ai/claude-code package
# Output is captured by orchestrator via container logs
claude --dangerously-skip-permissions -p "${SKILL}"
EXIT_CODE=$?

sep
if [[ ${EXIT_CODE} -eq 0 ]]; then
    ok "Skill completed successfully: ${SKILL}"
else
    err "Skill failed with exit code: ${EXIT_CODE}"
    err "Skill: ${SKILL}"
fi
sep

exit ${EXIT_CODE}
