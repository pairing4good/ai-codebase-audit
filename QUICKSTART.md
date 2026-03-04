# Quick Start

Run AI-powered security audits in 3 steps. Get your API key: https://console.anthropic.com/settings/keys

---

## Setup

### 1. Create workspace and add projects

```bash
# Create workspace (separate from this repo)
mkdir -p ~/code-audits && cd ~/code-audits

# Copy config files from ai-codebase-audit repo
cp /path/to/ai-codebase-audit/{config.yml,CLAUDE.md} .
cp -r /path/to/ai-codebase-audit/.claude .

# Copy your projects to the workspace
cp -r /path/to/your/java-project ./my-java-app
cp -r /path/to/your/react-app ./my-react-app
```

### 2. Configure

**In the ai-codebase-audit repo** (NOT workspace), create `.env`:
```bash
cd /path/to/ai-codebase-audit
cp .env.example .env
```

Edit `.env`:
```bash
AUDIT_BASE_DIR=/Users/you/code-audits  # Absolute path to workspace
ANTHROPIC_API_KEY=sk-ant-api03-...
```

**In your workspace**, edit `config.yml`:
```bash
nano ~/code-audits/config.yml
```

Set targets:
```yaml
targets:
  - dir: my-java-app        # Must match directory name
    skills: [/audit-java]
  - dir: my-react-app
    skills: [/audit-javascript]
```

### 3. Run

**From the ai-codebase-audit repo** (where `docker-compose.yml` lives):
```bash
cd /path/to/ai-codebase-audit
docker compose build
docker compose run --rm skills
```

---

## Results

Outputs written to your **workspace** (`~/code-audits/`):
- `logs/summary_<timestamp>.txt` - Pass/fail overview
- `logs/result_<project>__<skill>_<timestamp>.txt` - Detailed findings
- `<project>/.analysis/<language>/` - Full analysis artifacts

---

## What it does

Each audit runs 4 independent agents analyzing:
- Architecture & design patterns
- Security vulnerabilities (OWASP Top 10, CWE/SANS 25)
- Dependencies & supply chain risks
- Code quality & maintainability

Then reconciles findings with static analysis tools (Semgrep, Snyk, etc.) and generates a final report.

---

## Advanced

Available skills: `/audit-java`, `/audit-javascript`, `/audit-python`, `/audit-dotnet`

Config options (in workspace `config.yml`):
```yaml
runner:
  model: claude-sonnet-4-6   # or claude-opus-4-6 (3x cost)
  concurrency: 3             # parallel tasks
  max_budget_usd: 10.0       # cost limit per task
```

See [README.md](README.md) for cost estimates, troubleshooting, and security details.
