# Quick Start

Run AI-powered codebase audits in 3 steps.

**Prerequisites**: Python 3.11+ with pip installed
- **Verify**: `python3 --version && pip3 --version`
(see [README.md](README.md#Quick_Start))

---

## 1. Setup

```bash
# Clone and configure
git clone https://github.com/your-org/ai-codebase-audit.git
cd ai-codebase-audit
pip install aiodocker pyyaml python-dotenv
# or
pip3 install aiodocker pyyaml python-dotenv

# Set environment
cp .env.example .env
# Edit .env: add your ANTHROPIC_API_KEY and AUDIT_BASE_DIR path
```

Get your API key: https://console.anthropic.com/settings/keys

---

## 2. Prepare Workspace

```bash
# Create workspace and copy config
mkdir -p ~/code-audits
cp config.yml ~/code-audits/

# Clone your repos to audit
cd ~/code-audits
git clone https://github.com/your-org/your-project

# Configure which skills to run
nano config.yml
```

Edit `config.yml` to list your projects:
```yaml
targets:
  - dir: your-project
    skills: [/audit-java]  # or /audit-javascript, /audit-python, /audit-dotnet
```

---

## 3. Run Analysis

```bash
cd ~/git/ai-codebase-audit
python3 orchestrator_devcontainer.py
```

**First run**: 10-15 minutes (builds Docker image)
**Subsequent runs**: ~5 minutes (uses cached image)

---

## View Results

```bash
# Summary
cat ~/code-audits/logs/summary_*.txt

# Detailed reports
ls ~/code-audits/your-project/.analysis/*/final-report/
```

Results written to `~/code-audits/`:
- `logs/summary_*.txt` - Pass/fail overview
- `logs/summary_*.json` - Machine-readable results
- `<project>/.analysis/<language>/final-report/` - Full analysis

---

## What It Does

Each audit runs 6 automated stages:
1. **Artifact Generation** - Maps codebase structure
2. **Parallel Analysis** - 4 agents analyze architecture, security, dependencies, quality
3. **Static Analysis** - Runs tools (Semgrep, Snyk, Trivy, etc.)
4. **Reconciliation** - Synthesizes findings
5. **Adversarial Review** - Eliminates false positives
6. **Final Report** - Comprehensive markdown with remediation

---

## Available Skills

- `/audit-java` - Java/Spring Boot/Maven/Gradle
- `/audit-javascript` - JavaScript/TypeScript/React/Node.js
- `/audit-python` - Python/Django/Flask
- `/audit-dotnet` - C#/F#/ASP.NET Core

---

## Cost Estimation

Typical costs per skill (claude-sonnet-4-6):
- Small projects (<10K LOC): $0.50 - $2.00
- Medium (10-50K LOC): $2.00 - $6.00
- Large (50-150K LOC): $6.00 - $15.00

Monitor costs using the Claude Console at https://console.anthropic.com

---

## Need Help?

**Troubleshooting**: Set `debug.enabled: true` in config.yml for verbose logs (see [README.md](README.md#debugging))

- **Configuration**: See [README.md](README.md#configuration)
- **Architecture**: See [docs/DEVCONTAINER-ARCHITECTURE.md](docs/DEVCONTAINER-ARCHITECTURE.md)
