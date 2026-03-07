# Claude Parallel Skill Runner

Runs `.claude` skills against project directories in parallel inside Docker.
Skills run directly against project directories — no sandboxes, no copying.

---

## Directory Structure

This tool uses **two separate directories**:

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1. ai-codebase-audit repo (where you cloned the GitHub repo)        │
│    /path/to/ai-codebase-audit/                                       │
│    ├── docker-compose.yml      ← Run docker compose here            │
│    ├── Dockerfile                                                    │
│    ├── .env                    ← Create and configure this          │
│    ├── .env.example                                                  │
│    ├── entrypoint.sh                                                 │
│    ├── run_skills.py                                                 │
│    ├── config.yml              ← Template to copy to workspace      │
│    ├── CLAUDE.md               ← Template to copy to workspace      │
│    └── .claude/                ← Template to copy to workspace      │
└──────────────────────────────────────────────────────────────────────┘
                                  ↓ Docker mounts ↓
┌──────────────────────────────────────────────────────────────────────┐
│ 2. Audit workspace (separate directory you create)                  │
│    ~/code-audits/              ← Set as AUDIT_BASE_DIR              │
│    ├── config.yml              ← Copied from repo, edit here        │
│    ├── CLAUDE.md               ← Copied from repo                   │
│    ├── .claude/                ← Copied from repo                   │
│    ├── my-java-app/            ← Your project #1                    │
│    │   ├── src/                                                      │
│    │   ├── pom.xml                                                   │
│    │   ├── CLAUDE.md           ← Auto-copied at container startup   │
│    │   ├── .claude/            ← Auto-copied at container startup   │
│    │   └── .analysis/java/     ← Results written here               │
│    ├── my-react-app/           ← Your project #2                    │
│    │   ├── src/                                                      │
│    │   ├── package.json                                              │
│    │   ├── CLAUDE.md           ← Auto-copied at container startup   │
│    │   ├── .claude/            ← Auto-copied at container startup   │
│    │   └── .analysis/javascript/ ← Results written here             │
│    └── logs/                   ← Logs written here                  │
│        ├── docker_<ts>.log                                           │
│        ├── python_<ts>.log                                           │
│        ├── summary_<ts>.txt                                          │
│        └── result_*.txt                                              │
└──────────────────────────────────────────────────────────────────────┘
```

**Key points**:
- **Run commands from**: ai-codebase-audit repo (where `docker-compose.yml` lives)
- **Edit config.yml in**: Audit workspace (`~/code-audits/config.yml`)
- **Results written to**: Audit workspace (`~/code-audits/logs/`, `.analysis/`)

---

### 1. ai-codebase-audit Repository (where you run commands)
```
/path/to/ai-codebase-audit/        ← Where you cloned this GitHub repo
  ├── docker-compose.yml           ← Docker configuration
  ├── Dockerfile                   ← Container build instructions
  ├── .env                         ← Environment config (you create this)
  ├── .env.example                 ← Template for .env
  ├── entrypoint.sh                ← Container startup script
  ├── run_skills.py                ← Python orchestrator
  ├── config.yml                   ← Template (copy to workspace)
  ├── CLAUDE.md                    ← Template (copy to workspace)
  └── .claude/                     ← Template (copy to workspace)
      ├── settings.json
      ├── agents/                  ← Analysis agents
      └── skills/                  ← Audit workflows
