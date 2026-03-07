#!/usr/bin/env bash
# DEPRECATED: This file is deprecated as of 2026-03-07
# Use orchestrator_devcontainer.py instead
# See legacy/README.md for details
#
# =============================================================================
# entrypoint.sh
#
# Runs on every container startup:
#   1. Log to stdout + /workdir/logs/docker_<ts>.log
#   2. Source version managers
#   3. Log toolchain versions
#   4. Validate workdir has config.yml, CLAUDE.md, and .claude/
#   5. For each configured project directory:
#        - Remove any existing .claude/ and CLAUDE.md (ensures clean state)
#        - Copy /workdir/.claude/        → <project>/.claude/
#        - Copy /workdir/CLAUDE.md       → <project>/CLAUDE.md
#   6. Validate disk space
#   7. Launch run_skills.py with graceful shutdown handling
# =============================================================================
set -euo pipefail

# =============================================================================
# Signal handling for graceful shutdown
# =============================================================================
cleanup() {
    echo ""
    echo "============================================================"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [WARN ] Caught termination signal"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [INFO ] Attempting graceful shutdown..."
    echo "============================================================"

    # Send SIGTERM to Python orchestrator if it's running
    if [[ -n "${PYTHON_PID:-}" ]] && kill -0 "${PYTHON_PID}" 2>/dev/null; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [INFO ] Terminating Python orchestrator (PID ${PYTHON_PID})..."
        kill -TERM "${PYTHON_PID}" 2>/dev/null || true

        # Wait up to 30 seconds for graceful shutdown
        for i in {1..30}; do
            if ! kill -0 "${PYTHON_PID}" 2>/dev/null; then
                echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [OK   ] Python orchestrator terminated gracefully"
                break
            fi
            sleep 1
        done

        # Force kill if still running
        if kill -0 "${PYTHON_PID}" 2>/dev/null; then
            echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [WARN ] Forcing termination..."
            kill -KILL "${PYTHON_PID}" 2>/dev/null || true
        fi
    fi

    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [INFO ] Shutdown complete"
    echo "============================================================"
    exit 143  # 128 + 15 (SIGTERM)
}

# Register signal handlers
trap cleanup SIGTERM SIGINT

TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
LOG_DIR="/workdir/logs"
DOCKER_LOG="${LOG_DIR}/docker_${TIMESTAMP}.log"
CONFIG_FILE="/workdir/config.yml"

mkdir -p "${LOG_DIR}"
exec > >(tee -a "${DOCKER_LOG}") 2>&1

log()  { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$1] ${*:2}"; }
info() { log "INFO " "$@"; }
ok()   { log "OK   " "$@"; }
err()  { log "ERROR" "$@"; }
sep()  { echo "============================================================"; }

# =============================================================================
# Source version managers (consolidated)
# =============================================================================
source /opt/init-env.sh

# =============================================================================
# Startup banner + toolchain versions
# =============================================================================
sep
info "Claude Parallel Skill Runner — starting"
info "Timestamp : ${TIMESTAMP}"
info "Log       : ${DOCKER_LOG}"
sep
info "Toolchain:"
info "  Java    : $(java -version 2>&1 | head -1)"
info "  Node.js : $(node --version 2>&1)"
info "  Python  : $(python --version 2>&1)"
info "  .NET    : $(dotnet --version 2>&1)"
info "  git     : $(git --version 2>&1)"
info "  SDK     : $(python -c 'import claude_agent_sdk; print(getattr(claude_agent_sdk,"__version__","installed"))' 2>&1)"
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
    err "  ✗ Bandit not found (Python analysis will be limited)"
    TOOL_ERRORS=1
else
    info "  ✓ Bandit   : $(bandit --version 2>&1 | head -1)"
fi

if ! command -v pylint &> /dev/null; then
    err "  ✗ Pylint not found (Python analysis will be limited)"
    TOOL_ERRORS=1
else
    info "  ✓ Pylint   : $(pylint --version 2>&1 | head -1)"
fi

# JavaScript tools
if ! npx eslint --version &> /dev/null; then
    err "  ✗ ESLint not found (JavaScript analysis will be limited)"
    TOOL_ERRORS=1
else
    info "  ✓ ESLint   : $(npx eslint --version 2>&1)"
