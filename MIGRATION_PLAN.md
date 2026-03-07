# Migration Plan: DevContainer-Native Multi-Container Architecture (Build-from-Source)

## Overview
Transition from Docker Compose to **devcontainer-native architecture** where N isolated containers (one per repo+skill) are spawned programmatically. Each container is built from a committed Dockerfile (not prebuilt image) ensuring full transparency and reproducibility.

## Core Architecture

### Container Strategy
- Committed `.devcontainer/Dockerfile` defines the complete build (all tools, all versions)
- Python orchestrator spawns N containers dynamically (one per repo+skill)
- Each container built on-demand from Dockerfile (first run builds, subsequent runs use cache)
- Framework configs mounted read-only, outputs written to shared volume

### Build Philosophy
- NO prebuilt images from registries
- ALL build commands in plain text Dockerfile
- Complete build reproducibility from git clone
- Longer first startup (build time) acceptable for transparency

### Key Components
1. `.devcontainer/Dockerfile` - Multi-language base image with ALL tools (committed, plain text)
2. `.devcontainer/devcontainer.json` - Build configuration (references Dockerfile)
3. `orchestrator_devcontainer.py` - Spawns N containers via aiodocker, builds image if needed
4. `run_skill.sh` - Simplified per-container entrypoint
5. No GitHub Actions for image building (not needed)

## Migration Steps

### Phase 1: Create DevContainer Configuration (New Files)

#### 1.1 Create `.devcontainer/` directory structure ✅ COMPLETED
```
.devcontainer/
  Dockerfile              # Build definition (all tools, plain text)
  devcontainer.json       # Build configuration
  devcontainer-entrypoint.sh   # Simplified startup
  README.md              # Documents build process
```
**Status**: Directory created at `/Users/davidkessler/git/ai-codebase-audit/.devcontainer/`

