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

At container startup, `entrypoint.sh`:
1. Validates `config.yml`, `CLAUDE.md`, and `.claude/` exist in AUDIT_BASE_DIR
2. For each configured project directory:
   - Removes any existing `.claude/` and `CLAUDE.md` (ensures clean state)
   - Copies `AUDIT_BASE_DIR/.claude/`  → `<project>/.claude/`
   - Copies `AUDIT_BASE_DIR/CLAUDE.md` → `<project>/CLAUDE.md`

`run_skills.py` then runs all skills in parallel directly against the project
directories. Claude is invoked with `cwd` set to the project directory and
finds `CLAUDE.md` and `.claude/` immediately at its root.

Skills write output to `.analysis/<language>/` inside each project, keeping
parallel runs isolated with no risk of conflicts.

Duplicate skills listed for the same directory are skipped — each
`(directory, skill)` pair runs exactly once.

---

## Setup

### Step 0: Prepare Your Audit Workspace

Before configuring the tool, you need to create a **separate workspace directory** that will contain both the audit configuration files and your project directories.

```bash
# 1. Create a dedicated audit workspace directory (separate from ai-codebase-audit repo)
mkdir -p ~/code-audits
cd ~/code-audits

# 2. Copy required configuration files FROM the ai-codebase-audit repository TO your workspace
#    Replace /path/to/ai-codebase-audit with where you cloned the GitHub repo
cp /path/to/ai-codebase-audit/config.yml .
cp /path/to/ai-codebase-audit/CLAUDE.md .
cp -r /path/to/ai-codebase-audit/.claude .

# 3. Copy your project(s) to this workspace directory
cp -r /path/to/your/java-project ./my-java-app
cp -r /path/to/your/react-app ./my-react-app
```

Your workspace should now look like:
```
~/code-audits/              ← This becomes your AUDIT_BASE_DIR
  ├── config.yml            ← Copied from ai-codebase-audit repo
  ├── CLAUDE.md             ← Copied from ai-codebase-audit repo
  ├── .claude/              ← Copied from ai-codebase-audit repo
  ├── my-java-app/          ← Your project (copied here)
  └── my-react-app/         ← Your project (copied here)
```

### Step 1: Configure Environment Variables

**Navigate to the ai-codebase-audit repository** (NOT your workspace):

```bash
# Go to the ai-codebase-audit repository directory
cd /path/to/ai-codebase-audit

# Copy the environment template
cp .env.example .env
```

Edit `.env` and set:
- `AUDIT_BASE_DIR`: **Absolute path** to the workspace directory you created in Step 0
- `ANTHROPIC_API_KEY`: Your Anthropic API key from https://console.anthropic.com/settings/keys

Example `.env` (in the ai-codebase-audit repo):
```bash
AUDIT_BASE_DIR=/Users/you/code-audits    # ← Absolute path to workspace from Step 0
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

**Important**:
- The `.env` file lives in the **ai-codebase-audit repo**, NOT your workspace
- `AUDIT_BASE_DIR` must be an **absolute path** to your workspace

### Step 2: Configure Audit Targets

Edit `config.yml` **in your audit workspace** (`~/code-audits/config.yml`), NOT in the ai-codebase-audit repo:

```bash
# Edit the config.yml in your workspace
nano ~/code-audits/config.yml
```

Configure your runner settings and target projects:

```yaml
runner:
  model: claude-sonnet-4-6
  concurrency: 3
  max_turns: 20
  timeout: 300
  max_budget_usd: 10.0  # Cost protection per task in USD

targets:
  - dir: my-java-app      # ← Must exactly match directory name from Step 0
    skills:
      - /audit-java

  - dir: my-react-app     # ← Must exactly match directory name from Step 0
    skills:
      - /audit-javascript
```

**Important**: The `dir:` values must exactly match the project directory names in your workspace from Step 0.

### Step 3: Build and Run

**Navigate to the ai-codebase-audit repository** and run docker compose:

```bash
# Go to the ai-codebase-audit repository directory (where docker-compose.yml lives)
cd /path/to/ai-codebase-audit

# Build the Docker image
docker compose build

