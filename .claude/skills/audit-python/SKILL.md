---
name: audit-python
description: "Performs comprehensive 6-stage audit of Python codebases with maximum accuracy using independent agents and static analysis (OWASP Top 10, CWE/SANS 25, Django/Flask Security)"
user-invokable: true
---

# Python Codebase Audit - Executable Orchestration

You are orchestrating a complete 7-stage analytical funnel to produce the top 10 highest-priority improvements for this Python codebase.

## Your Mission

Execute all 7 stages sequentially (Stage 0 is build/environment validation), using specialized agents at each stage. Track progress with TodoWrite and present evaluation checkpoints to the user after key stages.

**IMPORTANT**: You MUST actually execute this audit, not just describe what would happen. Use the Task tool to invoke agents, Bash tool to run commands, and Write tool to create outputs.

---

## Stage 0: Environment Validation (CRITICAL - MANDATORY)

**Objective**: Ensure Python is installed and dependencies are available before analysis. **DO NOT PROCEED** without successful environment setup.

### Your Actions

1. Create todo tracking with all 7 stages (including Stage 0)

2. Mark Stage 0 as in_progress

3. **Check for Python** (MANDATORY - STOP IF MISSING):

```bash
if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  echo "❌ ERROR: Python is not installed!"
  echo ""
  echo "Python is required to:"
  echo "  - Install and verify dependencies (pip, poetry, pipenv)"
  echo "  - Run static analysis tools (Bandit, Pylint, mypy, etc.)"
  echo "  - Validate project setup"
  echo "  - Ensure accurate analysis of Python code"
  echo ""
  echo "Please install Python 3.8+ (recommend Python 3.11 or 3.12):"
  echo "  • macOS: brew install python@3.12"
  echo "  • Linux (Ubuntu): sudo apt install python3 python3-pip python3-venv"
  echo "  • Linux (RHEL): sudo yum install python3 python3-pip"
  echo "  • Windows: https://www.python.org/downloads/"
  echo ""
  echo "After installation, verify with: python3 --version"
  echo ""
  echo "⛔ Audit cannot proceed without Python."
  exit 1
fi
```

4. Verify Python version and determine python command:

```bash
# Determine which python command to use
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
  PIP_CMD="pip3"
else
  PYTHON_CMD="python"
  PIP_CMD="pip"
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo "✅ Python detected: $PYTHON_VERSION"

# Check Python version is 3.8+
PYTHON_MINOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.minor)')
if [ $PYTHON_MINOR -lt 8 ]; then
  echo "⚠️ WARNING: Python 3.$PYTHON_MINOR detected. Python 3.8+ recommended for best analysis coverage."
fi
```

5. Detect project type and dependency manager:

```bash
# Check for Python project indicators
if [ ! -f "setup.py" ] && [ ! -f "pyproject.toml" ] && [ ! -f "requirements.txt" ] && [ ! -f "Pipfile" ]; then
  echo "⚠️ WARNING: No Python dependency files found!"
  echo "Expected one of: setup.py, pyproject.toml, requirements.txt, Pipfile"
  echo ""
  read -p "Continue anyway? This may be a Python project without dependencies (y/n): " CONTINUE
  if [ "$CONTINUE" != "y" ]; then
    echo "⛔ Audit cancelled."
    exit 1
  fi
  DEPENDENCY_MANAGER="none"
else
  # Detect dependency manager
  if [ -f "poetry.lock" ] && command -v poetry >/dev/null 2>&1; then
    echo "✅ Dependency manager: Poetry (poetry.lock detected)"
    DEPENDENCY_MANAGER="poetry"
  elif [ -f "Pipfile.lock" ] && command -v pipenv >/dev/null 2>&1; then
    echo "✅ Dependency manager: Pipenv (Pipfile.lock detected)"
    DEPENDENCY_MANAGER="pipenv"
  elif [ -f "requirements.txt" ]; then
    echo "✅ Dependency manager: pip (requirements.txt detected)"
    DEPENDENCY_MANAGER="pip"
  elif [ -f "pyproject.toml" ]; then
    echo "✅ Dependency manager: pip (pyproject.toml detected)"
    DEPENDENCY_MANAGER="pip"
  elif [ -f "setup.py" ]; then
    echo "✅ Dependency manager: pip (setup.py detected)"
    DEPENDENCY_MANAGER="pip"
  else
    echo "✅ Python project detected (no dependency manager)"
    DEPENDENCY_MANAGER="none"
  fi
fi
```

6. Create virtual environment and install dependencies:

```bash
echo "Setting up Python environment..."

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ] && [ ! -d ".venv" ]; then
  echo "Creating virtual environment..."
  $PYTHON_CMD -m venv .venv
  VENV_CREATED=1
fi

# Activate virtual environment
if [ -d ".venv" ]; then
  source .venv/bin/activate 2>/dev/null || . .venv/bin/activate
elif [ -d "venv" ]; then
  source venv/bin/activate 2>/dev/null || . venv/bin/activate
fi

# Install dependencies based on detected manager
if [ "$DEPENDENCY_MANAGER" = "poetry" ]; then
  echo "Installing dependencies with Poetry..."
  poetry install --no-interaction 2>&1 | tail -20
  INSTALL_STATUS=$?
elif [ "$DEPENDENCY_MANAGER" = "pipenv" ]; then
  echo "Installing dependencies with Pipenv..."
  pipenv install --dev 2>&1 | tail -20
  INSTALL_STATUS=$?
elif [ "$DEPENDENCY_MANAGER" = "pip" ]; then
  echo "Installing dependencies with pip..."
  if [ -f "requirements.txt" ]; then
    $PIP_CMD install -r requirements.txt 2>&1 | tail -20
    INSTALL_STATUS=$?
  elif [ -f "pyproject.toml" ]; then
    $PIP_CMD install -e . 2>&1 | tail -20
    INSTALL_STATUS=$?
  elif [ -f "setup.py" ]; then
    $PIP_CMD install -e . 2>&1 | tail -20
    INSTALL_STATUS=$?
  fi
else
  echo "ℹ️ No dependencies to install."
  INSTALL_STATUS=0
fi
```

7. Check installation status:

```bash
if [ $INSTALL_STATUS -ne 0 ]; then
  echo ""
  echo "⚠️ WARNING: Dependency installation had errors!"
  echo ""
  echo "This may affect analysis accuracy. Common issues:"
  echo "  - Package version conflicts"
  echo "  - Missing system dependencies (e.g., PostgreSQL dev headers)"
  echo "  - Network connectivity issues"
  echo ""
  echo "You can:"
  echo "  1. Fix dependency issues and re-run the audit"
  echo "  2. Continue anyway (analysis may have reduced coverage)"
  echo ""
  read -p "Continue with analysis? (y/n): " CONTINUE
  if [ "$CONTINUE" != "y" ]; then
    echo "⛔ Audit cancelled. Please fix dependency issues first."
    exit 1
  fi
fi
```

8. Detect Python framework:

```bash
# Detect web frameworks and common libraries
echo "Detecting Python frameworks..."

if grep -q "django" requirements.txt pyproject.toml setup.py 2>/dev/null || [ -f "manage.py" ]; then
  echo "✅ Django framework detected"
  FRAMEWORK="django"
elif grep -q "flask" requirements.txt pyproject.toml setup.py 2>/dev/null; then
  echo "✅ Flask framework detected"
  FRAMEWORK="flask"
elif grep -q "fastapi" requirements.txt pyproject.toml setup.py 2>/dev/null; then
  echo "✅ FastAPI framework detected"
  FRAMEWORK="fastapi"
else
  echo "ℹ️ No specific web framework detected (generic Python project)"
  FRAMEWORK="generic"
fi
```

9. Inform user:
```
✅ Stage 0 Complete: Python environment validated
🐍 Python version: [version]
📦 Dependency manager: [poetry/pipenv/pip/none]
🌐 Framework: [django/flask/fastapi/generic]
🔍 Ready for static analysis
```

10. Mark Stage 0 as completed

**CRITICAL**: If step 3 (Python check) fails, **STOP IMMEDIATELY** and inform the user. Do NOT proceed to Stage 1.

For dependency installation failures (step 7), prompt user whether to continue with reduced coverage.

---

## Stage 1: Architecture Artifact Generation

**Objective**: Build comprehensive mental model before any analysis begins.

### Your Actions

1. Create the directory structure:
```bash
mkdir -p .analysis/stage1-artifacts
```

2. Mark Stage 1 as in_progress (todos already initialized in Stage 0)

3. Invoke the `artifact-generator` agent using the Task tool with subagent_type="artifact-generator":

**Prompt for artifact-generator**:
```
You are generating architecture artifacts for this Python codebase.

IMPORTANT: This is a PYTHON project. Focus on Python-specific patterns:
- Django architecture (if detected): models, views, URLs, middleware, settings
- Flask architecture (if detected): blueprints, routes, extensions
- FastAPI architecture (if detected): routers, dependencies, middleware
- Package structure: modules, __init__.py hierarchy
- Entry points: manage.py, app.py, main.py, __main__.py
- Database patterns: Django ORM, SQLAlchemy, async database drivers
- API patterns: REST endpoints, GraphQL (if present)

Your task:
1. Analyze the repository structure comprehensively
2. Generate ALL required artifacts in .analysis/stage1-artifacts/:
   - architecture-overview.md (system purpose, tech stack, framework, architecture layers)
   - component-dependency.mermaid (module/package dependency graph)
   - data-flow-diagrams/ directory with flows for:
     * Authentication flow (Django/Flask-Login if present)
     * Business operation flows (request → view/route → business logic → database)
   - sequence-diagrams/ directory for critical paths:
     * Request handling (HTTP → middleware → view → response)
     * Database transaction patterns
   - entity-relationship.mermaid (Django models or SQLAlchemy models)
   - tech-debt-surface-map.md (high churn files, complexity hotspots, TODO/FIXME debt)
   - metadata.json (statistics: file counts, LOC, dependencies count, Python version)

Python-specific items to include:
- Identify all Django views/viewsets or Flask routes (these are API endpoints)
- Map business logic modules
- Map Django models or SQLAlchemy ORM classes (data layer)
- Document middleware pipeline
- List database connections (settings.py DATABASE config or SQLAlchemy engines)
- Identify async patterns (async def, asyncio, celery tasks)
- Document background tasks (Celery, RQ, APScheduler)

Follow the complete process outlined in your agent definition (.claude/agents/artifact-generator.md).

Output all files to .analysis/stage1-artifacts/
```