```

**This is where you**:
- Create and edit the `.env` file
- Run `docker compose build` and `docker compose run --rm skills`

### 2. Audit Workspace (where projects and results live)

The audit system requires a **separate workspace directory** (AUDIT_BASE_DIR) that contains:
1. Configuration files (config.yml, CLAUDE.md, .claude/) - copied from repo
2. Your project directories to audit
3. Logs directory (created automatically)

```
/your/audit-workspace/             ← Set AUDIT_BASE_DIR to this path
  config.yml                       ← Copied from repo, edit to configure audits
  CLAUDE.md                        ← Copied from repo (agent instructions)
  .claude/                         ← Copied from repo (skills and agents)
    settings.json                  ← Agent configuration
    agents/                        ← Specialized analysis agents
      architecture-analyzer.md
      security-analyzer.md
      dependency-analyzer.md
      maintainability-analyzer.md
      reconciliation-agent.md
      adversarial-agent.md
      artifact-generator.md
    skills/                        ← Language-specific audit workflows
      audit-java/SKILL.md + tools/
      audit-javascript/SKILL.md + tools/
      audit-dotnet/SKILL.md + tools/
      audit-python/SKILL.md + tools/
  project-one/                     ← Your first project to audit
    .git/
    src/
    pom.xml
    CLAUDE.md                      ← Copied from parent at container startup
    .claude/                       ← Copied from parent at container startup
    .analysis/java/                ← Audit results written here
  project-two/                     ← Your second project to audit
    .git/
    src/
    package.json
    CLAUDE.md                      ← Copied from parent at container startup
    .claude/                       ← Copied from parent at container startup
    .analysis/javascript/          ← Audit results written here
  logs/                            ← Created automatically
    docker_<timestamp>.log         ← Container lifecycle logs
    python_<timestamp>.log         ← Orchestration logs
    task_<project>__<skill>.log    ← Per-task execution logs
    result_<project>__<skill>.txt  ← Final skill results
    summary_<timestamp>.txt        ← Overall pass/fail summary
```

**This is where**:
- Your projects live
- You edit `config.yml` to configure which projects to audit
- All results are written (logs/ and .analysis/ directories)

---

## How it works

The orchestrator (`orchestrator_devcontainer.py`):
1. Validates `config.yml` and `.claude/` exist in the framework directory
2. For each configured project directory:
   - Renames any existing `.claude/`, `CLAUDE.md`, and `CLAUDE.local.md` files with `OLD-` prefix (ensures clean state, preserves originals)
   - Mounts the framework's `.claude/` directory as read-only at `/workspace/.claude`
   - Mounts the project source code at `/workspace/<project-dir>`
3. Spawns isolated containers (one per project+skill combination)
4. Each container runs a single skill via Claude Code CLI

Claude discovers the framework's mounted `.claude/` directory and uses the audit
skills, never finding any renamed `OLD-` prefixed files in the target repositories.

Skills write output to `.analysis/<language>/` inside each project, keeping
parallel runs isolated with no risk of conflicts.

Duplicate skills listed for the same directory are skipped — each
`(directory, skill)` pair runs exactly once.

---

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

4. Prepare your audit workspace (separate directory):
   ```bash
   # Create workspace directory
   mkdir -p ~/code-audits
   export AUDIT_BASE_DIR=~/code-audits

   # Copy framework files
   cp config.yml CLAUDE.md ~/code-audits/
   cp -r .claude ~/code-audits/

   # Clone target repos into workspace
   cd ~/code-audits
   git clone https://github.com/example/project-one
   git clone https://github.com/example/project-two

   # Edit config.yml to list your projects
   nano config.yml
   ```

5. First run will build the devcontainer image (~10-15 minutes):
   ```bash
   cd ~/git/ai-codebase-audit
   python3 orchestrator_devcontainer.py
   ```

   The Dockerfile will be built locally from `.devcontainer/Dockerfile`. Subsequent runs use Docker's cache and start much faster (~30 seconds).

### Build from Source Philosophy

This project builds containers from source (committed Dockerfile) rather than pulling prebuilt images. This ensures:

- **Transparency**: All build steps visible in plain text
- **Reproducibility**: Anyone can rebuild from git clone
- **Security**: No dependency on external registries
- **Auditability**: Tool versions pinned in committed Dockerfile

First run takes 10-15 minutes to install all tools. Docker caching makes subsequent runs start in ~30 seconds.

To force a rebuild:
```bash
export FORCE_REBUILD=true
python3 orchestrator_devcontainer.py
```

Or manually:
```bash
./scripts/clean-images.sh
python3 orchestrator_devcontainer.py
```

### Quick Start

After setup, running audits is simple:

```bash
# Make sure AUDIT_BASE_DIR is set
export AUDIT_BASE_DIR=~/code-audits