# Run the audits
docker compose run --rm skills
```

**Key points**:
- Run `docker compose` commands from the **ai-codebase-audit repo** directory
- Docker will automatically mount your **audit workspace** (specified in `.env`) into the container
- Results are written to your workspace directory (`~/code-audits/logs/` and `.analysis/`)

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
| Budget exceeded | Task cost > `runner.max_budget_usd` (default $10) | Increase budget or use smaller model |
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
3. **Re-run the container**:
   ```bash
   docker compose run --rm skills
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
find . -type d -name ".analysis" -exec rm -rf {} +

# Remove all logs
rm -rf logs/*

# Remove Docker image to force rebuild
docker compose down --rmi local
docker compose build --no-cache
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

Debug output appears in the same log locations:

```bash
# Check Docker startup and configuration
cat logs/docker_<timestamp>.log | grep -A 5 "Debug mode"

# Check task execution with full messages
cat logs/task_<project>__<skill>_<ts>_<uid>.log

# Search for tool errors
grep -r "⚠️" logs/task_*.log
grep -r "ERROR" logs/task_*.log
```

### Common Debugging Scenarios

#### Scenario 1: Task Starts But No Progress

**Symptoms:** Task logs show "START" but no assistant messages or tool usage. API balance doesn't decrease.

**Most common cause:** Network isolation blocking API access.

**Quick fix:**
1. Check docker-compose.yml line 42:
   ```bash
   grep "network_mode" docker-compose.yml
   ```
2. If it says `network_mode: "none"`, comment it out:
   ```yaml
   # network_mode: "none"  # Temporarily disabled - SDK needs API access
   ```
3. Rebuild and retry:
   ```bash
   docker compose build
   docker compose run --rm skills
   ```

**Other debug steps:**
1. Enable debug mode in config.yml
2. Check if Claude sessions are being created:
   ```bash
   grep "Session started" logs/task_*.log
   ```
3. Look for skill invocation errors:
   ```bash
   grep "SDK Error" logs/task_*.log
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
2. Re-run without rebuilding:
   ```bash
   docker compose run --rm skills
   ```

No rebuild needed - the debug flag is read from config.yml at runtime.

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

### Budget control

Set `max_budget_usd` in config.yml to prevent runaway costs:

```yaml
runner:
  max_budget_usd: 10.0  # Per-task spending limit
```

**What happens when budget is exceeded:**
- The skill stops gracefully
- Partial analysis is preserved in `.analysis/<language>/`
- Task is marked as failed with "budget exceeded" in logs
- Container continues with remaining tasks

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

**Note**: Set `max_budget_usd` to your per-skill limit, not total budget. The system applies this limit to each individual skill execution.

---

## config.yml options

| Key | Default | Description |
|---|---|---|
| `runner.model` | `claude-sonnet-4-6` | Model to use (`claude-sonnet-4-6` or `claude-opus-4-6`) |
| `runner.concurrency` | `3` | Max parallel tasks |
| `runner.max_turns` | `20` | Max agent turns per task |
| `runner.timeout` | `300` | Per-task timeout in seconds |
| `runner.max_budget_usd` | `10.0` | **Per-task** spending limit in USD (see Cost Estimation above) |

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

**Layer 1: Network Isolation** ⚠️ CURRENTLY DISABLED
- `network_mode: none` is commented out (SDK requires API access)
- **TODO:** Implement restricted networking (allow only api.anthropic.com)
- **Current state:** Container has network access but tools are still pre-installed
- **Mitigation:** Use read-only source mounts when implementing structured output

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

**Why this is safe:**
- Even if skills malfunction and try to run `rm -rf /`, they only affect the container
- Container network is disabled, so no data can be exfiltrated
- Container is destroyed after run, so no persistent changes
- Pre-installed tools prevent arbitrary code execution during runtime

### Security Best Practices

1. **Network isolation temporarily disabled** - Required for Claude API access (see Layer 1 above)
2. **Review skill definitions** - Understand what each skill does before running
3. **Use ephemeral containers** - Always use `--rm` flag: `docker compose run --rm skills`
4. **Backup before running** - Take snapshots of projects before first audit
5. **Review `.analysis/` output** - Check what was written to analysis directories
6. **Consider restricted networking** - Implement firewall rules to allow only api.anthropic.com

### For CI/CD Pipelines

This security model makes the runner **perfect for automated pipelines**:
- No human approval needed (fully autonomous)
- Isolated execution (won't affect other jobs)
- Deterministic results (pre-installed tool versions)
- Safe for untrusted code analysis (container isolation)
