---
name: audit-dotnet
description: "Performs comprehensive 6-stage audit of .NET/C#/F# codebases with maximum accuracy using independent agents and static analysis (OWASP Top 10, CWE/SANS 25, ASP.NET Core Security)"
user-invocable: true
---

# .NET Codebase Audit - Executable Orchestration

You are orchestrating a complete 6-stage analytical funnel to produce the top 10 highest-priority improvements for this .NET codebase.

## Your Mission

Execute all 7 stages sequentially (Stage 0 is build validation), using specialized agents at each stage. Track progress with TodoWrite and present evaluation checkpoints to the user after key stages.

**IMPORTANT**: You MUST actually execute this audit, not just describe what would happen.

---

## Stage 0: Build Validation (CRITICAL - MANDATORY)

**Objective**: Ensure .NET SDK is installed and the project compiles before analysis. **DO NOT PROCEED** without a successful build.

### Your Actions

1. Create todo tracking with all 7 stages

2. Mark Stage 0 as in_progress

3. **Check for .NET SDK** (MANDATORY - STOP IF MISSING):

```bash
if ! command -v dotnet >/dev/null 2>&1; then
  echo "❌ ERROR: .NET SDK is not installed!"
  echo ""
  echo "The .NET SDK is required to:"
  echo "  - Build the project (validate it compiles)"
  echo "  - Run Roslyn analyzers (built into dotnet build)"
  echo "  - Execute dotnet-outdated (dependency analysis)"
  echo "  - Ensure accurate analysis of C#/F# code"
  echo ""
  echo "Please install the .NET SDK:"
  echo "  • macOS: brew install dotnet"
  echo "  • Linux: https://learn.microsoft.com/en-us/dotnet/core/install/linux"
  echo "  • Windows: https://dotnet.microsoft.com/download"
  echo ""
  echo "After installation, verify with: dotnet --version"
  echo ""
  echo "⛔ Audit cannot proceed without .NET SDK."
  exit 1
fi
```

4. Verify .NET SDK version:

```bash
echo "✅ .NET SDK detected: $(dotnet --version)"
```

5. Detect .NET project:

```bash
# Check for .NET project files
if ! (ls *.csproj >/dev/null 2>&1 || ls *.fsproj >/dev/null 2>&1 || ls *.sln >/dev/null 2>&1); then
  echo "❌ ERROR: No .NET project files found (.csproj, .fsproj, or .sln)"
  echo "Is this a .NET project? Change to the project directory and try again."
  exit 1
fi

# Detect solution or project files
if ls *.sln >/dev/null 2>&1; then
  echo "✅ .NET solution detected: $(ls *.sln | head -1)"
elif ls *.csproj >/dev/null 2>&1; then
  echo "✅ .NET C# project detected: $(ls *.csproj | head -1)"
elif ls *.fsproj >/dev/null 2>&1; then
  echo "✅ .NET F# project detected: $(ls *.fsproj | head -1)"
fi
```

6. Run restore and build:

```bash
echo "Restoring NuGet packages..."
dotnet restore

echo "Building project (Release configuration)..."
dotnet build --no-restore --configuration Release
BUILD_STATUS=$?
```

7. Check build status (STOP IF FAILED):

```bash
if [ $BUILD_STATUS -ne 0 ]; then
  echo ""
  echo "❌ ERROR: Project does not compile!"
  echo ""
  echo "Build errors must be fixed before running the audit."
  echo "Reasons:"
  echo "  - Roslyn analyzers run during compilation"
  echo "  - Cannot analyze code that doesn't build"
  echo "  - Static analysis tools require valid assemblies"
  echo ""
  echo "To see detailed build errors, run:"
  echo "  dotnet build"
  echo ""
  echo "⛔ Audit cannot proceed with build failures."
  exit 1
fi
```

8. Inform user:
```
✅ Build successful! .NET assemblies compiled.
📦 Build configuration: Release
📂 Compiled output ready for analysis.
```

9. Mark Stage 0 as completed

**CRITICAL**: If any of steps 3, 5, or 7 fail, **STOP IMMEDIATELY** and inform the user. Do NOT proceed to Stage 1.

---

## Stage 1: Architecture Artifact Generation

(Similar to Java - detect ASP.NET Core, Blazor, Entity Framework, etc.)

**Prompt for artifact-generator**:
```
You are generating architecture artifacts for this .NET/C# codebase.

IMPORTANT: This is a .NET project. Focus on .NET-specific patterns:
- ASP.NET Core architecture (if detected)
- Dependency Injection patterns (IServiceCollection, scoped/transient/singleton)
- Entity Framework Core patterns (DbContext, migrations)
- Middleware pipeline (if ASP.NET Core)
- API endpoints (look for [ApiController], [HttpGet], [HttpPost])
- Blazor component structure (if Blazor detected)

Output all files to $PROJECT_ROOT/.analysis/dotnet/stage1-artifacts/
```

