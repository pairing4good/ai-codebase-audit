# Quick Start

Run AI-powered security audits in 5 steps. Get your API key: https://console.anthropic.com/settings/keys

---

## 1. Setup (5 minutes)

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

Edit `.env`:
```bash
AUDIT_BASE_DIR=/Users/you/code-audits  # Absolute path to workspace
ANTHROPIC_API_KEY=sk-ant-api03-...
```

---

## 2. Prepare Workspace (5 minutes)

```bash
# Create workspace directory
mkdir -p ~/code-audits
export AUDIT_BASE_DIR=~/code-audits

# Copy config file (only file needed in workspace)
cp config.yml ~/code-audits/

# Clone target repos
cd ~/code-audits
git clone https://github.com/example/project-one
git clone https://github.com/example/project-two

# Edit config.yml to list your projects
nano config.yml
```

Configure targets in `~/code-audits/config.yml`:
```yaml
targets:
  - dir: project-one      # Must match directory name
    skills: [/audit-java]
  - dir: project-two
    skills: [/audit-javascript]
```

**Note**: The `.claude/` directory is mounted read-only from the framework root into each container. No file copying needed.

---

## 3. First Run (10-15 minutes build + analysis time)

```bash
cd ~/git/ai-codebase-audit
python3 orchestrator_devcontainer.py

# First run builds devcontainer image (~10-15 min)
# Then runs analysis
```

**Note**: First run takes 10-15 minutes to build the Docker image from `.devcontainer/Dockerfile`. This builds all language runtimes and static analysis tools from source.

---

## 4. Subsequent Runs (~5 minutes analysis time)

```bash
# Docker cache makes image build ~30 seconds
python3 orchestrator_devcontainer.py
```

**Note**: After the first run, Docker caching makes the image build nearly instant (~30 seconds). Analysis time remains the same.

---

## 5. View Results

```bash
# Summary
cat ~/code-audits/logs/summary_*.txt

# Detailed reports
ls ~/code-audits/project-one/.analysis/java/final-report/

# JSON results (machine-readable)
cat ~/code-audits/logs/summary_*.json
```

---

## Results

Outputs written to your **workspace** (`~/code-audits/`):
- `logs/summary_<timestamp>.txt` - Pass/fail overview
- `logs/summary_<timestamp>.json` - Machine-readable results
- `logs/task_<project>__<skill>_<ts>_<uid>.log` - Per-task execution logs
- `<project>/.analysis/<language>/final-report/` - Full analysis artifacts

**Workspace structure after run**:
```
~/code-audits/
  config.yml                    # Configuration (copied from framework)
  project-one/                  # Your cloned repo
    .analysis/java/             # Created by container during analysis
      final-report/
  project-two/                  # Your cloned repo
    .analysis/javascript/       # Created by container during analysis
      final-report/
  logs/                         # Created by orchestrator
    summary_<timestamp>.txt
    summary_<timestamp>.json
    task_*.log
```

**Framework files** (not copied, mounted read-only):
```
~/git/ai-codebase-audit/
  .claude/                      # Mounted into containers as /workspace/.claude:ro
    agents/
    skills/
  .devcontainer/Dockerfile      # Image build source
  orchestrator_devcontainer.py  # Run from here
```

---

## What it does

Each audit runs 6 stages:

1. **Artifact Generation**: Maps codebase structure, dependencies, entry points
2. **Parallel Independent Analysis**: 4 agents analyze concurrently:
   - Architecture & design patterns
   - Security vulnerabilities (OWASP Top 10, CWE/SANS 25)
   - Dependencies & supply chain risks
   - Code quality & maintainability
3. **Static Analysis**: Runs language-specific tools (Semgrep, Snyk, Trivy, etc.)
4. **Reconciliation**: Synthesizes agent findings with static analysis results
5. **Adversarial Review**: Challenges findings to eliminate false positives
6. **Final Report**: Generates comprehensive markdown report with remediation steps

---

## Build from Source Philosophy

This tool builds containers **from source** (committed Dockerfile) rather than pulling prebuilt images:

**Benefits**:
- **Transparency**: All build steps visible in `.devcontainer/Dockerfile`
- **Reproducibility**: Anyone can rebuild from `git clone`
- **Security**: No dependency on external registries
- **Auditability**: Security teams can review exact build steps

**Trade-off**: First run takes 10-15 minutes to build (vs instant pull). Docker caching makes subsequent runs fast (~30 seconds).

**Force rebuild**:
```bash
# Option 1: Environment variable
export FORCE_REBUILD=true
python3 orchestrator_devcontainer.py

# Option 2: Manual cleanup
./scripts/clean-images.sh
python3 orchestrator_devcontainer.py
```

---

## Advanced

### Available Skills
- `/audit-java` - Java/Spring Boot/Maven/Gradle
- `/audit-javascript` - JavaScript/TypeScript/React/Node.js
- `/audit-python` - Python/Django/Flask
- `/audit-dotnet` - C#/F#/ASP.NET Core

### Config Options

Edit `~/code-audits/config.yml`:

```yaml
runner:
  model: claude-sonnet-4-6   # or claude-opus-4-6 (3x cost, deeper insights)
  concurrency: 3             # max parallel containers
  max_turns: 20              # max agent turns per task
  timeout: 300               # per-task timeout (seconds)
  max_budget_usd: 10.0       # cost limit per task
  image_tag: audit-runner:local  # Docker image tag
  rebuild: false             # force rebuild toggle

debug:
  enabled: false             # verbose logging (10-100x larger logs)
```

### Developer Tools

```bash
# Build image manually
./scripts/build-local.sh --verify

# Verify all tools installed
./scripts/verify-build.sh

# Clean local images (force rebuild)
./scripts/clean-images.sh

# Watch logs in real-time
tail -f ~/code-audits/logs/task_*.log
```

---

## Troubleshooting

### Build Failures

**Problem**: Docker build fails

**Solutions**:
1. Check disk space: `docker system df`
2. Prune old images: `docker image prune -a`
3. Retry with no cache: `./scripts/build-local.sh --no-cache --verify`

### Container Spawn Failures

**Problem**: Orchestrator can't spawn containers

**Solutions**:
1. Verify Docker running: `docker info`
2. Check environment: `echo $AUDIT_BASE_DIR`
3. Verify image exists: `docker images | grep audit-runner`

### Tool Missing Errors

**Problem**: Container reports missing tools

**Solutions**:
1. Force rebuild: `./scripts/clean-images.sh && python3 orchestrator_devcontainer.py`
2. Verify build: `./scripts/verify-build.sh`
3. Check build logs for installation errors

### Task Failures

**Problem**: Skills fail during execution

**Solutions**:
1. Check summary: `cat ~/code-audits/logs/summary_*.txt`
2. Review task logs: `cat ~/code-audits/logs/task_<project>__<skill>_*.log`
3. Enable debug mode: `debug.enabled: true` in config.yml
4. Increase timeout or budget in config.yml

---

## Cost Estimation

Typical costs per skill with `claude-sonnet-4-6` (default):

| Project Size | Lines of Code | Cost per Skill |
|--------------|---------------|----------------|
| Small        | < 10,000      | $0.50 - $2.00  |
| Medium       | 10K - 50K     | $2.00 - $6.00  |
| Large        | 50K - 150K    | $6.00 - $15.00 |
| Very Large   | > 150K        | $15.00 - $30.00+ |

**Note**: `claude-opus-4-6` costs ~3x more but provides deeper insights.

**Budget control**: Set `max_budget_usd` in config.yml to prevent runaway costs.

---

## More Information

- [README.md](README.md) - Complete documentation
- [docs/DEVCONTAINER-ARCHITECTURE.md](docs/DEVCONTAINER-ARCHITECTURE.md) - Architecture details
- [MIGRATION_PLAN.md](MIGRATION_PLAN.md) - Migration from Docker Compose
- [.devcontainer/README.md](.devcontainer/README.md) - DevContainer configuration