#### 1.2 Create `.devcontainer/Dockerfile` ✅ COMPLETED
- ✅ Based on Anthropic's official `node:20` devcontainer base
- ✅ Added multi-language runtimes (Java/Node/Python/.NET)
- ✅ Integrated version managers (SDKMAN, nvm, pyenv, dotnet)
- ✅ Pre-installed 15+ static analysis tools with pinned versions
- ✅ Changed user from `claude` to `node` (Anthropic's convention)
- ✅ Changed working directory from `/workdir` to `/workspace` (Anthropic's standard)
- ✅ Installed Claude via npm (`@anthropic-ai/claude-code`) instead of Python SDK
- ✅ Added zsh + powerline10k shell configuration
- ✅ Included `init-firewall.sh` for network security
- ✅ Added devcontainer metadata labels
- ✅ Set ENTRYPOINT to `/app/devcontainer-entrypoint.sh`

**Status**: Created at `.devcontainer/Dockerfile` (12KB) and `.devcontainer/init-firewall.sh` (4.5KB)

**Key Changes from Original**:
- Base: `node:20` instead of `debian:bookworm-slim`
- User: `node` instead of `claude` (affects all volume mounts, permissions)
- Workdir: `/workspace` instead of `/workdir` (affects all paths)
- Claude: npm package instead of Python SDK
- Shell: zsh with powerline10k for better interactive experience

#### 1.3 Create `.devcontainer/devcontainer.json` ✅ COMPLETED
- ✅ Based on Anthropic's official devcontainer.json structure
- ✅ Build configuration with args (TZ, CLAUDE_CODE_VERSION, etc.)
- ✅ Network capabilities for firewall (--cap-add=NET_ADMIN, NET_RAW)
- ✅ VS Code extensions (claude-code, eslint, prettier, gitlens)
- ✅ Terminal settings (zsh default, bash available)
- ✅ Volume mounts for bash history and .claude config (per devcontainer ID)
- ✅ Environment variables:
  - Anthropic's: NODE_OPTIONS, CLAUDE_CONFIG_DIR, POWERLEVEL9K_DISABLE_GITSTATUS
  - Custom: ANTHROPIC_API_KEY, DEBUG_MODE, SKILL_NAME
- ✅ Firewall initialization via postStartCommand
- ✅ remoteUser: `node`
- ✅ workspaceFolder: `/workspace`

**Status**: Created at `.devcontainer/devcontainer.json` (1.7KB)

**Key Decisions Implemented**:
- Moved `init-env.sh` to `.devcontainer/` (matching Anthropic's pattern)
- Updated Dockerfile to reference `.devcontainer/init-env.sh`
- Enhanced `init-firewall.sh` with whitelisted domains for:
  - Claude API (api.anthropic.com)
  - Package registries (npm, PyPI, Maven, NuGet)
  - Vulnerability databases (nvd.nist.gov, cve.mitre.org, snyk.io)
- Environment variables follow Anthropic's pattern with ${localEnv:VAR:default}
- Orchestrator will handle workspace mounts (not in devcontainer.json)

#### 1.4 Create `.devcontainer/devcontainer-entrypoint.sh` ✅ COMPLETED
- ✅ Simplified version of legacy `entrypoint.sh` (242 lines vs 374 lines)
- ✅ No file copying - orchestrator handles all mounts
- ✅ Sources version managers via `/opt/init-env.sh`
- ✅ Logs toolchain versions (Java, Node, Python, .NET, git, Claude)
- ✅ Verifies static analysis tools (semgrep, snyk, trivy, bandit, pylint, eslint, dotnet tools)
- ✅ Validates ANTHROPIC_API_KEY presence
- ✅ Validates skill file existence
- ✅ Supports DEBUG_MODE environment variable
- ✅ Executes single skill via `claude --dangerously-skip-permissions -p "${SKILL}"`
- ✅ Accepts skill as command-line arg or SKILL_NAME env var
- ✅ Security model documentation in logs

**Status**: Created at `.devcontainer/devcontainer-entrypoint.sh` (8.2KB, 242 lines, executable)

**Key Differences from Legacy entrypoint.sh**:
- **Removed**: config.yml parsing (orchestrator handles this)
- **Removed**: Project directory loop and file copying (orchestrator mounts per-container)
- **Removed**: run_skills.py invocation (orchestrator spawns N containers directly)
- **Removed**: Signal handling for Python orchestrator (not needed for single skill)
- **Removed**: Disk space validation (orchestrator responsibility)
- **Added**: Claude CLI version check (`claude --version`)
- **Added**: Skill file validation before execution
- **Simplified**: Runs ONE skill in ONE isolated container (not N skills in one container)

#### 1.5 Create `.devcontainer/README.md`
- Document build-from-source approach
- Explain why no prebuilt images
- List all installed tools with versions
- Build time expectations (~10-15 min first run)

### Phase 2: Create New Orchestrator

#### 2.1 Install Python dependencies
```bash
pip install aiodocker pyyaml
```

#### 2.2 Create `orchestrator_devcontainer.py`

**Key Build Strategy**:
```python
async def ensure_image_built(docker, config):
    """Build devcontainer image from Dockerfile if not exists"""

    image_tag = config.get('image_tag', 'audit-runner:local')

    # Check if image exists
    try:
        await docker.images.inspect(image_tag)
        logger.info(f"Image {image_tag} exists (using cache)")
        return image_tag
    except:
        logger.info(f"Image {image_tag} not found, building from Dockerfile...")

    # Build from .devcontainer/Dockerfile
    # This reads the committed Dockerfile and builds locally
    build_stream = await docker.images.build(
        path=str(repo_root),  # ai-codebase-audit root
        dockerfile='.devcontainer/Dockerfile',
        tag=image_tag,
        rm=True,  # Remove intermediate containers
        stream=True,
    )

    # Stream build output
    async for chunk in build_stream:
        if 'stream' in chunk:
            logger.info(chunk['stream'].strip())

    logger.info(f"Image {image_tag} built successfully")
    return image_tag
```

**Container Spawn Strategy** (same as before):
- For each (project, skill) pair:
  - Spawn isolated container using built image
  - Mount framework configs read-only
  - Mount project directory and .analysis/ read-write
  - Run `/app/run_skill.sh <skill>` inside container
  - Wait for completion, collect logs
  - Remove container (ephemeral)
- Aggregate results into summary

**Key Difference from Original Plan**:
- Build image on first run (or when Dockerfile changes)
- Use local image tag (e.g., `audit-runner:local`)
- NO push to registry
- Docker caching makes subsequent builds fast

#### 2.3 Create `run_skill.sh` (simplified entrypoint)
- Sources `init-env.sh` for version managers
- Verifies tools available (fail fast if missing)
- Sets up environment variables
- Invokes Claude SDK with skill parameter: `claude --dangerously-skip-permissions "$SKILL_NAME"`
- Writes results to logs directory with proper naming

### Phase 3: Update Configuration Files

#### 3.1 Update config.yml (minimal changes)
```yaml
runner:
  model: claude-sonnet-4-6
  concurrency: 3
  max_turns: 20
  timeout: 300
  max_budget_usd: 10.0
  image_tag: audit-runner:local  # NEW: local build tag (not registry URL)
  rebuild: false                  # NEW: force rebuild even if image exists

targets:
  - dir: project-one
    skills:
      - /audit-java
      - /audit-javascript
  # ... rest unchanged
```

#### 3.2 Update .env.example
```bash
# Required
AUDIT_BASE_DIR=/path/to/audit-workspace
ANTHROPIC_API_KEY=sk-ant-api03-...

# Optional
DEBUG_MODE=false
FORCE_REBUILD=false  # Set to true to rebuild image on every run
```

#### 3.3 Keep .claude/ unchanged
- All skills and agents work as-is
- No modifications needed

### Phase 4: Update Build Process

#### 4.1 Add build verification script
Create `scripts/verify-build.sh`:
```bash
#!/bin/bash
# Verify all tools are installed correctly in built image

docker run --rm audit-runner:local bash -c "
  set -e
  echo '=== Verifying Language Runtimes ==='
  java -version
  node --version
  python --version
  dotnet --version

  echo '=== Verifying Static Analysis Tools ==='
  semgrep --version
  snyk --version
  trivy --version
  bandit --version
  eslint --version

  echo '=== Verifying Claude SDK ==='
  claude --version

  echo '=== All tools verified ==='
"
```

#### 4.2 Add local build script (for testing)
Create `scripts/build-local.sh`:
```bash
#!/bin/bash
# Build devcontainer image locally for testing

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "Building devcontainer image from .devcontainer/Dockerfile..."

docker build \
  -f .devcontainer/Dockerfile \
  -t audit-runner:local \
  --progress=plain \
  .

echo "Build complete. Verifying..."
./scripts/verify-build.sh
```

#### 4.3 Add clean script
Create `scripts/clean-images.sh`:
```bash
#!/bin/bash
# Remove locally built images to force rebuild

docker rmi audit-runner:local 2>/dev/null || true
docker image prune -f
echo "Local images cleaned. Next run will rebuild from Dockerfile."
```

### Phase 5: Update Documentation

#### 5.1 Update README.md

**Replace "Setup" section**:
```markdown
## Setup

### Prerequisites
- Docker installed and running
- Python 3.11+ with pip
- Git

### First-Time Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/your-org/ai-codebase-audit.git
   cd ai-codebase-audit
   ```

2. Install Python dependencies:
   ```bash
   pip install aiodocker pyyaml
   ```

3. Set environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your ANTHROPIC_API_KEY and AUDIT_BASE_DIR
   ```

4. First run will build the devcontainer image (~10-15 minutes):
   ```bash
   python orchestrator_devcontainer.py
   ```

   The Dockerfile will be built locally. Subsequent runs use Docker's cache
   and start much faster (~30 seconds).

### Build from Source Philosophy

This project builds containers from source (committed Dockerfile) rather than
pulling prebuilt images. This ensures:

- **Transparency**: All build steps visible in plain text
- **Reproducibility**: Anyone can rebuild from git clone
- **Security**: No dependency on external registries
- **Auditability**: Tool versions pinned in committed Dockerfile

First run takes 10-15 minutes to install all tools. Docker caching makes
subsequent runs start in ~30 seconds.

To force a rebuild:
```bash
export FORCE_REBUILD=true
python orchestrator_devcontainer.py
```

Or manually:
```bash
./scripts/clean-images.sh
python orchestrator_devcontainer.py
```
```

#### 5.2 Create docs/DEVCONTAINER-ARCHITECTURE.md
```markdown
# DevContainer Architecture

## Build-from-Source Approach

### Why Build from Source?

This project uses a **build-from-source** approach rather than prebuilt images:

1. **Transparency**: Every tool installation is visible in `.devcontainer/Dockerfile`
2. **Reproducibility**: `git clone` → `docker build` → identical environment
3. **Security**: No hidden dependencies or registry compromises
4. **Auditability**: Security teams can review exact build steps
5. **Version Control**: Tool versions pinned in committed Dockerfile

### Build Process

1. First run: `orchestrator_devcontainer.py` detects no local image
2. Builds from `.devcontainer/Dockerfile` (~10-15 minutes)
3. Tags as `audit-runner:local`
4. Spawns N containers from this local image
5. Subsequent runs: Docker cache makes builds ~30 seconds

### Container Lifecycle

For each (project, skill) combination:

```
1. Check if audit-runner:local image exists
   ├─ No: Build from .devcontainer/Dockerfile
   └─ Yes: Use cached image

2. Spawn container:
   - Name: audit-{project}-{skill}
   - Mount: .claude/ (read-only)
   - Mount: {project}/ (read-write)
   - Mount: logs/ (read-write)
   - Env: ANTHROPIC_API_KEY, SKILL_NAME, etc.

3. Execute: /app/run_skill.sh /audit-{language}
   - Runs 6-stage analysis
   - Writes to {project}/.analysis/{language}/
   - Writes to logs/task_{project}__{skill}_{ts}_{uid}.log

4. Cleanup: Remove container (ephemeral)

5. Aggregate: Collect all logs → summary_{ts}.txt
```

### Image Size Optimization

The built image is large (~3-4 GB) due to:
- 4 language runtimes (Java, Node, Python, .NET)
- 15+ static analysis tools
- Multiple SDK versions per language

This is intentional for:
- Self-contained analysis environment
- No runtime downloads (faster, more secure)
- Consistent tool versions across all runs

### Rebuild Triggers

Image rebuilds when:
1. `audit-runner:local` doesn't exist (first run)
2. `FORCE_REBUILD=true` environment variable
3. Manual: `./scripts/clean-images.sh`

Docker caching means rebuilds are fast unless:
- `.devcontainer/Dockerfile` changed
- Base image updates (debian:bookworm-slim)
- Tool version pins changed
```

#### 5.3 Update QUICKSTART.md
```markdown
## Quick Start

### 1. Setup (5 minutes)

```bash
# Clone repo
git clone https://github.com/your-org/ai-codebase-audit.git
cd ai-codebase-audit

# Install Python deps
pip install aiodocker pyyaml

# Configure
cp .env.example .env
# Edit .env: set ANTHROPIC_API_KEY and AUDIT_BASE_DIR
```

### 2. Prepare Workspace (5 minutes)

```bash
# Create workspace directory
mkdir -p ~/audit-workspace
export AUDIT_BASE_DIR=~/audit-workspace

# Copy framework files
cp config.yml CLAUDE.md ~/audit-workspace/
cp -r .claude ~/audit-workspace/

# Clone target repos
cd ~/audit-workspace
git clone https://github.com/example/project-one
git clone https://github.com/example/project-two

# Edit config.yml to list your projects
nano config.yml
```

### 3. First Run (10-15 minutes build + analysis time)

```bash
cd ~/git/ai-codebase-audit
python orchestrator_devcontainer.py

# First run builds devcontainer image (~10-15 min)
# Then runs analysis
```

### 4. Subsequent Runs (~5 minutes analysis time)

```bash
# Docker cache makes image build ~30 seconds
python orchestrator_devcontainer.py
```

### 5. View Results

```bash
# Summary
cat ~/audit-workspace/logs/summary_*.txt

# Detailed reports
ls ~/audit-workspace/project-one/.analysis/java/final-report/
```
```

### Phase 6: Deprecate Old Files

#### 6.1 Create `legacy/` directory
```bash
mkdir legacy
mv docker-compose.yml legacy/
mv run_skills.py legacy/
mv entrypoint.sh legacy/
```

#### 6.2 Add legacy/README.md
```markdown
# Legacy Docker Compose Approach

This directory contains the previous Docker Compose-based orchestration.

**Status**: Deprecated as of 2026-03-07

**Migration**: Use `orchestrator_devcontainer.py` in project root instead.

**Removal**: Planned for 2026-06-07 (3 months)

## Files

- `docker-compose.yml` - Old Docker Compose configuration
- `run_skills.py` - Old Python orchestrator (single container, N tasks)
- `entrypoint.sh` - Old container startup script

## Why Deprecated?

The new devcontainer approach provides:
- True container isolation (N containers, not N tasks)
- Build-from-source transparency (no prebuilt images)
- Standards compliance (official devcontainer spec)
- Better security (container-level isolation)
```

#### 6.3 Delete root Dockerfile
```bash
rm Dockerfile  # Replaced by .devcontainer/Dockerfile
```

#### 6.4 Add deprecation notice to legacy files
Add to top of each legacy file:
```bash
# DEPRECATED: This file is deprecated as of 2026-03-07
# Use orchestrator_devcontainer.py instead
# See legacy/README.md for details
```

### Phase 7: Add Developer Tools

#### 7.1 Create `scripts/` directory
```
scripts/
  build-local.sh         # Build image manually
  verify-build.sh        # Verify all tools installed
  clean-images.sh        # Remove local images
  test-single-skill.sh   # Test one project+skill
  watch-logs.sh          # Tail all logs live
```

#### 7.2 Create `scripts/test-single-skill.sh`
```bash
#!/bin/bash
# Test a single project+skill combination

PROJECT=${1:-project-one}
SKILL=${2:-/audit-java}

echo "Testing $PROJECT:$SKILL"

python3 -c "
import asyncio
import sys
sys.path.insert(0, '.')
from orchestrator_devcontainer import run_skill_container, load_config
import aiodocker
import logging

async def test():
    docker = aiodocker.Docker()
    config = load_config('$AUDIT_BASE_DIR/config.yml')
    logger = logging.getLogger()

    result = await run_skill_container(
        docker, '$PROJECT', '$SKILL', config, logger
    )

    await docker.close()
    print(result)

asyncio.run(test())
"
```

#### 7.3 Create `scripts/watch-logs.sh`
```bash
#!/bin/bash
# Watch all container logs in real-time

tail -f $AUDIT_BASE_DIR/logs/task_*.log
```

## File Changes Summary

### New Files (14)
- `.devcontainer/Dockerfile` (copied from root, enhanced)
- `.devcontainer/devcontainer.json`
- `.devcontainer/devcontainer-entrypoint.sh`
- `.devcontainer/README.md`
- `orchestrator_devcontainer.py` (replaces run_skills.py)
- `run_skill.sh` (simplified entrypoint)
- `scripts/build-local.sh`
- `scripts/verify-build.sh`
- `scripts/clean-images.sh`
- `scripts/test-single-skill.sh`
- `scripts/watch-logs.sh`
- `docs/DEVCONTAINER-ARCHITECTURE.md`
- `legacy/README.md`
- `.dockerignore` (optimize build context)

### Modified Files (4)
- `README.md` (rewrite setup/usage sections)
- `QUICKSTART.md` (updated steps)
- `config.yml` (add image_tag and rebuild options)
- `.env.example` (add FORCE_REBUILD)

### Moved to legacy/ (3)
- `docker-compose.yml`
- `run_skills.py`
- `entrypoint.sh`

### Deleted (1)
- `Dockerfile` (replaced by `.devcontainer/Dockerfile`)

### Unchanged (critical)
- `.claude/skills/` - All 4 language-specific skills work as-is
- `.claude/agents/` - All 7 specialized agents work as-is
- `.claude/settings.json` - Unchanged
- `CLAUDE.md` - Unchanged
- `init-env.sh` - Still used by devcontainer-entrypoint.sh

## Key Architectural Decisions

### 1. Build from Source
✅ All build commands in committed Dockerfile
- NO prebuilt images from GHCR or Docker Hub
- Complete transparency and reproducibility
- Longer first startup acceptable (10-15 min)
- Docker caching makes subsequent builds fast (~30 sec)

### 2. Container Isolation
✅ One container per repo+skill
- Containers spawned dynamically via Docker SDK
- Each fully isolated (processes, filesystem, network)
- Ephemeral containers (removed after completion)

### 3. DevContainer is Core
✅ Not optional
- Official devcontainer spec (devcontainer.json)
- Build configuration in plain text
- Compatible with VS Code, Codespaces
- Replaces Docker Compose completely

### 4. Local Image Tagging
✅ `audit-runner:local`
- Not pushed to any registry
- Built on developer's machine
- Cached by Docker for fast rebuilds
- Force rebuild with `FORCE_REBUILD=true`

### 5. Orchestrator Controls Build
✅ Python script handles everything
- Checks if image exists
- Builds from Dockerfile if needed
- Spawns N containers
- Collects outputs
- Cleans up containers

### 6. Security
✅ Build-from-source model
- All tool installations visible in Dockerfile
- Pinned versions (no surprises)
- No registry dependencies
- Auditable build process

## Build Time Expectations

### First Run (image doesn't exist)
- Dockerfile build: ~10-15 minutes
  - Base image pull: ~2 min
  - Language runtimes: ~5 min
  - Static analysis tools: ~3 min
  - SDK installation: ~2 min
  - Image compression: ~1 min
- Then analysis runs: ~5-10 min per project+skill
- **Total**: ~20-30 minutes for full config

### Subsequent Runs (image cached)
- Image check: ~1 second
- Container spawn: ~5 seconds each
- Analysis runs: ~5-10 min per project+skill
- **Total**: ~5-15 minutes for full config

### Rebuild (Dockerfile changed)
- Docker layer caching helps (~2-5 min)
- Only changed layers rebuild
- Unchanged layers from cache

## Benefits Over Prebuilt Image Approach

1. **Transparency**: Every RUN command visible in git
2. **Reproducibility**: Anyone can rebuild from clone
3. **Security**: No trust required in external registries
4. **Auditability**: Security teams review Dockerfile
5. **Version Control**: Tool version changes in git history
6. **No Registry Dependencies**: Works offline after first build
7. **Simplicity**: No CI/CD pipeline for image builds

## Tradeoffs Accepted

1. **Slower First Run**: 10-15 min build vs instant pull (acceptable per user request)
2. **Larger Git Repo**: Dockerfile is comprehensive (~300 lines)
3. **Local Storage**: ~4GB image on each developer machine
4. **Network Usage**: Downloads tools on each machine (vs once to registry)

## Testing Strategy

1. **Build Verification**: `./scripts/verify-build.sh` after build
2. **Single Skill Test**: `./scripts/test-single-skill.sh project-one /audit-java`
3. **Full Config Test**: `python orchestrator_devcontainer.py` with 2-3 projects
4. **Rebuild Test**: `FORCE_REBUILD=true python orchestrator_devcontainer.py`
5. **Cache Test**: Run twice, verify second is faster
6. **Cleanup Test**: Verify all containers removed after completion

## Timeline Estimate

- Phase 1 (DevContainer config): 2 hours
- Phase 2 (Orchestrator with build logic): 3 hours
- Phase 3 (Update configs): 1 hour
- Phase 4 (Build verification scripts): 1 hour
- Phase 5 (Documentation): 3 hours
- Phase 6 (Deprecation): 1 hour
- Phase 7 (Developer tools): 1 hour
- Testing: 2 hours
- **Total**: ~14 hours

## Success Criteria

✅ `.devcontainer/Dockerfile` committed with all tools
✅ First run builds image from Dockerfile (~10-15 min)
✅ Subsequent runs use cached image (~30 sec)
✅ Orchestrator spawns N isolated containers
✅ Each container runs skill to completion
✅ Outputs collected correctly (no collisions)
✅ All containers cleaned up after run
✅ Existing skills/agents work unchanged
✅ `./scripts/verify-build.sh` passes
✅ Documentation clear and accurate
✅ No external registry dependencies
