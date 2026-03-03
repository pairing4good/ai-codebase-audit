# Quick Start

Run AI-powered security audits on your codebase in 4 steps.

## 1. Create your audit workspace

First, create a dedicated directory that will contain everything for your audits:

```bash
# Create audit workspace directory
mkdir -p ~/code-audits
cd ~/code-audits

# Copy the required configuration files from this repo
cp /path/to/this/repo/config.yml .
cp /path/to/this/repo/CLAUDE.md .
cp -r /path/to/this/repo/.claude .

# Move or symlink your project(s) into this directory
# Option A: Move existing projects here
mv /path/to/your/java-project ./my-java-app
mv /path/to/your/react-app ./my-react-app

# Option B: Create symlinks (recommended if projects are elsewhere)
ln -s /path/to/your/java-project ./my-java-app
ln -s /path/to/your/react-app ./my-react-app
```

Your workspace should now look like:
```
~/code-audits/              ← This becomes your AUDIT_BASE_DIR
  ├── config.yml            ← Copied from repo
  ├── CLAUDE.md             ← Copied from repo
  ├── .claude/              ← Copied from repo
  ├── my-java-app/          ← Your project (moved or symlinked)
  └── my-react-app/         ← Your project (moved or symlinked)
```

## 2. Configure environment

```bash
# From the ai-codebase-audit repo directory
cp .env.example .env

# Edit .env - set these two values:
AUDIT_BASE_DIR=/Users/you/code-audits  # ← Path to the workspace you just created
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

**Important**: `AUDIT_BASE_DIR` points to the workspace directory you created in step 1.

Get your API key: https://console.anthropic.com/settings/keys

## 3. Set targets

Edit `config.yml` in your AUDIT_BASE_DIR (~/code-audits/config.yml):

```yaml
targets:
  - dir: my-java-app       # ← Must match directory name in step 1
    skills:
      - /audit-java

  - dir: my-react-app      # ← Must match directory name in step 1
    skills:
      - /audit-javascript
```

**Important**: The `dir:` values must exactly match your project directory names from step 1.

## 4. Run

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
