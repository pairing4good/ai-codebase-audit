# DevContainer Configuration for AI Codebase Audit Runner

This directory contains the DevContainer configuration for the AI Codebase Audit Runner, built on [Anthropic's official Claude Code devcontainer](https://github.com/anthropics/claude-code) with multi-language runtime support.

## Overview

This DevContainer provides a complete, reproducible environment for running automated code audits across multiple programming languages (Java, JavaScript/TypeScript, Python, .NET) using Claude AI and 15+ static analysis tools.

## Build-from-Source Philosophy

This project **builds containers from source** (committed Dockerfile) rather than pulling prebuilt images from registries.

### Why Build from Source?

1. **Transparency**: Every tool installation is visible in plain text in `Dockerfile`
2. **Reproducibility**: Anyone can rebuild identical environment from `git clone`
3. **Security**: No hidden dependencies or potential registry compromises
4. **Auditability**: Security teams can review exact build steps and tool versions
5. **Version Control**: Tool version changes tracked in git history

### Trade-offs

- **First build**: Takes 10-15 minutes to install all tools
- **Subsequent builds**: ~30 seconds (Docker layer caching)
- **Disk space**: ~3-4 GB image size (acceptable for comprehensive tooling)
- **Network**: Downloads packages on each machine (vs once to registry)

We believe transparency and reproducibility outweigh the longer first-time setup.

## Files in This Directory

```
.devcontainer/
├── Dockerfile                    # Complete build definition (all tools, all versions)
├── devcontainer.json             # Container configuration and VS Code settings
├── devcontainer-entrypoint.sh    # Container startup script (runs single skill)
├── init-env.sh                   # Version manager initialization (SDKMAN, nvm, pyenv, dotnet)
├── init-firewall.sh              # Network security (whitelists allowed domains)
└── README.md                     # This file
```

## Installed Tools and Versions

### Language Runtimes

| Language | Version Manager | Installed Versions | Default |
|----------|----------------|-------------------|---------|
| **Node.js** | nvm | 20 LTS, 18 LTS | 20 |
| **Java** | SDKMAN | 21.0.5-tem, 17.0.13-tem | 21 |
| **Python** | pyenv | 3.12, 3.11 | 3.12 |
| **.NET** | dotnet-install.sh | 8, 6 | 8 |

### Static Analysis Tools (Pre-installed)

All tools are **pre-installed with pinned versions** for security and reproducibility:

#### Core Tools (All Languages)
- **Semgrep** 1.100.0 - SAST tool for security analysis
- **Snyk** 1.1293.1 - Dependency vulnerability scanner
- **Trivy** 0.69.3 - Container and dependency scanner

#### Python Tools
- **Bandit** 1.7.10 - Security issue finder
- **Safety** 3.2.11 - Dependency vulnerability checker
- **Pylint** 3.3.2 - Code quality analyzer
- **Mypy** 1.13.0 - Static type checker
- **Radon** 6.0.1 - Code complexity analyzer

#### JavaScript/TypeScript Tools
- **ESLint** 9.16.0 - Code quality and style checker
- **TypeScript-ESLint** 8.18.0 - TypeScript-specific linting

#### .NET Tools
- **dotnet-outdated-tool** 4.6.4 - Dependency update checker
- **security-scan** 5.6.7 - Security vulnerability scanner

### Development Tools (from Anthropic's base)
- **Claude Code** (latest) - AI coding assistant
- **git-delta** 0.18.2 - Enhanced diff viewer
- **zsh** with powerline10k - Interactive shell
- **fzf** - Fuzzy finder
- **GitHub CLI (gh)** - GitHub integration
- **jq** - JSON processor

## Build Time Expectations

### First Build (no cache)
```bash
docker build -f .devcontainer/Dockerfile -t audit-runner:local .
```
- **Time**: 10-15 minutes
- **Breakdown**:
  - Base image pull: ~2 min
  - Language runtimes: ~5 min
  - Static analysis tools: ~3 min
  - Claude SDK + tools: ~2 min
  - Image optimization: ~1 min

### Subsequent Builds (with cache)
- **Time**: ~30 seconds
- **What's cached**: All unchanged layers
- **What rebuilds**: Only modified layers and everything after

### Force Rebuild
```bash
# Remove local image
docker rmi audit-runner:local

# Or use --no-cache
docker build --no-cache -f .devcontainer/Dockerfile -t audit-runner:local .
```

## Architecture Differences from Anthropic's Base

### What We Added
1. **Multi-language runtimes**: Java, Python, .NET (Anthropic's base is Node.js only)
2. **Version managers**: SDKMAN, pyenv, .NET installer (added to nvm from base)
3. **Static analysis tools**: 15+ security and quality tools pre-installed
4. **Custom entrypoint**: Simplified for single-skill execution model
5. **Enhanced firewall**: Whitelisted domains for package registries and CVE databases

### What We Kept from Anthropic
1. **Base image**: `node:20` (official Node.js image)
2. **User**: `node` (non-root user for security)
3. **Shell**: zsh with powerline10k theme
4. **Firewall**: `init-firewall.sh` with iptables-based network isolation
5. **VS Code integration**: Extensions and settings for interactive debugging
6. **Claude Code**: npm package `@anthropic-ai/claude-code`

### What We Changed
1. **Working directory**: `/workspace` (same as Anthropic)
2. **Entrypoint**: Custom script for audit workflow (vs interactive shell)
3. **Purpose**: Automated security audits (vs general development)

## Network Security

The container includes **firewall-based network isolation** via `init-firewall.sh`.

### Allowed Domains (Whitelisted)
- **Claude API**: api.anthropic.com, statsig.anthropic.com
- **Package Registries**: registry.npmjs.org, pypi.org, repo.maven.apache.org, api.nuget.org
- **Vulnerability Databases**: nvd.nist.gov, cve.mitre.org, snyk.io
- **GitHub**: *.github.com (all GitHub services)
- **VS Code**: marketplace.visualstudio.com, vscode.blob.core.windows.net

### Blocked
- All other outbound connections are **blocked** by default

### Why Network Access?
1. **Claude API calls** - Required for AI-powered analysis
2. **Vulnerability research** - CVE lookups, security advisories
3. **Package metadata** - Dependency version checking
4. **Tool updates** - Static analysis tool data

Network access is **required** for effective security audits. Containers are **ephemeral** and **isolated**, limiting potential impact.

## Security Model

### Container Isolation
- **Ephemeral**: Containers destroyed after each skill execution
- **Isolated**: Each repo+skill gets its own container instance
- **Pre-installed tools**: No runtime downloads (except data updates)
- **Non-root user**: Runs as `node` user (uid 1000)

### Filesystem Access
- **Framework configs**: Mounted read-only by orchestrator
- **Source code**: Mounted by orchestrator (per project)
- **Output directories**: `.analysis/` and `logs/` writable

### Network Security
- **Firewall**: Active by default (see above)
- **Capabilities**: NET_ADMIN and NET_RAW for firewall management
- **Verification**: Firewall tests on startup (blocks example.com, allows GitHub)

### Risk Assessment
- ✅ **Container escape**: Very low (standard Docker isolation)
- ⚠️ **Data exfiltration**: Possible via allowed domains (review skills before running)
- ✅ **Persistence**: None (ephemeral containers)
- ✅ **Lateral movement**: Limited to mounted directories

**Recommendation**: For highly sensitive code, run in isolated VMs or air-gapped environments.

## Environment Variables

### Required
- `ANTHROPIC_API_KEY` - Your Claude API key from console.anthropic.com

### Optional
- `DEBUG_MODE` - Set to `true` for verbose logging (default: `false`)
- `SKILL_NAME` - Skill to execute (e.g., `/audit-java`, `/audit-python`)
- `TZ` - Timezone (default: `America/Los_Angeles`)

### Automatic (from Anthropic's base)
- `NODE_OPTIONS` - Set to `--max-old-space-size=4096` (4GB heap)
- `CLAUDE_CONFIG_DIR` - Set to `/home/node/.claude`
- `DEVCONTAINER` - Set to `true` (for feature detection)
- `POWERLEVEL9K_DISABLE_GITSTATUS` - Set to `true` (performance optimization)

## Usage

### Interactive Development (VS Code)
```bash
# Open in VS Code
code /path/to/ai-codebase-audit

# VS Code will prompt to "Reopen in Container"
# Click "Reopen in Container"

# Container builds (10-15 min first time)
# Then opens with all tools available
```

### Automated Audit Execution (Orchestrator)
```bash
# The orchestrator spawns N containers programmatically
python orchestrator_devcontainer.py

# Each container:
# 1. Builds from Dockerfile (or uses cache)
# 2. Mounts framework configs read-only
# 3. Mounts target project directory
# 4. Runs single skill (/audit-java, /audit-python, etc.)
# 5. Writes output to .analysis/ and logs/
# 6. Exits and is destroyed
```

### Manual Container Execution
```bash
# Build image
docker build -f .devcontainer/Dockerfile -t audit-runner:local .

# Run single skill
docker run --rm \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -e SKILL_NAME="/audit-java" \
  -v $(pwd)/.claude:/workspace/.claude:ro \
  -v /path/to/target-repo:/workspace/target-repo:rw \
  -v $(pwd)/logs:/workspace/logs:rw \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  audit-runner:local
```

## Version Manager Usage

Once inside the container, you can switch between installed language versions:

### Java (SDKMAN)
```bash
# List installed versions
sdk list java | grep installed

# Switch version for this session
sdk use java 17.0.13-tem

# Switch permanently
sdk default java 17.0.13-tem

# Install additional version
sdk install java 11.0.25-tem
```

### Node.js (nvm)
```bash
# List installed versions
nvm list

# Switch version
nvm use 18

# Make default
nvm alias default 18
```

### Python (pyenv)
```bash
# List installed versions
pyenv versions

# Switch globally
pyenv global 3.11

# Switch for current directory
pyenv local 3.11
```

### .NET (side-by-side)
```bash
# List installed SDKs
dotnet --list-sdks

# Pin version for project (create global.json)
dotnet new globaljson --sdk-version 6.0.428
```

## Troubleshooting

### Build fails with "init-env.sh not found"
**Cause**: Dockerfile expects `init-env.sh` in `.devcontainer/` directory.

**Fix**: Ensure `init-env.sh` exists in `.devcontainer/`:
```bash
ls -la .devcontainer/init-env.sh
```

### Firewall blocks required domain
**Cause**: Domain not in whitelist in `init-firewall.sh`.

**Fix**: Add domain to whitelist (lines 67-85 in `init-firewall.sh`):
```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "your-new-domain.com"; do  # Add here
```

### Tools missing after build
**Cause**: Build cache may be stale or build failed partway.

**Fix**: Force rebuild without cache:
```bash
docker build --no-cache -f .devcontainer/Dockerfile -t audit-runner:local .
```

### Container exits immediately
**Cause**: ANTHROPIC_API_KEY not set or skill file not found.

**Fix**: Check logs:
```bash
docker logs <container-id>

# Ensure API key is set
echo $ANTHROPIC_API_KEY

# Verify skill exists
ls .claude/skills/audit-java/SKILL.md
```

### Permission denied errors
**Cause**: File ownership mismatch (container runs as `node` user, uid 1000).

**Fix**: Adjust host file ownership:
```bash
# Option 1: Change ownership to match container
sudo chown -R 1000:1000 /path/to/workspace

# Option 2: Make directories world-writable (less secure)
chmod -R 777 /path/to/workspace/.analysis
```

## Maintenance

### Updating Tool Versions

1. Edit `Dockerfile` (update version pins)
2. Rebuild image:
   ```bash
   docker build -f .devcontainer/Dockerfile -t audit-runner:local .
   ```
3. Verify tools:
   ```bash
   docker run --rm audit-runner:local semgrep --version
   docker run --rm audit-runner:local snyk --version
   ```
4. Commit changes to git

### Adding New Languages

1. Add version manager installation in `Dockerfile`
2. Add runtime installation commands
3. Update `init-env.sh` to source new version manager
4. Add language-specific static analysis tools
5. Update this README's tool version table
6. Test build and verify tools

### Updating Anthropic's Base

1. Check for updates: https://github.com/anthropics/claude-code
2. Review changes in their Dockerfile and devcontainer.json
3. Merge relevant updates into our files
4. Test thoroughly (we have additional complexity)
5. Update CLAUDE_CODE_VERSION in devcontainer.json if needed

## Resources

- **Anthropic's Claude Code**: https://github.com/anthropics/claude-code
- **DevContainer Spec**: https://containers.dev/
- **Docker Documentation**: https://docs.docker.com/
- **SDKMAN**: https://sdkman.io/
- **nvm**: https://github.com/nvm-sh/nvm
- **pyenv**: https://github.com/pyenv/pyenv
- **.NET Install Script**: https://dot.net/v1/dotnet-install.sh

## Contributing

When modifying DevContainer configuration:

1. **Test builds**: Always test full build before committing
2. **Document changes**: Update this README with version changes
3. **Version pins**: Never use `latest` - always pin tool versions
4. **Security review**: Consider security implications of new tools/domains
5. **Size awareness**: Monitor image size (`docker images audit-runner:local`)

## License

This DevContainer configuration inherits the license from the parent ai-codebase-audit project.