4. After the agent completes, read `.analysis/stage1-artifacts/architecture-overview.md` and present a summary to the user

5. Mark Stage 1 as completed

---

## Stage 2: Parallel Independent Analysis

**Objective**: Four specialist agents analyze in complete isolation (no cross-contamination).

### Your Actions

1. Create directory:
```bash
mkdir -p .analysis/stage2-parallel-analysis
```

2. Mark Stage 2 as in_progress

3. **Launch all 4 agents IN PARALLEL** using a single message with 4 Task tool calls:

**CRITICAL**: You MUST send all 4 Task invocations in a SINGLE message to run them in parallel. Do NOT run them sequentially.

**Agent 1: architecture-analyzer**
```
You are analyzing this Python codebase for architectural issues.

IMPORTANT: This is a PYTHON project. Focus on Python-specific architectural patterns.

Read Stage 1 artifacts from .analysis/stage1-artifacts/ for context.

Analyze for Python-specific issues:
- **Django patterns** (if Django detected):
  - Fat models vs fat views (business logic location)
  - Proper use of Django ORM (QuerySets, select_related, prefetch_related)
  - Custom managers vs custom QuerySets
  - Signal usage (are they overused?)
  - Middleware design
  - Settings organization (base/local/production split)

- **Flask patterns** (if Flask detected):
  - Blueprint organization
  - Application factory pattern usage
  - Extension initialization patterns
  - Request context management

- **FastAPI patterns** (if FastAPI detected):
  - Dependency injection usage
  - Router organization
  - Pydantic model design
  - Async/await patterns

- **General Python architecture**:
  - Package structure and modularity
  - Circular imports
  - Proper use of __init__.py
  - Abstract base classes (ABC) usage
  - Design patterns (Factory, Strategy, Observer, etc.)
  - Separation of concerns (business logic vs framework code)
  - Database abstraction (Repository pattern)
  - Configuration management (environment variables, config files)

Common Python architectural anti-patterns to detect:
- God classes (>500 lines, >20 methods)
- Circular dependencies between modules
- Mixing business logic with framework code
- Missing abstraction layers
- Tight coupling to frameworks
- Improper use of global state
- Missing dependency injection
- Monolithic modules (>1000 lines)

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: .analysis/stage2-parallel-analysis/architecture-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/architecture-analyzer.md).
```

**Agent 2: security-analyzer**
```
You are analyzing this Python codebase for security vulnerabilities.

IMPORTANT: This is a PYTHON project. Focus on Python-specific security issues.

Read Stage 1 artifacts from .analysis/stage1-artifacts/ for context.

Analyze for Python-specific OWASP Top 10 vulnerabilities:

1. **SQL Injection**:
   - String concatenation in raw SQL queries
   - Unsafe use of Django's .raw() or .extra()
   - SQLAlchemy text() without bound parameters
   - Example: cursor.execute("SELECT * FROM users WHERE id = " + user_id) (VULNERABLE)

2. **Command Injection**:
   - os.system() with user input
   - subprocess.call/run with shell=True and user input
   - eval() or exec() with user-controlled data

3. **Path Traversal**:
   - File operations with unsanitized user input
   - open(user_input) without validation
   - Missing checks for .. in file paths

4. **Insecure Deserialization**:
   - pickle.loads() on untrusted data
   - yaml.load() without SafeLoader
   - Accepting serialized objects from users

5. **Authentication and Authorization Flaws**:
   - Django: Missing @login_required decorators
   - Flask: Missing @login_required or custom auth checks
   - FastAPI: Missing OAuth2/JWT validation
   - Weak password hashing (MD5, SHA1 instead of bcrypt/Argon2)
   - Missing CSRF protection in forms
   - Session fixation vulnerabilities

6. **Sensitive Data Exposure**:
   - Hardcoded secrets in source code
   - API keys, passwords in settings.py or .env committed to git
   - Logging sensitive data (passwords, tokens, SSNs)
   - Missing encryption for sensitive fields
   - DEBUG=True in production

7. **Security Misconfiguration**:
   - Django: ALLOWED_HOSTS = ['*']
   - Django: SECRET_KEY hardcoded or weak
   - Flask: app.debug = True in production
   - CORS misconfiguration (overly permissive origins)
   - Missing security headers (CSP, HSTS, X-Frame-Options)
   - Insecure cookies (missing HttpOnly, Secure flags)

8. **Cross-Site Scripting (XSS)**:
   - Django: Using |safe or mark_safe on user input
   - Flask: render_template_string with user input
   - Jinja2: autoescape=False with user data
   - Missing output encoding

9. **XML External Entity (XXE)**:
   - xml.etree.ElementTree.parse() without defusedxml
   - lxml without secure defaults
   - Unsafe XML parsing

10. **Server-Side Request Forgery (SSRF)**:
    - requests.get(user_provided_url) without validation
    - Missing URL validation for internal resources

Django-specific security checks:
- CSRF token validation disabled
- Weak Django admin security
- Missing Content Security Policy
- Template injection via render_template_string

Flask-specific security checks:
- session.permanent without PERMANENT_SESSION_LIFETIME
- Missing Talisman or similar security extensions
- Unsafe Jinja2 templates

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: .analysis/stage2-parallel-analysis/security-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/security-analyzer.md).
```

