# Quick Start

Run AI-powered security audits on your codebase in 3 steps.

## 1. Configure

```bash
# Copy environment template
cp .env.example .env

# Edit .env - set these two values:
AUDIT_BASE_DIR=/absolute/path/to/your/audit-parent-directory
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

**Important**: `AUDIT_BASE_DIR` must be the **parent directory** that contains:
- `config.yml`, `CLAUDE.md`, `.claude/` (configuration files)
- `project-one/`, `project-two/`, etc. (your actual project directories)

See [.env.example](.env.example) for a detailed directory structure diagram.

Get your API key: https://console.anthropic.com/settings/keys

## 2. Set targets

Edit `config.yml` in your AUDIT_BASE_DIR:

```yaml
targets:
  - dir: your-project-name
    skills:
      - /audit-java          # for Java projects
      - /audit-javascript    # for JS/TS projects
      - /audit-dotnet        # for C#/F# projects
      - /audit-python        # for Python projects
```

## 3. Run

```bash
docker compose build
docker compose run --rm skills
```

## Results

All output in `<AUDIT_BASE_DIR>/logs/`:
- `summary_<timestamp>.txt` - Pass/fail overview
- `result_<project>__<skill>_<timestamp>.txt` - Detailed findings
- `.analysis/<language>/` in each project - Full analysis artifacts

## What it does

Each audit skill:
1. Analyzes architecture, security, dependencies, maintainability
2. Runs language-specific static analysis tools (Semgrep, Snyk, etc.)
3. Reconciles findings with independent agents
4. Generates final security report with confidence ratings

## Config options

```yaml
runner:
  model: claude-sonnet-4-6   # or claude-opus-4-6
  concurrency: 3             # parallel tasks
  max_turns: 20              # agent conversation limit
  timeout: 300               # seconds per task
  max_budget_usd: 10.0       # cost limit per task
```

## Need help?

- See [README.md](README.md) for full documentation
- Check [CLAUDE.md](CLAUDE.md) for Docker environment details