fi

# .NET tools
if ! dotnet tool list --global | grep -q dotnet-outdated; then
    err "  ✗ dotnet-outdated not found (.NET analysis will be limited)"
    TOOL_ERRORS=1
else
    info "  ✓ dotnet-outdated : installed"
fi

if [[ "${TOOL_ERRORS}" -ne 0 ]]; then
    err "Some static analysis tools are missing!"
    err "This should not happen - tools are pre-installed in Dockerfile."
    err "Please rebuild the Docker image: docker compose build --no-cache"
    exit 1
fi

ok "All static analysis tools verified"
sep

# =============================================================================
# Validate workdir
# =============================================================================
info "Validating workdir..."
ERRORS=0
[[ ! -f "${CONFIG_FILE}" ]]     && err "Missing config.yml"  && ERRORS=1
[[ ! -f "/workdir/CLAUDE.md" ]] && err "Missing CLAUDE.md"   && ERRORS=1
[[ ! -d "/workdir/.claude" ]]   && err "Missing .claude/"    && ERRORS=1

if [[ "${ERRORS}" -ne 0 ]]; then
    err "Workdir must contain: config.yml  CLAUDE.md  .claude/"
    exit 1
fi

ok "config.yml, CLAUDE.md, and .claude/ found"
sep
info "config.yml:"
cat "${CONFIG_FILE}"
sep

# =============================================================================
# Read debug configuration and export DEBUG_MODE environment variable
# =============================================================================
DEBUG_ENABLED=$(python3 - << 'PYEOF'
import yaml
try:
    with open("/workdir/config.yml") as f:
        cfg = yaml.safe_load(f)
    debug_cfg = cfg.get("debug", {})
    enabled = debug_cfg.get("enabled", False)
    print("true" if enabled else "false")
except Exception:
    print("false")
PYEOF
)

export DEBUG_MODE="${DEBUG_ENABLED}"

if [[ "${DEBUG_MODE}" == "true" ]]; then
    info "Debug mode: ENABLED (verbose logging active)"
    info "  - SDK messages will not be truncated"
    info "  - Tool commands will show execution details"
    info "  - Log files will be significantly larger"
else
    info "Debug mode: disabled"
fi
sep

# =============================================================================
# Prepare each configured project directory
#
# Rename any existing .claude/ and CLAUDE.md so they cannot conflict, then
# copy the authoritative versions from the workdir root into each project.
# Skills run directly against these project directories — no sandboxes.
# =============================================================================
info "Preparing project directories..."

PROJECT_DIRS=$(python3 - << 'PYEOF'
import yaml
with open("/workdir/config.yml") as f:
    cfg = yaml.safe_load(f)
for t in cfg.get("targets", []):
    d = t.get("dir", "").strip()
    if d:
        print(d)
PYEOF
)

if [[ -z "${PROJECT_DIRS}" ]]; then
    err "No target directories found in config.yml"
    exit 1
fi

