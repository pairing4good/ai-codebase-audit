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
   - Name: audit-{project}-{skill}-{timestamp}-{uid}
   - Mount: .claude/ (read-only, shared across all containers)
   - Mount: {project}/ (read-write, isolated per container)
   - Mount: {project}/.analysis/ (read-write, isolated per container)
   - Mount: logs/ (read-write, shared for centralized logging)
   - Env: ANTHROPIC_API_KEY, SKILL_NAME, MODEL, MAX_TURNS, etc.

3. Execute: /app/devcontainer-entrypoint.sh
   - Sources version managers (/opt/init-env.sh)
   - Verifies static analysis tools
   - Validates ANTHROPIC_API_KEY and skill file
   - Runs Claude CLI: claude --dangerously-skip-permissions -p "${SKILL}"
   - Executes 6-stage analysis workflow
   - Writes to {project}/.analysis/{language}/
   - Writes to logs/task_{project}__{skill}_{ts}_{uid}.log

4. Cleanup: Remove container (ephemeral, destroyed after completion)

5. Aggregate: Collect all logs → summary_{ts}.txt and summary_{ts}.json
```

## Architecture Comparison

### DevContainer vs Legacy Docker Compose

| Aspect | Legacy (Docker Compose) | DevContainer (Current) |
|--------|------------------------|------------------------|
| **Image Source** | Prebuilt from GHCR/Docker Hub | Built from committed Dockerfile |
| **Container Isolation** | 1 container, N tasks in parallel | N containers, 1 task each |
| **Build Time** | Instant (pull image) | 10-15 min first, ~30s cached |
| **Transparency** | Opaque (trust registry) | Full (audit Dockerfile) |
| **Security Model** | Trust external registry | Build and verify locally |
| **File Copying** | entrypoint.sh copies files | Orchestrator mounts directly |
| **Orchestration** | run_skills.py (SDK sessions) | orchestrator_devcontainer.py (Docker SDK) |
| **Skill Invocation** | SDK sessions in single container | Claude CLI in isolated containers |
| **Log Collection** | In-process logging | Container stdout/stderr collection |

### What Changed from Anthropic's Base

Our `.devcontainer/Dockerfile` is based on Anthropic's official `node:20` devcontainer but adds:

**Added:**
- Multi-language runtimes (Java via SDKMAN, Python via pyenv, .NET)
- Version managers (SDKMAN, nvm, pyenv, dotnet-install.sh)
- 15+ static analysis tools with pinned versions
- Network firewall with whitelisted domains (init-firewall.sh)
- Security-focused configuration

**Kept from Anthropic:**
- Base image: `node:20` (not `debian:bookworm-slim`)
- User: `node` (not `claude`)
- Working directory: `/workspace` (not `/workdir`)
- Claude installation: npm package `@anthropic-ai/claude-code`
- Shell: zsh with powerline10k

**Modified:**
- ENTRYPOINT: `/app/devcontainer-entrypoint.sh` (our custom entrypoint)
- Volume mounts: Handled by orchestrator (not in devcontainer.json)
- Environment variables: Passed by orchestrator per container

## Image Size Optimization

The built image is large (~3-4 GB) due to:
- 4 language runtimes (Java, Node, Python, .NET)
- 15+ static analysis tools (Semgrep, Snyk, Trivy, Bandit, ESLint, etc.)
- Multiple SDK versions per language (Java 21+17, Node 20+18, Python 3.12+3.11, .NET 8+6)

This is **intentional** for:
- Self-contained analysis environment
- No runtime downloads (faster, more secure)
- Consistent tool versions across all runs
- Offline operation after first build

## Network Security

The DevContainer includes a network firewall (`init-firewall.sh`) that whitelists specific domains:

**Whitelisted Domains:**
- `api.anthropic.com` - Claude API
- Package registries: `registry.npmjs.org`, `pypi.org`, `repo.maven.apache.org`, `api.nuget.org`
- Vulnerability databases: `nvd.nist.gov`, `cve.mitre.org`, `snyk.io`, `github.com`
- CDNs: `cloudflare.com`, `fastly.net`

**Firewall Behavior:**
- Initialized via `postStartCommand` in devcontainer.json
- Requires `--cap-add=NET_ADMIN` and `--cap-add=NET_RAW` capabilities
- Blocks all outbound traffic except whitelisted domains
- Logs blocked connections for security auditing

**Why Network Access is Enabled:**
- Claude API calls (required for analysis)
- Vulnerability research (CVE databases, security advisories)
- Up-to-date security information (OWASP, GitHub advisories, Snyk, NVD)
- Static analysis tools may check online databases (Snyk, Trivy)

**Trade-off:**
- Enables comprehensive security audits
- Allows potential data exfiltration (mitigated by firewall whitelist)
- Review skills before running, use isolated VMs for sensitive code

## Rebuild Triggers

Image rebuilds when:

1. **`audit-runner:local` doesn't exist** (first run)
2. **`FORCE_REBUILD=true` environment variable**
   ```bash
   export FORCE_REBUILD=true
   python3 orchestrator_devcontainer.py
   ```
3. **`runner.rebuild: true` in config.yml**
   ```yaml
   runner:
     rebuild: true  # Force rebuild
   ```
4. **Manual cleanup**
   ```bash
   ./scripts/clean-images.sh
   python3 orchestrator_devcontainer.py
   ```

Docker caching means rebuilds are fast unless:
- `.devcontainer/Dockerfile` changed
- Base image updates (`node:20`)
- Tool version pins changed

## Volume Mounts

Each container receives isolated mounts:

| Host Path | Container Path | Mode | Purpose |
|-----------|----------------|------|---------|
| `{AUDIT_BASE_DIR}/.claude/` | `/workspace/.claude` | `ro` | Framework configs (shared, read-only) |
| `{AUDIT_BASE_DIR}/{project}/` | `/workspace/{project}` | `rw` | Project source (isolated, read-write) |
| `{AUDIT_BASE_DIR}/{project}/.analysis/` | `/workspace/{project}/.analysis` | `rw` | Analysis output (isolated, read-write) |
| `{AUDIT_BASE_DIR}/logs/` | `/workspace/logs` | `rw` | Centralized logs (shared, read-write) |

**Key Points:**
- Framework configs (`.claude/`) are shared read-only across all containers
- Project directories are isolated per container (no collisions)
- Logs are centralized for easy aggregation
- No file copying needed (orchestrator handles mounts)

## Environment Variables

The orchestrator passes these environment variables to each container:

**Required:**
- `ANTHROPIC_API_KEY` - API key from environment
- `SKILL_NAME` - Skill to execute (e.g., `/audit-java`)

**From config.yml:**
- `MODEL` - Model to use (e.g., `claude-sonnet-4-6`)
- `MAX_TURNS` - Max agent turns (e.g., `20`)
- `TIMEOUT` - Per-task timeout in seconds (e.g., `300`)
- `MAX_BUDGET_USD` - Per-task spending limit (e.g., `10.0`)

**Optional:**
- `DEBUG_MODE` - Verbose logging toggle (default: `false`)

**Automatic (for logging):**
- `TASK_TIMESTAMP` - ISO 8601 timestamp for log file naming
- `TASK_UID` - Unique 8-char ID for log file naming

**Devcontainer-specific:**
- `NODE_OPTIONS` - Node.js options (e.g., heap size)
- `CLAUDE_CONFIG_DIR` - Claude config directory path
- `DEVCONTAINER` - Flag indicating devcontainer environment

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

## Build Time Expectations

### First Run (image doesn't exist)
- Dockerfile build: ~10-15 minutes
  - Base image pull: ~2 min
  - Language runtimes: ~5 min (Java, Node, Python, .NET)
  - Static analysis tools: ~3 min (Semgrep, Snyk, Trivy, etc.)
  - SDK installation: ~2 min (Claude, version managers)
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

## Testing Strategy

1. **Build Verification**: `./scripts/verify-build.sh` after build
   - Verifies all language runtimes installed
   - Verifies all static analysis tools installed
   - Verifies version managers working
   - Verifies user and permissions correct

2. **Single Skill Test**: Test one project+skill combination
   ```bash
   # Set environment
   export AUDIT_BASE_DIR=~/code-audits
   export ANTHROPIC_API_KEY=sk-ant-...

   # Edit config.yml to include only one project+skill
   nano ~/code-audits/config.yml

   # Run orchestrator
   python3 orchestrator_devcontainer.py
   ```

3. **Full Config Test**: Run with 2-3 projects
   ```bash
   python3 orchestrator_devcontainer.py
   ```

4. **Rebuild Test**: Force rebuild and verify
   ```bash
   export FORCE_REBUILD=true
   python3 orchestrator_devcontainer.py
   ```

5. **Cache Test**: Run twice, verify second is faster
   ```bash
   # First run
   python3 orchestrator_devcontainer.py

   # Second run (should be ~30s faster)
   python3 orchestrator_devcontainer.py
   ```

6. **Cleanup Test**: Verify all containers removed after completion
   ```bash
   # Check running containers (should be empty after run)
   docker ps -a | grep audit-
   ```

## Troubleshooting

### Build Failures

**Symptom**: Docker build fails during image creation

**Solutions**:
1. Check Docker disk space: `docker system df`
2. Prune old images: `docker image prune -a`
3. Retry with no cache: `./scripts/build-local.sh --no-cache`
4. Check Docker daemon logs for specific errors

### Container Spawn Failures

**Symptom**: Orchestrator fails to spawn containers

**Solutions**:
1. Verify image exists: `docker images | grep audit-runner`
2. Check Docker daemon running: `docker info`
3. Verify environment variables set: `echo $AUDIT_BASE_DIR`
4. Check Docker logs: `docker logs <container-id>`

### Tool Verification Failures

**Symptom**: Container starts but tools are missing

**Solutions**:
1. Force rebuild: `./scripts/clean-images.sh && python3 orchestrator_devcontainer.py`
2. Verify build: `./scripts/verify-build.sh`
3. Check Dockerfile for tool installation commands
4. Review container logs for installation errors

### Network Firewall Issues

**Symptom**: Container can't access APIs or package registries

**Solutions**:
1. Check firewall initialization: `grep "init-firewall.sh" logs/docker_*.log`
2. Verify NET_ADMIN capability granted
3. Add domain to whitelist in `init-firewall.sh`
4. Temporarily disable firewall for testing (edit devcontainer.json)

## Maintenance

### Updating Tool Versions

1. Edit `.devcontainer/Dockerfile` and update version pins
2. Force rebuild:
   ```bash
   ./scripts/clean-images.sh
   python3 orchestrator_devcontainer.py
   ```
3. Verify build:
   ```bash
   ./scripts/verify-build.sh
   ```

### Adding New Languages

1. Edit `.devcontainer/Dockerfile`:
   - Add language runtime installation
   - Add version manager if applicable
   - Add language-specific static analysis tools
2. Update `.devcontainer/devcontainer-entrypoint.sh`:
   - Add version verification
   - Add tool verification
3. Update documentation (README.md, this file)
4. Test with sample project

### Updating Anthropic's Base

1. Check Anthropic's devcontainer releases
2. Update base image in `.devcontainer/Dockerfile`:
   ```dockerfile
   FROM node:20  # Update version if needed
   ```
3. Review changes to official devcontainer.json template
4. Merge applicable changes (keep our customizations)
5. Test thoroughly before committing

## Resources

- [DevContainer Specification](https://containers.dev/)
- [Anthropic DevContainer Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/)
- [aiodocker Documentation](https://aiodocker.readthedocs.io/)

## Contributing

When contributing to the DevContainer architecture:

1. **Test locally first**: Build and verify before committing
2. **Document changes**: Update this file and README.md
3. **Pin versions**: Always pin tool versions in Dockerfile
4. **Verify builds**: Run `./scripts/verify-build.sh` before PR
5. **Update migration plan**: Keep MIGRATION_PLAN.md in sync
