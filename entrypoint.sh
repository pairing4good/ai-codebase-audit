#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh
#
# Runs on every container startup:
#   1. Log to stdout + /workdir/logs/docker_<ts>.log
#   2. Source version managers
#   3. Log toolchain versions
#   4. Validate workdir has config.yml, CLAUDE.md, and .claude/
#   5. For each configured project directory:
#        - Rename any existing .claude/  → OLD-.claude/
#        - Rename any existing CLAUDE.md → OLD-CLAUDE.md
#        - Copy /workdir/.claude/        → <project>/.claude/
#        - Copy /workdir/CLAUDE.md       → <project>/CLAUDE.md
#   6. Launch run_skills.py
# =============================================================================
set -euo pipefail

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
# Source version managers
# =============================================================================
export SDKMAN_DIR="/opt/sdkman"
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"

export NVM_DIR="/opt/nvm"
[[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"

export PYENV_ROOT="/opt/pyenv"
export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"
command -v pyenv > /dev/null && eval "$(pyenv init -)"

export DOTNET_ROOT="/opt/dotnet"
export PATH="${DOTNET_ROOT}:${PATH}"

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
        rm -rf "${PROJECT_DIR}/.claude"
        info "    Removed existing .claude/"
    fi

    if [[ -f "${PROJECT_DIR}/CLAUDE.md" ]]; then
        rm -f "${PROJECT_DIR}/CLAUDE.md"
        info "    Removed existing CLAUDE.md"
    fi

    # Copy authoritative audit configuration from workspace root
    cp -r "/workdir/.claude" "${PROJECT_DIR}/.claude"
    info "    ✓ .claude/ copied"

    cp "/workdir/CLAUDE.md" "${PROJECT_DIR}/CLAUDE.md"
    info "    ✓ CLAUDE.md copied"
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
# Launch runner
# =============================================================================
info "Launching run_skills.py..."
sep

python3 /app/run_skills.py --audit-base-dir /workdir --config "${CONFIG_FILE}"
EXIT_CODE=$?

sep
[[ ${EXIT_CODE} -eq 0 ]] \
    && ok  "All skills completed successfully." \
    || err "One or more skills failed (exit code: ${EXIT_CODE})."
info "Logs → /workdir/logs/"
sep

exit ${EXIT_CODE}