**Agent 3: maintainability-analyzer**
```
You are analyzing this Python codebase for code quality and technical debt.

IMPORTANT: This is a PYTHON project. Focus on Python-specific code quality issues.

Read Stage 1 artifacts from .analysis/stage1-artifacts/ for context.

Analyze for Python-specific code quality issues:
- **Complexity metrics**:
  - Cyclomatic complexity >10 (too many branches)
  - Cognitive complexity (nested loops, conditionals)
  - Function length >50 lines
  - Class length >500 lines

- **Code duplication**:
  - Copy-pasted code blocks
  - Similar functions that should be refactored
  - Repeated logic across modules

- **PEP 8 compliance**:
  - Line length >79 characters (or >120 if project uses black)
  - Incorrect indentation (spaces vs tabs)
  - Missing docstrings for public functions/classes
  - Improper naming conventions (snake_case for functions, PascalCase for classes)

- **Type hints**:
  - Missing type annotations (Python 3.5+)
  - Inconsistent typing usage
  - Use of Any when specific types are known

- **Exception handling**:
  - Bare except: clauses (should catch specific exceptions)
  - Catching Exception when more specific exception available
  - Swallowing exceptions without logging
  - Raising generic Exception instead of specific types

- **Python idioms**:
  - Not using list comprehensions where appropriate
  - Using range(len(x)) instead of enumerate
  - Mutable default arguments (def func(arg=[]))
  - Not using context managers (with statement) for resources
  - Using isinstance checks instead of duck typing

- **Import management**:
  - Wildcard imports (from module import *)
  - Unused imports
  - Import order violations (stdlib, third-party, local)
  - Circular imports

- **Testing**:
  - Test coverage percentage
  - Missing unit tests for critical functions
  - Missing integration tests
  - Test quality (assertions, mocking)

- **Documentation**:
  - Missing module-level docstrings
  - Missing class/function docstrings
  - Outdated docstrings
  - Missing README or poor documentation
  - TODO/FIXME/XXX comments (technical debt markers)

- **Dead code**:
  - Unreachable code paths
  - Unused functions/classes
  - Commented-out code blocks

- **Django/Flask specific**:
  - Django: Missing migrations for model changes
  - Django: N+1 query problems (missing select_related/prefetch_related)
  - Flask: Missing error handlers (@app.errorhandler)

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: .analysis/stage2-parallel-analysis/maintainability-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/maintainability-analyzer.md).
```

**Agent 4: dependency-analyzer**
```
You are analyzing this Python codebase for dependency and supply chain issues.

IMPORTANT: This is a PYTHON project. Analyze pip/poetry/pipenv dependencies.

Read requirements.txt, pyproject.toml, Pipfile, or setup.py.

Analyze for Python-specific dependency issues:
- **Outdated dependencies**:
  - Old Django versions (check against latest LTS)
  - Old Flask versions
  - Old requests library (security fixes)
  - Old cryptography library (CVEs)
  - Python version (Python 2.7 is EOL, Python 3.7 is EOL)

- **Known CVEs**:
  - Django CVEs (check Django security releases)
  - Flask CVEs
  - Pillow vulnerabilities (image processing)
  - requests vulnerabilities
  - PyYAML unsafe loading
  - cryptography library CVEs
  - SQLAlchemy vulnerabilities

- **Dependency conflicts**:
  - Version pinning conflicts
  - Incompatible dependency versions
  - Missing upper bounds (should use Django>=3.2,<4.0)

- **Unpinned dependencies**:
  - Dependencies without version constraints (risky)
  - Using latest versions (no upper bound)
  - Missing lock files (requirements.txt without versions)

- **Unused dependencies**:
  - Packages declared but not imported
  - Development dependencies in production requirements

- **Missing dependencies**:
  - Imports without corresponding requirements
  - Implicit dependencies (transitive deps relied upon)

- **License compliance**:
  - GPL/LGPL dependencies in commercial applications
  - Incompatible license combinations
  - Missing license information

- **Dependency quality**:
  - Unmaintained packages (last updated >2 years ago)
  - Packages with few GitHub stars/contributors
  - Packages without recent releases

- **Supply chain security**:
  - Typosquatting risks (similar package names)
  - Packages from untrusted PyPI sources
  - Missing package signature verification

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: .analysis/stage2-parallel-analysis/dependency-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/dependency-analyzer.md).
```

4. After ALL agents complete, read all 4 JSON outputs

5. Generate a convergence preview by identifying findings that appear in multiple agent outputs:
   - Group findings by file:line location
   - Count how many agents flagged each location
   - Write `.analysis/stage2-parallel-analysis/convergence-preview.md` showing multi-agent findings
   - Write `.analysis/stage2-parallel-analysis/metadata.json` with counts

6. Present convergence preview to user showing high-confidence findings

7. Mark Stage 2 as completed

---

## Stage 3: Static Analysis Tools

