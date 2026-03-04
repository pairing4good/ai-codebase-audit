# Claude Parallel Skill Runner

Runs `.claude` skills against project directories in parallel inside Docker.
Skills run directly against project directories — no sandboxes, no copying.

---

## Directory Structure

The audit system requires a **parent directory** (AUDIT_BASE_DIR) that contains:
1. Configuration files (config.yml, CLAUDE.md, .claude/)
2. Your project directories to audit
3. Logs directory (created automatically)

```
/your/audit-base-dir/              ← Set AUDIT_BASE_DIR to this path
  config.yml                       ← Configure which projects & skills to run
  CLAUDE.md                        ← Claude agent instructions (provided)
  .claude/                         ← Shared skills and agents (provided)
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
    CLAUDE.md                      ← Copied from parent at startup
    .claude/                       ← Copied from parent at startup
    .analysis/java/                ← Audit results written here
  project-two/                     ← Your second project to audit
    .git/
    src/
    package.json
    CLAUDE.md                      ← Copied from parent at startup
    .claude/                       ← Copied from parent at startup
    .analysis/javascript/          ← Audit results written here
  logs/                            ← Created automatically
    docker_<timestamp>.log         ← Container lifecycle logs
    python_<timestamp>.log         ← Orchestration logs
    task_<project>__<skill>.log    ← Per-task execution logs
    result_<project>__<skill>.txt  ← Final skill results
    summary_<timestamp>.txt        ← Overall pass/fail summary
```

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

Before configuring the tool, you need to create a workspace directory that will contain both the audit configuration files and your project directories.

```bash
# 1. Create a dedicated audit workspace directory
mkdir -p ~/code-audits
cd ~/code-audits

# 2. Copy required configuration files from this repository
cp /path/to/ai-codebase-audit/config.yml .
cp /path/to/ai-codebase-audit/CLAUDE.md .
cp -r /path/to/ai-codebase-audit/.claude .

# 3. Add your project(s) to this directory
#    Option A: Move projects here
mv /path/to/your/java-project ./my-java-app
mv /path/to/your/react-app ./my-react-app

#    Option B: Create symlinks (recommended - keeps projects in original locations)
ln -s /path/to/your/java-project ./my-java-app
ln -s /path/to/your/react-app ./my-react-app
```

Your workspace should now look like:
```
~/code-audits/              ← This becomes your AUDIT_BASE_DIR
  ├── config.yml            ← Copied from ai-codebase-audit repo
  ├── CLAUDE.md             ← Copied from ai-codebase-audit repo
  ├── .claude/              ← Copied from ai-codebase-audit repo
  ├── my-java-app/          ← Your project (moved or symlinked)
  └── my-react-app/         ← Your project (moved or symlinked)
```

### Step 1: Configure Environment Variables

```bash
# From the ai-codebase-audit repository directory
cp .env.example .env
```

Edit `.env` and set:
- `AUDIT_BASE_DIR`: Absolute path to the workspace directory you created in Step 0
- `ANTHROPIC_API_KEY`: Your Anthropic API key from https://console.anthropic.com/settings/keys

Example `.env`:
```bash
AUDIT_BASE_DIR=/Users/you/code-audits    # ← Path to workspace from Step 0
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

**Important**: `AUDIT_BASE_DIR` must point to the workspace directory you created in Step 0 (the directory containing config.yml, CLAUDE.md, .claude/, AND your projects).

### Step 2: Configure Audit Targets

Edit `config.yml` in your AUDIT_BASE_DIR workspace (`~/code-audits/config.yml`)

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

```bash
docker compose build
docker compose run --rm skills
```

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

## Permission Mode

This runner uses **`bypassPermissions`** mode, which is **hardcoded** and cannot be changed via configuration.

**What this means:**
- Claude automatically approves all tool executions without prompting
- Enables fully autonomous operation in headless Docker environments
- No blocking or waiting for user approval

**Why it's hardcoded:**
- **Reliability:** Ensures the runner never blocks waiting for approvals in headless environments
- **Simplicity:** One less configuration option to worry about
- **Security:** Designed specifically for isolated, ephemeral Docker containers

**Security note:** This runner should only be used in isolated Docker containers. The `bypassPermissions` mode is safe for this use case because:
- Each container is ephemeral (destroyed after completion)
- Working directory is explicitly defined and isolated
- Perfect for automated code audits and CI/CD pipelines