# Run the orchestrator
python3 orchestrator_devcontainer.py
```

Results will be written to:
- `~/code-audits/logs/` - Execution logs and summaries
- `~/code-audits/{project}/.analysis/` - Detailed analysis reports

---

## API key

The API key is loaded from the `ANTHROPIC_API_KEY` environment variable.
Set this in your `.env` file (see `.env.example` for a template).

Get your API key from: https://console.anthropic.com/settings/keys

---

## Language version managers

| Language | Manager | Switch version |
|---|---|---|
| Java | SDKMAN | `sdk use java 17.0.13-tem` |
| Node.js | nvm | `nvm use 18` |
| Python | pyenv | `pyenv global 3.11` |
| .NET | side-by-side + global.json | `/opt/dotnet-install.sh --channel 7.0 --install-dir /opt/dotnet` |

Pre-installed:

| Language | Default | Also installed |
|---|---|---|
| Java | 21 (Temurin) | 17 (Temurin) |
| Node.js | 20 LTS | 18 LTS |
| Python | 3.12 | 3.11 |
| .NET | 8 | 6 |

---

## Pre-installed Static Analysis Tools

**Security Note:** All static analysis tools are pre-installed in the Docker image with pinned versions. This eliminates the security risk of auto-install scripts executing arbitrary code during analysis.

### Core Tools (All Languages)
- **Semgrep** v1.95.0 - SAST for OWASP Top 10, CWE/SANS 25
- **Snyk** v1.1293.1 - Dependency vulnerability scanning
- **Trivy** v0.58.1 - Container and dependency scanning

### Python Tools
- **Bandit** v1.7.10 - Python security issues
- **Safety** v3.2.11 - Python dependency vulnerabilities
- **Pylint** v3.3.2 - Code quality and PEP 8
- **Mypy** v1.13.0 - Static type checking
- **Radon** v6.0.1 - Code complexity metrics

### JavaScript/TypeScript Tools
- **ESLint** v9.16.0 - Linting and code quality
- **@typescript-eslint/parser** v8.18.0 - TypeScript support
- **@typescript-eslint/eslint-plugin** v8.18.0 - TypeScript rules

### .NET Tools
- **dotnet-outdated-tool** v4.6.4 - Dependency version checking
- **security-scan** v5.6.7 - Security analysis for .NET

All tool versions are verified at container startup. If any tools are missing, the container will fail fast with a clear error message prompting you to rebuild the image.

---

## Logs

All in `<AUDIT_BASE_DIR>/logs/`:

| File | Contents |
|---|---|
| `docker_<ts>.log` | Startup, validation, prep, shutdown |
| `python_<ts>.log` | Task queue, start, ok, fail |
| `task_<dir>__<skill>_<ts>_<uid>.log` | Full per-task output (uid prevents collisions) |
| `result_<dir>__<skill>_<ts>_<uid>.txt` | Skill's final output (uid prevents collisions) |
| `summary_<ts>.txt` | Pass/fail table |
| `summary_<ts>.json` | Machine-readable results |

---

## Handling Failures

### What happens when a skill fails?

If a skill fails during execution:

1. **Partial results are preserved**: Analysis outputs in `.analysis/<language>/` are kept for inspection
2. **Logs are retained**: Check logs for detailed error information (see Logs section above)
3. **Container exits with non-zero code**: Final exit code is 1 if any skills failed
4. **Summary shows failures**: `logs/summary_<ts>.txt` indicates which tasks failed

### How to diagnose failures

**Step 1: Check the summary**
```bash
cat logs/summary_<most-recent>.txt
```
This shows which projects/skills failed.

**Step 2: Review task logs**
```bash
cat logs/task_<project>__<skill>_<ts>_<uid>.log
```
Replace `<project>`, `<skill>`, `<ts>`, and `<uid>` with values from the summary.

**Step 3: Check partial analysis**
```bash
ls -la <project-dir>/.analysis/<language>/
```
Partial results may contain clues about what was analyzed before failure.

### Common failure scenarios

| Failure Type | Likely Cause | Solution |
|---|---|---|
| Timeout | Task exceeded `runner.timeout` (default 300s) | Increase timeout in config.yml or reduce codebase scope |
| Out of memory | Container exceeded 4GB limit | Analyze fewer projects concurrently or reduce `runner.concurrency` |
| Config error | Invalid skill path or duplicate skills | Fix config.yml based on error message |
| Disk space | Insufficient space for analysis outputs | Free up space or increase volume size |

### How to re-run only failed skills

1. **Identify failed skills** from `logs/summary_<ts>.txt`
2. **Edit config.yml** to include only the failed projects/skills:
   ```yaml
   targets:
     - dir: project-that-failed
       skills:
         - /audit-java  # Only the skill that failed
   ```
3. **Re-run the orchestrator**:
   ```bash
   python3 orchestrator_devcontainer.py
   ```

### Preserving previous results

Analysis outputs in `.analysis/<language>/` are NOT automatically cleaned up between runs. Each run adds to or overwrites previous results. To preserve previous analysis:

```bash
# Before re-running, backup existing analysis
cp -r project-one/.analysis project-one/.analysis.backup-2026-03-03
```

### Emergency cleanup

If you need to start completely fresh:

```bash
# Remove all analysis outputs
cd ~/code-audits
find . -type d -name ".analysis" -exec rm -rf {} +