**Objective**: Run Python-specific static analysis tools for objective validation.

### Your Actions

1. Create directory:
```bash
mkdir -p .analysis/stage3-static-analysis/raw-outputs
```

2. Mark Stage 3 as in_progress

3. **Auto-install missing tools** (attempts automatic installation where possible):
```bash
echo "Checking and installing static analysis tools..."
bash .claude/skills/audit-python/tools/auto-install-tools.sh
```

4. Detect available tools and run them:

**Tool 1: Semgrep** (OWASP Top 10, CWE/SANS 25 for Python)
```bash
if command -v semgrep >/dev/null 2>&1; then
  echo "Running Semgrep with Python OWASP/CWE rulesets..."
  bash .claude/skills/audit-python/tools/semgrep-runner.sh . .analysis/stage3-static-analysis/raw-outputs/semgrep-report.json
else
  echo "⚠️ Semgrep not installed (optional but recommended)"
fi
```

**Tool 2: Bandit** (Python security issues - OWASP focused)
```bash
if command -v bandit >/dev/null 2>&1 || $PIP_CMD list | grep -q bandit; then
  echo "Running Bandit for Python security analysis..."
  bash .claude/skills/audit-python/tools/bandit-runner.sh . .analysis/stage3-static-analysis/raw-outputs/bandit-report.json
else
  echo "⚠️ Bandit not installed (will attempt to install)"
fi
```

**Tool 3: Pylint** (Code quality, PEP 8, complexity)
```bash
if command -v pylint >/dev/null 2>&1 || $PIP_CMD list | grep -q pylint; then
  echo "Running Pylint for code quality analysis..."
  bash .claude/skills/audit-python/tools/pylint-runner.sh . .analysis/stage3-static-analysis/raw-outputs/pylint-report.json
else
  echo "⚠️ Pylint not installed (will attempt to install)"
fi
```

**Tool 4: mypy** (Type checking)
```bash
if command -v mypy >/dev/null 2>&1 || $PIP_CMD list | grep -q mypy; then
  echo "Running mypy for static type checking..."
  bash .claude/skills/audit-python/tools/mypy-runner.sh . .analysis/stage3-static-analysis/raw-outputs/mypy-report.json
else
  echo "⚠️ mypy not installed (optional)"
fi
```

**Tool 5: Safety** (Dependency CVE scanning)
```bash
if command -v safety >/dev/null 2>&1 || $PIP_CMD list | grep -q safety; then
  echo "Running Safety for dependency vulnerability scanning..."
  bash .claude/skills/audit-python/tools/safety-runner.sh . .analysis/stage3-static-analysis/raw-outputs/safety-report.json
else
  echo "⚠️ Safety not installed (will attempt to install)"
fi
```

**Tool 6: Snyk** (SAST + Dependencies)
```bash
if command -v snyk >/dev/null 2>&1; then
  echo "Running Snyk Code and Open Source analysis..."
  bash .claude/skills/audit-python/tools/snyk-runner.sh . .analysis/stage3-static-analysis/raw-outputs
else
  echo "⚠️ Snyk not installed (optional but recommended for CVE detection)"
fi
```

**Tool 7: Trivy** (Container/IaC/Dependencies)
```bash
if command -v trivy >/dev/null 2>&1; then
  echo "Running Trivy for container and dependency scanning..."
  bash .claude/skills/audit-python/tools/trivy-runner.sh . .analysis/stage3-static-analysis/raw-outputs/trivy-report.json
else
  echo "⚠️ Trivy not installed (optional)"
fi
```

**Tool 8: Radon** (Complexity metrics)
```bash
if command -v radon >/dev/null 2>&1 || $PIP_CMD list | grep -q radon; then
  echo "Running Radon for complexity analysis..."
  bash .claude/skills/audit-python/tools/radon-runner.sh . .analysis/stage3-static-analysis/raw-outputs/radon-report.json
else
  echo "⚠️ Radon not installed (optional)"
fi
```

**Tool 9: SonarQube** (if configured)
```bash
if [ -f "sonar-project.properties" ] && command -v sonar-scanner >/dev/null 2>&1; then
  echo "Running SonarQube Scanner..."
  bash .claude/skills/audit-python/tools/sonarqube-runner.sh . .analysis/stage3-static-analysis/raw-outputs/sonarqube-report.json
else
  echo "⚠️ SonarQube not configured (optional)"
fi
```

5. Unify results using format-static-results.js:
```bash
node .claude/skills/audit-python/tools/format-static-results.js .analysis/stage3-static-analysis
```

This creates:
- `.analysis/stage3-static-analysis/unified-results.json` (normalized format)
- `.analysis/stage3-static-analysis/tool-comparison.md` (which tools found what)
- `.analysis/stage3-static-analysis/overlap-analysis.json` (convergence across tools)

6. Read `tool-comparison.md` and present summary to user

7. Write `.analysis/stage3-static-analysis/metadata.json` with tool execution status

8. Mark Stage 3 as completed

---

## Stage 4: Reconciliation

**Objective**: Synthesize findings from all sources with statistical confidence scoring.

### Your Actions

1. Create directory:
```bash
mkdir -p .analysis/stage4-reconciliation
```

2. Mark Stage 4 as in_progress