for DIR_NAME in ${PROJECT_DIRS}; do
    PROJECT_DIR="/workdir/${DIR_NAME}"

    if [[ ! -d "${PROJECT_DIR}" ]]; then
        err "  ${DIR_NAME}/ — not found, skipping"
        continue
    fi

    info "  ${DIR_NAME}/"

    # Remove any existing audit configuration files to ensure clean state
    # This prevents conflicts and ensures the authoritative versions are used
    if [[ -d "${PROJECT_DIR}/.claude" ]]; then
        if ! rm -rf "${PROJECT_DIR}/.claude" 2>&1; then
            err "    ✗ Failed to remove existing .claude/ - check permissions"
            err "    Aborting to prevent inconsistent configuration state"
            exit 1
        fi
        info "    Removed existing .claude/"
    fi

    if [[ -f "${PROJECT_DIR}/CLAUDE.md" ]]; then
        if ! rm -f "${PROJECT_DIR}/CLAUDE.md" 2>&1; then
            err "    ✗ Failed to remove existing CLAUDE.md - check permissions"
            err "    Aborting to prevent inconsistent configuration state"
            exit 1
        fi
        info "    Removed existing CLAUDE.md"
    fi

    # Copy authoritative audit configuration from workspace root
    if ! cp -r "/workdir/.claude" "${PROJECT_DIR}/.claude" 2>&1; then
        err "    ✗ Failed to copy .claude/ - check disk space and permissions"
        exit 1
    fi
    info "    ✓ .claude/ copied"

    if ! cp "/workdir/CLAUDE.md" "${PROJECT_DIR}/CLAUDE.md" 2>&1; then
        err "    ✗ Failed to copy CLAUDE.md - check disk space and permissions"
        exit 1
    fi
    info "    ✓ CLAUDE.md copied"

    # Create .analysis directory with proper permissions for sandboxed write access
    # This is the ONLY directory where skills can write output
    ANALYSIS_DIR="${PROJECT_DIR}/.analysis"
    if [[ ! -d "${ANALYSIS_DIR}" ]]; then
        mkdir -p "${ANALYSIS_DIR}"
        info "    ✓ Created .analysis/ (writable output directory)"
    else
        info "    ✓ .analysis/ exists"
    fi

    # Ensure .analysis is writable (defense in depth for sandboxing)
    chmod 755 "${ANALYSIS_DIR}" 2>/dev/null || true

    # Verify write access
    if ! touch "${ANALYSIS_DIR}/.write-test" 2>/dev/null; then
        err "    ✗ .analysis/ is not writable - skills will fail!"
        exit 1
    fi
    rm -f "${ANALYSIS_DIR}/.write-test"
    info "    ✓ .analysis/ is writable (sandboxed output directory)"
done

ok "Project directories ready."
sep

# =============================================================================
# Disk space validation
# =============================================================================
info "Checking available disk space..."

AVAILABLE_GB=$(df /workdir | tail -1 | awk '{print int($4/1024/1024)}')
REQUIRED_GB=5

if [[ $AVAILABLE_GB -lt $REQUIRED_GB ]]; then
    err "Insufficient disk space: ${AVAILABLE_GB}GB available"
    err "Recommend ${REQUIRED_GB}GB+ for analysis (logs + .analysis directories)"
    err "Please free up space or expand volume and try again."
    exit 1
fi

ok "Disk space OK: ${AVAILABLE_GB}GB available"
sep

# =============================================================================
# Security Model Summary (Honest Assessment)
# =============================================================================
info "Security Model (enforced at Docker level, not deny lists):"
info ""
info "  Layer 1: Network Access"
info "    ✓ Network: ENABLED (required for Claude API and vulnerability research)"
info "    ✓ Allows WebFetch/WebSearch for CVE data and security advisories"
info "    ⚠️  Code could theoretically be exfiltrated - review skills before running"
info "    ℹ️  Use isolated VMs for highly sensitive code"
info ""
info "  Layer 2: Container Isolation"
info "    ✓ Ephemeral containers (destroyed after each run)"
info "    ✓ Pre-installed tools with pinned versions (no runtime installs)"
info "    ✓ Limited blast radius (only affects mounted directories)"
info ""
info "  Layer 3: Filesystem Restrictions"
info "    ✓ Config files: READ-ONLY mounts (config.yml, CLAUDE.md, .claude/)"
info "    ✓ Source code: Currently READ-WRITE (TODO: make read-only)"
info "    ✓ Output: .analysis/ and logs/ are writable"
info ""
info "  bypassPermissions Mode:"
info "    ⚠️  Skills run with autonomous mode (no approval gates)"
info "    ⚠️  settings.json deny lists are DOCUMENTATION ONLY"
info "    ⚠️  Security is enforced by Docker, not permission rules"
info "    ✓  Safe because containers are isolated and ephemeral"
info ""
info "  Note: See .claude/settings.json and docker-compose.yml for details"
sep

# =============================================================================
# Launch runner
# =============================================================================
info "Launching run_skills.py..."
sep

# Launch Python orchestrator in background to capture PID
python3 /app/run_skills.py --audit-base-dir /workdir --config "${CONFIG_FILE}" &
PYTHON_PID=$!

# Wait for Python to complete
wait ${PYTHON_PID}
EXIT_CODE=$?

sep
[[ ${EXIT_CODE} -eq 0 ]] \
    && ok  "All skills completed successfully." \
    || err "One or more skills failed (exit code: ${EXIT_CODE})."
info "Logs → /workdir/logs/"
sep

exit ${EXIT_CODE}