# Remove all logs
rm -rf logs/*

# Remove Docker image to force rebuild
docker rmi audit-runner:local
python3 ~/git/ai-codebase-audit/orchestrator_devcontainer.py
```

---

## Troubleshooting

### Build Failures

**Problem**: Docker build fails

**Solutions**:
1. Check disk space: `docker system df`
2. Prune old images: `docker image prune -a`
3. Retry with no cache: `./scripts/build-local.sh --no-cache --verify`
4. Check Docker daemon is running: `docker info`

### Container Spawn Failures

**Problem**: Orchestrator can't spawn containers

**Solutions**:
1. Verify Docker running: `docker info`
2. Check environment variable: `echo $AUDIT_BASE_DIR`
3. Verify image exists: `docker images | grep audit-runner`
4. Try manual build: `./scripts/build-local.sh --verify`

### Tool Missing Errors

**Problem**: Container reports missing static analysis tools

**Solutions**:
1. Force rebuild: `./scripts/clean-images.sh && python3 orchestrator_devcontainer.py`
2. Verify build completed: `./scripts/verify-build.sh`
3. Check build logs for installation errors in Dockerfile
4. Ensure you're using the correct image tag in config.yml

### Developer Tools

Useful scripts for troubleshooting and development:

```bash
# Build image manually with verification
./scripts/build-local.sh --verify

# Verify all tools are installed correctly
./scripts/verify-build.sh

# Clean local images to force rebuild
./scripts/clean-images.sh

# Watch logs in real-time
tail -f ~/code-audits/logs/task_*.log
```

**Force rebuild options**:
```bash
# Option 1: Environment variable
export FORCE_REBUILD=true
python3 orchestrator_devcontainer.py

# Option 2: Config file
# Edit config.yml: runner.rebuild: true

# Option 3: Manual cleanup
./scripts/clean-images.sh
python3 orchestrator_devcontainer.py
```

---

## Debugging

### When to Enable Debug Mode

Enable debug mode when you need to diagnose:
- Tasks that start but show no API progress or activity
- Silent tool failures with no clear error messages
- Unexpected behavior in skills or agents
- Performance bottlenecks or slow execution
- API usage verification (confirm Claude is being called)

### How to Enable

Edit `config.yml` in your workspace and set:

```yaml
debug:
  enabled: true  # Set to true for verbose diagnostic logging
```

Then rebuild and run:

```bash
docker compose build
docker compose run --rm skills
```

### What Changes in Debug Mode

When `debug.enabled: true`:

1. **Full SDK Messages (No Truncation)**
   - Normal mode: Assistant messages truncated to 500 chars, tool outputs to 200 chars
   - Debug mode: Full messages logged (can be 10,000+ chars)
   - Error messages are **never** truncated (always full in both modes)

2. **SDK Internal Diagnostics**
   - Normal mode: Only SDK errors and warnings logged
   - Debug mode: All SDK stderr output logged (including info/debug messages)
   - Prevents "Check stderr output for details" with no actual details

3. **Tool Execution Details**
   - Bash tracing enabled (`set -x`) for all static analysis tools
   - Full command-line arguments logged
   - Tool stdout/stderr captured and logged

4. **Verbose Startup Information**
   - Debug mode status displayed during container startup
   - Environment variable propagation confirmed
   - All configuration values logged

5. **Timing and Performance Data**
   - Task duration logged in orchestrator output
   - Helps identify slow operations

### Log File Impact

**Warning:** Debug mode generates significantly larger log files (10-100x normal size).

| Log Type | Normal Size | Debug Size | Location |
|---|---|---|---|
| Task logs | 50-500 KB | 5-50 MB | `logs/task_*.log` |
| Docker log | 10-50 KB | 100-500 KB | `logs/docker_*.log` |

**Example:**
- Normal 10K LOC project: ~500 KB logs
- Debug 10K LOC project: ~50 MB logs

Plan disk space accordingly when running multiple audits with debug enabled.

### Where to Find Debug Information

Debug output is written to the `logs/` directory in your audit workspace. When debug mode is enabled (`debug.enabled: true` in `config.yml`), all logs contain significantly more detail:

```bash
# Orchestrator logs (main coordinator process)
# Contains: image building, container creation, task scheduling
cat logs/orchestrator_<timestamp>.log

# Individual task logs (one per project+skill execution)
# Contains: entrypoint startup, Claude CLI output (with --debug --verbose),
#           skill execution, tool commands (with bash set -x)
cat logs/task_<project>__<skill>_<timestamp>_<uid>.log

# Search for tool errors across all task logs
grep -r "⚠️" logs/task_*.log
grep -r "ERROR" logs/task_*.log

# Search for debug statements
grep -r "DEBUG:" logs/task_*.log
```

**Debug mode enhancements:**
- **Orchestrator**: Shows container configuration, mount paths, environment variables (API key masked)
- **Claude CLI**: Runs with `--debug --verbose` flags for detailed execution traces
- **Entrypoint**: Logs all startup checks, firewall initialization, skill validation
- **Skills/Tools**: Bash commands shown with `set -x` (command echo before execution)
- **Python logging**: Level set to `DEBUG` instead of `INFO`

### Common Debugging Scenarios

#### Scenario 1: Task Starts But No Progress

**Symptoms:** Task logs show "START" but no assistant messages or tool usage. API balance doesn't decrease.

**Debug steps:**
1. Verify API key is set correctly:
   ```bash
   grep ANTHROPIC_API_KEY .env
   ```
2. Enable debug mode in config.yml and check for errors:
   ```yaml
   debug:
     enabled: true
   ```
3. Check if Claude sessions are being created:
   ```bash
   grep "Session started" logs/task_*.log
   ```
4. Look for skill invocation or network errors:
   ```bash
   grep -E "SDK Error|Failed|Exception" logs/task_*.log
   ```
5. Test network connectivity from container:
   ```bash
   docker compose run --rm skills bash -c "curl -I https://api.anthropic.com"
   ```

#### Scenario 2: Tool Fails Silently

**Symptoms:** Analysis completes but results are empty or missing.

**Debug steps:**
1. Enable debug mode
2. Check tool runner output:
   ```bash
   grep -A 10 "Running semgrep\|Running bandit" logs/task_*.log
   ```
3. Look for tool exit codes:
   ```bash
   grep "exited with code" logs/task_*.log
   ```

#### Scenario 3: Verify API Usage

**Symptoms:** Want to confirm Claude API is being called.

**Debug steps:**
1. Enable debug mode
2. Monitor for assistant messages:
   ```bash
   tail -f logs/task_*.log | grep "\[assistant\]"
   ```
3. Count API interactions:
   ```bash
   grep -c "\[assistant\]" logs/task_*.log
   ```

### Debug Mode in Skills and Agents

Skills and agents can access the `$DEBUG_MODE` environment variable:

```bash
# In skill or agent Bash tool:
if [ "$DEBUG_MODE" = "true" ]; then
  echo "DEBUG: Running analysis on $(pwd)"
  echo "DEBUG: Found $(find . -name "*.py" | wc -l) Python files"
fi
```

This allows conditional verbose logging within skill/agent execution.

### Disabling Debug Mode

To return to normal operation:

1. Edit `config.yml` and set `debug.enabled: false`
2. Re-run the orchestrator:
   ```bash
   python orchestrator_devcontainer.py
   ```

No rebuild needed - the debug setting is read from `config.yml` at runtime and passed to containers as they're created.

---

## Cost Estimation

### Typical costs per skill

Costs vary based on codebase size, complexity, and model choice. These are **rough estimates** using `claude-sonnet-4` (default):

| Project Size | Lines of Code | Cost Range per Skill |
|---|---|---|
| Small | < 10,000 LOC | $0.50 - $2.00 |
| Medium | 10,000 - 50,000 LOC | $2.00 - $6.00 |
| Large | 50,000 - 150,000 LOC | $6.00 - $15.00 |
| Very Large | > 150,000 LOC | $15.00 - $30.00+ |

**Note**: `claude-opus-4` costs approximately **3x more** than Sonnet for the same analysis.

### Factors affecting cost

1. **Codebase size**: More files and lines = more tokens to analyze
2. **Code complexity**: Complex architectures require more analysis turns
3. **Model choice**: Opus is more expensive but may provide deeper insights
4. **Analysis depth**: Security analysis typically costs more than basic structure analysis
5. **Number of agents**: Each skill runs 4 agents (architecture, security, dependency, maintainability)
6. **Static tool output**: Large tool outputs (e.g., from Semgrep, SpotBugs) increase cost

### Estimating total cost

**Formula:**
```
Total Cost ≈ (Number of Projects × Skills per Project) × Average Cost per Skill
```

**Example:**
```yaml
# config.yml
targets:
  - dir: project-one    # Medium Java project (~30K LOC)
    skills: [/audit-java]
  - dir: project-two    # Small Node project (~5K LOC)
    skills: [/audit-javascript]
```

**Estimated cost:**
- Project-one: 1 project × 1 skill × $4.00 = **$4.00**
- Project-two: 1 project × 1 skill × $1.00 = **$1.00**
- **Total: ~$5.00**

### Tracking actual costs

After each run, check:

```bash
# View summary with costs
cat logs/summary_<ts>.txt

# Machine-readable results with cost data
cat logs/summary_<ts>.json
```

The summary shows:
- Cost per task (if available from Claude API)
- Total tokens used
- Whether budget was exceeded

### Cost optimization tips

1. **Start small**: Test with one project first to gauge costs
2. **Use Sonnet**: Default model is cost-effective for most use cases
3. **Increase timeout**: Higher timeout may use more tokens but reduces failed runs
4. **Adjust concurrency**: Lower concurrency = less parallel cost accumulation
5. **Incremental analysis**: Run skills individually rather than all at once

### Budget recommendations

| Use Case | Recommended Budget |
|---|---|
| Single small project (< 10K LOC) | $5.00 |
| Single medium project (10-50K LOC) | $10.00 |
| Single large project (> 50K LOC) | $20.00 |
| Multiple projects (5-10 medium) | $50.00 - $100.00 |
| Organization-wide audit (20+ projects) | $200.00+ |

---

## config.yml options

| Key | Default | Description |
|---|---|---|
| `runner.model` | `claude-sonnet-4-6` | Model to use (`claude-sonnet-4-6` or `claude-opus-4-6`) |
| `runner.concurrency` | `3` | Max parallel tasks |
| `runner.timeout` | `300` | Per-task timeout in seconds |

---

## Security Model

This runner uses **`bypassPermissions`** mode for autonomous operation. Security is enforced at the **Docker level**, not by permission deny lists.

### Hardcoded Settings

**`bypassPermissions` mode:**
- Claude automatically approves all tool executions without prompting
- Enables fully autonomous operation in headless environments
- Cannot be changed via configuration (hardcoded for reliability)

**Why `bypassPermissions` is safe here:**
- Skills run in **isolated, ephemeral Docker containers**
- Security enforced by container isolation, not permission rules
- Deny lists in `.claude/settings.json` are **documentation only**

### Three Layers of Security

**Layer 1: Network Access** (Enabled by Design)
- Network access is **required** for comprehensive security audits:
  - Claude API calls (`api.anthropic.com`)
  - Vulnerability research via WebFetch/WebSearch (CVE databases, security advisories)
  - Up-to-date security information (OWASP, GitHub advisories, Snyk, NVD)
- Static analysis tools (Semgrep, Snyk, etc.) may check online databases
- **Trade-off:** Enables complete audits but allows potential data exfiltration
- **Mitigation:** Review skills before running, use isolated VMs for sensitive code

**Layer 2: Container Isolation**
- Containers are ephemeral (destroyed after each run)
- Limited blast radius (only affects mounted directories)
- No access to host system outside mounted volumes

**Layer 3: Filesystem Restrictions**
- Config files (config.yml, CLAUDE.md, .claude/) mounted read-only
- Source code currently mounted read-write (needed for `.claude/` file copying)
- Only `.analysis/` and `logs/` directories receive output
- See docker-compose.yml for volume mount configuration

### What `.claude/settings.json` Actually Does

**Common misconception:** The `permissions.deny` list blocks dangerous operations.

**Reality with `bypassPermissions` mode:**
- Deny lists are **documentation only** - they don't block anything
- Claude Agent SDK doesn't enforce these rules in `bypassPermissions` mode
- They serve as documentation of intended tool usage patterns
- Real security comes from Docker isolation (network, filesystem, ephemeral containers)

**Why this model is secure enough for most use cases:**
- Even if skills malfunction and try to run `rm -rf /`, they only affect the container
- Container is destroyed after run, so no persistent changes
- Pre-installed tools prevent arbitrary code execution during runtime
- Limited filesystem access (only mounted project directories)
- **Note:** Network is enabled, so code could theoretically be exfiltrated - review skills first

### Security Best Practices

1. **Review skill definitions first** - Understand what each skill does before running (especially Bash commands)
2. **For sensitive code** - Run in isolated VM or air-gapped environment to prevent exfiltration risk
3. **Use ephemeral containers** - Always use `--rm` flag: `docker compose run --rm skills`
4. **Backup before running** - Take snapshots of projects before first audit
5. **Review `.analysis/` output** - Check what was written to analysis directories
6. **Trust but verify** - Skills are open source and auditable in `.claude/skills/`

### For CI/CD Pipelines

This security model makes the runner **perfect for automated pipelines**:
- No human approval needed (fully autonomous)
- Isolated execution (won't affect other jobs)
- Deterministic results (pre-installed tool versions)
- Safe for untrusted code analysis (container isolation)