3. Invoke the `reconciliation-agent` using Task tool with subagent_type="reconciliation-agent":

**Prompt for reconciliation-agent**:
```
You are synthesizing findings from multiple independent sources for a PYTHON codebase.

You have NEVER analyzed this codebase before. You are coming to this fresh with no prior analytical bias.

Your inputs:
- Stage 1 artifacts: .analysis/stage1-artifacts/ (Python architecture context)
- Stage 2 agent outputs: .analysis/stage2-parallel-analysis/*.json (4 independent analyses)
- Stage 3 static analysis: .analysis/stage3-static-analysis/unified-results.json (Python tool findings)

Your task:
1. Read ALL inputs
2. Index findings by location (file:line)
3. Perform convergence analysis (which findings appear across multiple sources?)
4. Calculate confidence scores using the formula in your agent definition
5. Identify contradictions (agent vs tool disagreements)
6. Generate merged longlist with evidence tracking

Output to .analysis/stage4-reconciliation/:
- reconciled-longlist.json (all findings with confidence scores and evidence)
- convergence-analysis.md (which findings converged across sources)
- agent-only-findings.md (findings only agents caught)
- tool-only-findings.md (findings only tools caught)
- contradictions.md (disagreements requiring human review)
- metadata.json (statistics)

Follow the complete process in your agent definition (.claude/agents/reconciliation-agent.md).

Confidence levels:
- High (0.8-1.0): 2+ agents AND 1+ tool
- Medium (0.5-0.79): 2+ agents OR 2+ tools
- Low (0.0-0.49): Single source only
```

4. After completion, read `convergence-analysis.md` and show user the high-confidence findings count

5. Mark Stage 4 as completed

---

## Stage 5: Adversarial Challenge

**Objective**: Independent agent challenges findings to eliminate false positives.

### Your Actions

1. Create directory:
```bash
mkdir -p .analysis/stage5-adversarial
```

2. Mark Stage 5 as in_progress

3. Invoke the `adversarial-agent` using Task tool with subagent_type="adversarial-agent":

**Prompt for adversarial-agent**:
```
You are challenging reconciled findings from a PYTHON codebase to eliminate false positives.

You have NEVER been involved in this audit before. You are the independent skeptic.

Your input:
- Reconciled findings: .analysis/stage4-reconciliation/reconciled-longlist.json

Your task:
Attack each finding using the 5-point challenge framework:
1. Is this actually a problem? (false positive detection)
2. Is severity overstated? (inflation detection)
3. Is evidence valid? (verification)
4. Is this intentional design? (context understanding)
5. Does this matter in context? (priority assessment)

Python-specific false positive patterns to watch for:
- Test code misidentified as production code
- Django migrations (auto-generated code)
- Virtual environment files (venv/, .venv/)
- __pycache__ and .pyc files
- Third-party packages in local vendor/ directories
- Intentional patterns (use of eval in specific safe contexts, pickle for internal caching)
- Django management commands (intentional use of raw SQL)
- Type stubs (.pyi files)

For each finding, issue one of three verdicts:
- UPHELD: Finding is valid as stated
- DOWNGRADED: Valid but severity overstated (adjust severity)
- DISMISSED: False positive (remove from consideration)

Expected metrics:
- Upheld: 70-85%
- Downgraded: 10-20%
- Dismissed: 5-15%

Output to .analysis/stage5-adversarial/:
- challenged-findings.json (all findings with verdicts and adjusted severity)
- false-positives-identified.md (dismissed findings with reasoning)
- severity-adjustments.md (downgraded findings with justification)
- missing-context.md (findings needing more information)
- metadata.json (statistics)

Follow the complete process in your agent definition (.claude/agents/adversarial-agent.md).

Be SKEPTICAL. Make findings prove they deserve to be in the top 10.
```

4. After completion, read `false-positives-identified.md` and show user what was dismissed

5. Mark Stage 5 as completed

---

## Stage 6: Final Synthesis and Deliverable Generation

**Objective**: Generate top 10 prioritized findings and create executive deliverables.

### Your Actions

1. Create directory:
```bash
mkdir -p .analysis/stage6-final-synthesis
```

2. Mark Stage 6 as in_progress

3. Read `.analysis/stage5-adversarial/challenged-findings.json`

4. Filter to UPHELD findings only (exclude DISMISSED)

5. Apply prioritization formula to rank findings:

**Prioritization Formula** (Python-specific weighting):
```
priority_score = (severity_weight × severity_score) +
                 (confidence_weight × confidence_score) +
                 (effort_to_value_weight × effort_value_score) +
                 (python_security_bonus)

Weights:
- severity_weight: 0.4
- confidence_weight: 0.3
- effort_to_value_weight: 0.3

Severity scores:
- critical: 4
- high: 3
- medium: 2
- low: 1

Confidence scores:
- high: 3
- medium: 2
- low: 1

Effort-to-value scores (estimate):
- Low effort, high value: 3
- Medium effort, high value: 2
- High effort: 1

Python Security Bonus (add +0.5 to priority_score):
- SQL Injection vulnerabilities
- Command Injection (os.system, subprocess with shell=True)
- Insecure deserialization (pickle.loads on user data)
- Django/Flask security misconfigurations
- Hardcoded secrets in code
```