---

## Stage 2: Parallel Independent Analysis

(Launch 4 agents with .NET-specific prompts)

**Agent 1: architecture-analyzer** - Focus on ASP.NET Core layering, DI patterns, EF Core usage

**Agent 2: security-analyzer** - Focus on ASP.NET Core Identity, CSRF, XSS in Razor, SQL injection in EF

**Agent 3: maintainability-analyzer** - Focus on async/await patterns, LINQ complexity, IDisposable

**Agent 4: dependency-analyzer** - Focus on NuGet packages, outdated ASP.NET Core versions, CVEs

---

## Stage 3: Static Analysis Tools

### Your Actions

1. Create directory:
```bash
mkdir -p $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs
```

2. Mark Stage 3 as in_progress

3. Verify static analysis tools are available:
```bash
echo "Verifying static analysis tools..."
echo "✓ Semgrep: $(semgrep --version 2>&1 | head -1)"
echo "✓ dotnet-outdated: $(dotnet tool list --global | grep dotnet-outdated)"
echo "✓ security-scan: $(dotnet tool list --global | grep security-scan)"
echo ""
echo "Note: All tools are pre-installed in the Docker container."
```

4. Run .NET static analysis tools:

**Tool 1: Semgrep** (OWASP/CWE for C#)
```bash
if command -v semgrep >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/semgrep-runner.sh . $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs/semgrep-report.json
fi
```

**Tool 2: Roslyn Analyzers** (built into dotnet build)
```bash
bash .claude/skills/audit-dotnet/tools/roslyn-analyzer-runner.sh . $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs/roslyn-report.json
```

**Tool 3: Security Code Scan** (NuGet analyzer)
```bash
bash .claude/skills/audit-dotnet/tools/security-code-scan-runner.sh . $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs/security-code-scan-report.json
```

**Tool 4: Snyk** (SAST + Dependencies)
```bash
if command -v snyk >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/snyk-runner.sh . $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs
fi
```

**Tool 5: dotnet-outdated** (Dependency versions)
```bash
bash .claude/skills/audit-dotnet/tools/dotnet-outdated-runner.sh . $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs/dotnet-outdated-report.json
```

**Tool 6: Trivy** (Container/IaC)
```bash
if command -v trivy >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/trivy-runner.sh . $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs/trivy-report.json
fi
```

**Tool 7: SonarQube** (if configured)
```bash
if command -v sonar-scanner >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/sonarqube-runner.sh . $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/raw-outputs/sonarqube-report.json
fi
```

5. Unify results:
```bash
node .claude/skills/audit-dotnet/tools/format-static-results.js $PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis
```

6. Read `tool-comparison.md` and present summary to user

7. Write `$PROJECT_ROOT/.analysis/dotnet/stage3-static-analysis/metadata.json` with tool execution status

8. Mark Stage 3 as completed

---

## Stage 4: Reconciliation

(Same process as Java - synthesize findings with confidence scoring)

---

## Stage 5: Adversarial Challenge

(Same process - challenge findings to eliminate false positives)

.NET-specific false positive patterns:
- Framework-generated code (Entity Framework migrations, Razor compiled views)
- Intentional patterns (async void for event handlers)
- Dependency injection magic (service resolution)

---

## Stage 6: Final Synthesis

**Objective**: Generate top 10 prioritized findings and create executive deliverables.

### Your Actions

1. Create directory:
```bash
mkdir -p $PROJECT_ROOT/.analysis/dotnet/stage6-final-synthesis
```

2. Mark Stage 6 as in_progress

3. Read `$PROJECT_ROOT/.analysis/dotnet/stage5-adversarial/challenged-findings.json`

4. Filter to UPHELD findings only (exclude DISMISSED)

5. Apply prioritization formula to rank findings:

**Prioritization Formula** (.NET-specific weighting):
```
priority_score = (severity_weight × severity_score) +
                 (confidence_weight × confidence_score) +
                 (effort_to_value_weight × effort_value_score) +
                 (dotnet_security_bonus)

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

.NET Security Bonus (add +0.5 to priority_score):
- ASP.NET Core Identity misconfigurations
- CSRF token validation missing
- XSS in Razor views
- SQL injection in Entity Framework
- Async/await deadlock patterns
```

6. Sort by priority_score descending and select top 10

7. Write Stage 6 outputs:
   - `$PROJECT_ROOT/.analysis/dotnet/stage6-final-synthesis/prioritization-matrix.json` (all findings with scores)
   - `$PROJECT_ROOT/.analysis/dotnet/stage6-final-synthesis/top-10-detailed.json` (top 10 with full details)
   - `$PROJECT_ROOT/.analysis/dotnet/stage6-final-synthesis/honorable-mentions.md` (findings 11-20)
   - `$PROJECT_ROOT/.analysis/dotnet/stage6-final-synthesis/quick-wins.md` (low effort, high impact items)
   - `$PROJECT_ROOT/.analysis/dotnet/stage6-final-synthesis/systemic-patterns.md` (recurring .NET issues)
   - `$PROJECT_ROOT/.analysis/dotnet/stage6-final-synthesis/metadata.json` (statistics)

8. Create the final report directory and generate the 4 executive deliverables:

```bash
mkdir -p $PROJECT_ROOT/.analysis/dotnet/final-report
```

**ANALYSIS-REPORT.md**:
```markdown
# .NET Codebase Analysis Report

*Generated: [DATE] | Overall Confidence: [High/Medium] | [X] findings analyzed → Top 10 selected*

## Executive Summary

[1-2 paragraph overview: what was analyzed, methodology (6-stage funnel), key findings summary, overall codebase health assessment for .NET/C#/F# application]

## Methodology

This audit used a 6-stage analytical funnel with independent agents and static analysis:

1. **Build Validation**: Ensured project compiles (dotnet build)
2. **Artifact Generation**: Architecture mapping and tech debt surface analysis
3. **Parallel Independent Analysis**: 4 specialist agents (architecture, security, maintainability, dependency) operating in isolation
4. **Static Analysis**: .NET-specific tools (Semgrep, Roslyn, Security Code Scan, Snyk, dotnet-outdated, Trivy)
5. **Reconciliation**: Statistical convergence analysis across all sources
6. **Adversarial Challenge**: Independent skeptic eliminated false positives
7. **Final Synthesis**: Evidence-based prioritization

**Confidence Principle**: Findings that converged across multiple independent agents AND static tools receive "High" confidence.

## Top 10 Improvements

[For each finding 1-10:]

### [#]. [Critical/High/Medium] [Title]

**Location**: [Controllers/UserController.cs:42-56] (clickable link)
**Confidence**: [High/Medium/Low] (converged: [list agent names] + [list tool names])
**Priority Score**: [X.XX]
**Effort**: [Low/Medium/High]
**Impact**: [Critical/High/Medium/Low]

**Problem**:
[Clear description of what's wrong with .NET-specific context]

**Evidence**:
- Identified by agents: [architecture-analyzer, security-analyzer]
- Identified by tools: [Semgrep (csharp/security/sql-injection), Security Code Scan (SCS0002)]
- Convergence score: [0.85] (high confidence - multiple independent sources)

**Code Example**:
```csharp
// Controllers/UserController.cs:156-162
public async Task<IActionResult> GetUsersByRole(string role)
{
    var query = $"SELECT * FROM Users WHERE Role = '{role}'";  // VULNERABLE
    var users = await _context.Users.FromSqlRaw(query).ToListAsync();
    return Ok(users);
}
```

**Impact**:
[Business/technical impact - why this matters for .NET/ASP.NET Core applications]
- Allows SQL injection attacks via role parameter
- Entire user database could be compromised
- Violates OWASP Top 10 (A03:2021 - Injection)
- CWE-89: SQL Injection vulnerability

**Recommendation**:
Use parameterized queries with Entity Framework:

```csharp
// Fixed version:
public async Task<IActionResult> GetUsersByRole(string role)
{
    var users = await _context.Users
        .Where(u => u.Role == role)  // LINQ prevents injection
        .ToListAsync();
    return Ok(users);
}

// Or with FromSqlRaw using parameters:
public async Task<IActionResult> GetUsersByRole(string role)
{
    var users = await _context.Users
        .FromSqlRaw("SELECT * FROM Users WHERE Role = {0}", role)  // Parameterized
        .ToListAsync();
    return Ok(users);
}
```

**Survived Adversarial Challenge**: Yes - Confirmed as genuine SQL injection risk, not a false positive. Both pattern-based (Semgrep) and Roslyn analyzer tools identified it independently.

---

[Repeat for all 10 findings - EACH MUST INCLUDE actual code snippets from the codebase]

## Summary Statistics

- **Total Findings Analyzed**: [X]
- **High Confidence**: [X] findings (converged across agents + tools)
- **Medium Confidence**: [X] findings
- **Low Confidence**: [X] findings
- **False Positives Dismissed**: [X] findings
- **Severity Adjustments**: [X] findings downgraded

## .NET-Specific Insights

**Most Common Issues**:
1. SQL Injection (Entity Framework raw SQL): [X] instances
2. Missing CSRF protection in POST endpoints: [X] instances
3. Async/await deadlock risks: [X] instances
4. Missing IDisposable implementation: [X] instances

## What Makes These Recommendations Trustworthy

1. **Independent Analysis**: 4 specialist agents analyzed separately (no confirmation bias)
2. **Tool Validation**: 6-7 .NET-specific static analysis tools provided objective verification
3. **Convergence Scoring**: Findings appearing across multiple sources scored higher
4. **Adversarial Challenge**: Independent skeptic eliminated [X] false positives
5. **Evidence Transparency**: Every finding shows which agents/tools identified it AND includes actual code snippets

## Next Steps

1. Review this report and prioritize which findings to address first
2. See `$PROJECT_ROOT/.analysis/dotnet/final-report/FINDINGS-DETAILED.json` for complete structured data
3. See `$PROJECT_ROOT/.analysis/dotnet/final-report/CONFIDENCE-MATRIX.md` for evidence transparency matrix
4. See `$PROJECT_ROOT/.analysis/dotnet/` directory for complete stage-by-stage outputs
5. Consider running `/audit-dotnet` again after fixes to measure improvement

## Full Details

All stage-by-stage outputs available in `$PROJECT_ROOT/.analysis/dotnet/`:
- Stage 0: Build validation logs
- Stage 1: Architecture artifacts
- Stage 2: 4 independent agent analyses
- Stage 3: Static analysis tool results (Semgrep, Roslyn, Security Code Scan, Snyk, dotnet-outdated, Trivy)
- Stage 4: Reconciliation and convergence analysis
- Stage 5: Adversarial challenge results
- Stage 6: Prioritization matrix and patterns
```

9. **Create ARCHITECTURE-OVERVIEW.md**:
```bash
cp $PROJECT_ROOT/.analysis/dotnet/stage1-artifacts/architecture-overview.md $PROJECT_ROOT/.analysis/dotnet/final-report/ARCHITECTURE-OVERVIEW.md
```

10. **Create FINDINGS-DETAILED.json**: Export all upheld findings with complete structure (must include `example` field with `file`, `line_start`, `line_end`, and `code` for each finding)

11. **Create CONFIDENCE-MATRIX.md**: Generate evidence transparency table showing which agents/tools found each finding

Example format:
```markdown
# Confidence Matrix

| Finding | Location | security-analyzer | architecture-analyzer | maintainability-analyzer | dependency-analyzer | Semgrep | Roslyn | Security Code Scan | Snyk | Confidence |
|---------|----------|-------------------|----------------------|-------------------------|---------------------|---------|--------|-------------------|------|------------|
| SQL Injection | UserController.cs:156 | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | High (4 sources) |
...
```

12. Present final summary to user:
```
## Analysis Complete! 🎯

**Executive Deliverables** (in $PROJECT_ROOT/.analysis/dotnet/final-report/):
- ANALYSIS-REPORT.md - Top 10 with detailed recommendations
- ARCHITECTURE-OVERVIEW.md - .NET system architecture documentation
- FINDINGS-DETAILED.json - Complete structured data
- CONFIDENCE-MATRIX.md - Evidence transparency matrix

**Summary**:
- [X] total findings analyzed
- Top 10 selected via evidence-based prioritization
- [X] critical, [X] high, [X] medium severity in top 10
- Average confidence: [High/Medium] ([X]% convergence rate)
- [X] false positives eliminated

**.NET-Specific Findings**:
- ASP.NET Core security issues: [X]
- Entity Framework SQL injection risks: [X]
- Async/await pattern issues: [X]
- Dependency vulnerabilities: [X]

**Next Step**: Review `$PROJECT_ROOT/.analysis/dotnet/final-report/ANALYSIS-REPORT.md` for your prioritized improvements.
```

13. Mark Stage 6 as completed

---

## Error Handling

**If Stage 0 fails** (any of these):
- ❌ .NET SDK not installed → **STOP** - Provide installation instructions, do NOT proceed
- ❌ No .NET project files found → **STOP** - Verify this is a .NET project
- ❌ Build fails → **STOP** - Instruct user to fix build errors first

**DO NOT**:
- Proceed with "partial analysis" when build fails
- Try to analyze without .NET SDK
- Suggest workarounds to skip build validation

**ALWAYS**:
- Stop immediately when Stage 0 validation fails
- Provide clear installation/fix instructions
- Wait for user to resolve the issue before proceeding

(For other errors during Stages 1-6, continue with degraded capabilities but warn user)

---

## Important Reminders

1. **Actually execute each stage**
2. **Use Task tool** to invoke agents
3. **Run Stage 2 agents in PARALLEL**
4. **Update todos** after each stage
5. **.NET-specific focus** - Prioritize ASP.NET Core security, EF Core issues, async/await patterns
6. **Include clickable file:line references** in all outputs (format: `Controllers/UserController.cs:42`)

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
