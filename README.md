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
   - Renames any existing `.claude/`  → `OLD-.claude/`
   - Renames any existing `CLAUDE.md` → `OLD-CLAUDE.md`
   - Copies `AUDIT_BASE_DIR/.claude/`       → `<project>/.claude/`
   - Copies `AUDIT_BASE_DIR/CLAUDE.md`      → `<project>/CLAUDE.md`

`run_skills.py` then runs all skills in parallel directly against the project
directories. Claude is invoked with `cwd` set to the project directory and
finds `CLAUDE.md` and `.claude/` immediately at its root.

Skills write output to `.analysis/<language>/` inside each project, keeping
parallel runs isolated with no risk of conflicts.

Duplicate skills listed for the same directory are skipped — each
`(directory, skill)` pair runs exactly once.

---

## Setup

### 1. Copy `.env.example` → `.env` and configure

```bash
cp .env.example .env
```

Edit `.env` and set:
- `AUDIT_BASE_DIR`: Absolute path to your **parent directory** containing config.yml, CLAUDE.md, .claude/, and project directories
- `ANTHROPIC_API_KEY`: Your Anthropic API key from https://console.anthropic.com/settings/keys

Example `.env`:
```bash
AUDIT_BASE_DIR=/Users/you/code-audits
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

**Important**: `AUDIT_BASE_DIR` should point to the parent directory that contains your projects, NOT to a single project directory. See "Directory Structure" above for details.

### 2. Edit `config.yml` in your AUDIT_BASE_DIR

Configure your runner settings and target projects:

```yaml
runner:
  model: claude-sonnet-4-6
  concurrency: 3
  max_turns: 20
  timeout: 300
  max_budget_usd: 10.0  # Cost protection per task in USD

targets:
  - dir: project-one
    skills:
      - /audit-java
      - /audit-javascript

  - dir: project-two
    skills:
      - /audit-dotnet
```

### 3. Build and run

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

## Logs

All in `<AUDIT_BASE_DIR>/logs/`:

| File | Contents |
|---|---|
| `docker_<ts>.log` | Startup, validation, prep, shutdown |
| `python_<ts>.log` | Task queue, start, ok, fail |
| `task_<dir>__<skill>_<ts>.log` | Full per-task output |
| `result_<dir>__<skill>_<ts>.txt` | Skill's final output |
| `summary_<ts>.txt` | Pass/fail table |
| `summary_<ts>.json` | Machine-readable results |

---

## config.yml options

| Key | Default | Description |
|---|---|---|
| `runner.model` | `claude-sonnet-4-6` | Model to use (`claude-sonnet-4-6` or `claude-opus-4-6`) |
| `runner.concurrency` | `3` | Max parallel tasks |
| `runner.max_turns` | `20` | Max agent turns per task |
| `runner.timeout` | `300` | Per-task timeout in seconds |
| `runner.max_budget_usd` | `10.0` | Spending limit per task in USD |

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