6. Sort by priority_score descending and select top 10

7. Write Stage 6 outputs:
   - `.analysis/stage6-final-synthesis/prioritization-matrix.json` (all findings with scores)
   - `.analysis/stage6-final-synthesis/top-10-detailed.json` (top 10 with full details)
   - `.analysis/stage6-final-synthesis/honorable-mentions.md` (findings 11-20)
   - `.analysis/stage6-final-synthesis/quick-wins.md` (low effort, high impact items)
   - `.analysis/stage6-final-synthesis/systemic-patterns.md` (recurring Python issues)
   - `.analysis/stage6-final-synthesis/metadata.json` (statistics)

8. Create the final report directory and generate the 4 executive deliverables:

```bash
mkdir -p .analysis/final-report
```

**ANALYSIS-REPORT.md**:
```markdown
# Python Codebase Analysis Report

*Generated: [DATE] | Overall Confidence: [High/Medium] | [X] findings analyzed → Top 10 selected*

## Executive Summary

[1-2 paragraph overview: what was analyzed, methodology (7-stage funnel including environment validation), key findings summary, overall codebase health assessment for Python application]

## Methodology

This audit used a 7-stage analytical funnel with independent agents and static analysis:

1. **Environment Validation**: Ensured Python installed and dependencies set up
2. **Artifact Generation**: Architecture mapping and tech debt surface analysis
3. **Parallel Independent Analysis**: 4 specialist agents (architecture, security, maintainability, dependency) operating in isolation
4. **Static Analysis**: Python-specific tools (Semgrep, Bandit, Pylint, mypy, Safety, Radon, Snyk, Trivy)
5. **Reconciliation**: Statistical convergence analysis across all sources
6. **Adversarial Challenge**: Independent skeptic eliminated false positives
7. **Final Synthesis**: Evidence-based prioritization

**Confidence Principle**: Findings that converged across multiple independent agents AND static tools receive "High" confidence.

## Top 10 Improvements

[For each finding 1-10:]

### [#]. [Critical/High/Medium] [Title]

**Location**: [app/views.py:42-56](app/views.py#L42-L56) (clickable link)
**Confidence**: [High/Medium/Low] (converged: [list agent names] + [list tool names])
**Priority Score**: [X.XX]
**Effort**: [Low/Medium/High]
**Impact**: [Critical/High/Medium/Low]

**Problem**:
[Clear description of what's wrong with Python-specific context]

**Evidence**:
- Identified by agents: [architecture-analyzer, security-analyzer]
- Identified by tools: [Semgrep (python.django.security.sql-injection), Bandit (B608)]
- Convergence score: [0.85] (high confidence - multiple independent sources)

**Code Example**:
```python
# app/views.py:156-162
def get_users_by_role(request):
    role = request.GET.get('role')
    # VULNERABLE - SQL injection via string concatenation
    query = f"SELECT * FROM users WHERE role = '{role}'"
    cursor = connection.cursor()
    cursor.execute(query)
    return JsonResponse({'users': cursor.fetchall()})
```

**Impact**:
[Business/technical impact - why this matters for Python/Django/Flask applications]
- Allows SQL injection attacks via role parameter
- Entire user database could be compromised
- Violates OWASP Top 10 (A03:2021 - Injection)
- CWE-89: SQL Injection vulnerability

**Recommendation**:
Use parameterized queries with Django ORM or cursor parameters:

```python
# Fixed version using Django ORM:
from django.contrib.auth.models import User

def get_users_by_role(request):
    role = request.GET.get('role')
    users = User.objects.filter(groups__name=role)  # ORM prevents injection
    return JsonResponse({'users': list(users.values())})

# Or with raw SQL using parameters:
def get_users_by_role(request):
    role = request.GET.get('role')
    query = "SELECT * FROM users WHERE role = %s"  # Parameterized
    cursor = connection.cursor()
    cursor.execute(query, [role])  # Passes parameter safely
    return JsonResponse({'users': cursor.fetchall()})
```

**Survived Adversarial Challenge**: Yes - Confirmed as genuine SQL injection risk, not a false positive. Both pattern-based (Semgrep) and security-focused (Bandit) tools identified it independently.

---

[Repeat for all 10 findings - EACH MUST INCLUDE actual code snippets from the codebase]

## Summary Statistics

- **Total Findings Analyzed**: [X]
- **High Confidence**: [X] findings (converged across agents + tools)
- **Medium Confidence**: [X] findings
- **Low Confidence**: [X] findings
- **False Positives Dismissed**: [X] findings
- **Severity Adjustments**: [X] findings downgraded

## Python-Specific Insights

**Most Common Issues**:
1. SQL Injection (raw queries with string formatting): [X] instances
2. Missing CSRF protection: [X] instances
3. Hardcoded secrets: [X] instances
4. Insecure deserialization (pickle): [X] instances

## What Makes These Recommendations Trustworthy

1. **Independent Analysis**: 4 specialist agents analyzed separately (no confirmation bias)
2. **Tool Validation**: 8-9 Python-specific static analysis tools provided objective verification
3. **Convergence Scoring**: Findings appearing across multiple sources scored higher
4. **Adversarial Challenge**: Independent skeptic eliminated [X] false positives
5. **Evidence Transparency**: Every finding shows which agents/tools identified it AND includes actual code snippets

## Next Steps

1. Review this report and prioritize which findings to address first
2. See `.analysis/final-report/FINDINGS-DETAILED.json` for complete structured data
3. See `.analysis/final-report/CONFIDENCE-MATRIX.md` for evidence transparency matrix
4. See `.analysis/` directory for complete stage-by-stage outputs
5. Consider running `/audit-python` again after fixes to measure improvement

## Full Details

All stage-by-stage outputs available in `.analysis/`:
- Stage 0: Environment validation logs
- Stage 1: Architecture artifacts
- Stage 2: 4 independent agent analyses
- Stage 3: Static analysis tool results (Semgrep, Bandit, Pylint, mypy, Safety, Radon, Snyk, Trivy)
- Stage 4: Reconciliation and convergence analysis
- Stage 5: Adversarial challenge results
- Stage 6: Prioritization matrix and patterns
```

**`.analysis/final-report/ARCHITECTURE-OVERVIEW.md`**: Copy from `.analysis/stage1-artifacts/architecture-overview.md`

**`.analysis/final-report/FINDINGS-DETAILED.json`**: Export all upheld findings with complete structure (must include `example` field with `file`, `line_start`, `line_end`, and `code` for each finding)

**`.analysis/final-report/CONFIDENCE-MATRIX.md`**: Create evidence transparency table showing which agents/tools found each finding

9. Present final summary to user:
```
## Analysis Complete! 🎯

**Executive Deliverables** (in .analysis/final-report/):
- ANALYSIS-REPORT.md - Top 10 with detailed recommendations
- ARCHITECTURE-OVERVIEW.md - Python system architecture documentation
- FINDINGS-DETAILED.json - Complete structured data
- CONFIDENCE-MATRIX.md - Evidence transparency matrix

**Summary**:
- [X] total findings analyzed
- Top 10 selected via evidence-based prioritization
- [X] critical, [X] high, [X] medium severity in top 10
- Average confidence: [High/Medium] ([X]% convergence rate)
- [X] false positives eliminated

**Python-Specific Findings**:
- Django/Flask security issues: [X]
- SQL Injection risks: [X]
- Command Injection: [X]
- Dependency vulnerabilities: [X]

**Next Step**: Review `.analysis/final-report/ANALYSIS-REPORT.md` for your prioritized improvements.
```

10. Mark Stage 6 as completed

---

## Error Handling

**If Stage 0 fails** (any of these):
- ❌ Python not installed → **STOP** - Provide installation instructions, do NOT proceed
- ❌ No Python project files found → **PROMPT USER** - Ask if this is a Python project without deps or stop
- ❌ Dependency installation fails → **PROMPT USER** - Ask whether to continue with reduced coverage or stop

**DO NOT**:
- Proceed without Python installed
- Skip dependency installation entirely without asking
- Ignore missing project indicators without confirmation

**ALWAYS**:
- Stop immediately when Python is missing
- Provide clear installation instructions
- Give user choice on dependency/project detection failures

**For other stages**:
- **Stage 1 fails**: STOP - Cannot continue without architecture artifacts
- **Stage 2 agent fails**: Log warning, continue with available agents (minimum 2 required)
- **Stage 3 tools unavailable**: Continue with agent-only analysis (note lower confidence in report)
- **Stage 4 reconciliation fails**: STOP - Cannot continue to adversarial challenge
- **Stage 5 adversarial fails**: Fallback to Stage 4 reconciled findings (note in report)
- **Stage 6 fails**: Debug and retry - all inputs should be ready

---

## Important Reminders

1. **Actually execute each stage** - Don't just describe what would happen
2. **Use Task tool** to invoke agents with proper subagent_type
3. **Run Stage 2 agents in PARALLEL** - Single message with 4 Task calls
4. **Update todos** after each stage completion
5. **Present checkpoints** to user after key stages
6. **Write actual files** - Not just summaries
7. **Include clickable file:line references** in all outputs (format: `app/views.py:42`)
8. **Be thorough** - This is a comprehensive audit, not a quick scan
9. **Python-specific focus** - Prioritize Django/Flask security, SQL injection, command injection, pickle deserialization

## CRITICAL: Evidence Requirements

**EVERY finding MUST include**:
1. **Exact location**: `file:line` or `file:line-range` format
2. **Actual code snippet**: Copy the problematic code from the file (not paraphrased)
3. **Multiple sources**: List which agents AND which tools identified it
4. **Convergence score**: Calculate based on number of independent sources

**Validation checklist before Stage 6 completion**:
- [ ] All top 10 findings have exact `file:line` references
- [ ] All top 10 findings include actual code snippets from the codebase
- [ ] Code snippets show the ACTUAL vulnerable/problematic code (not examples)
- [ ] Each finding lists specific agents and tools that identified it
- [ ] Recommendations include fixed code examples

**If a finding lacks evidence** (no file:line or code snippet):
- It should be downgraded in priority OR
- Marked as "needs investigation" OR
- Excluded from top 10 (replaced with next best finding that HAS evidence)

Begin execution now!
