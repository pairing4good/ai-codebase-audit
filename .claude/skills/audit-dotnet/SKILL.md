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

## Stage 0: Build Validation (CRITICAL - NEW FOR .NET)

**Objective**: Ensure the .NET project compiles before analysis. Roslyn analyzers run during build.

### Your Actions

1. Create todo tracking with all 7 stages

2. Mark Stage 0 as in_progress

3. Detect .NET project:

```bash
# Check for .NET project files
if ls *.csproj >/dev/null 2>&1 || ls *.fsproj >/dev/null 2>&1; then
  echo ".NET project detected"
else
  echo "ERROR: No .csproj or .fsproj found. Is this a .NET project?"
  exit 1
fi
```

4. Run build:

```bash
dotnet restore
dotnet build --no-restore --configuration Release
BUILD_STATUS=$?
```

5. Check build status:

```bash
if [ $BUILD_STATUS -ne 0 ]; then
  echo "ERROR: Project does not compile. Please fix compilation errors before running the audit."
  echo "Run 'dotnet build' to see detailed errors."
  exit 1
fi
```

6. Inform user:
```
✅ Build successful! .NET assemblies compiled.
📦 Build configuration: Release
📂 Compiled output ready for analysis.
```

7. Mark Stage 0 as completed

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

Output all files to .analysis/stage1-artifacts/
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

Run available .NET tools:

**Tool 1: Semgrep** (OWASP/CWE for C#)
```bash
if command -v semgrep >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/semgrep-runner.sh . .analysis/stage3-static-analysis/raw-outputs/semgrep-report.json
fi
```

**Tool 2: Roslyn Analyzers** (built into dotnet build)
```bash
bash .claude/skills/audit-dotnet/tools/roslyn-analyzer-runner.sh . .analysis/stage3-static-analysis/raw-outputs/roslyn-report.json
```

**Tool 3: Security Code Scan** (NuGet analyzer)
```bash
bash .claude/skills/audit-dotnet/tools/security-code-scan-runner.sh . .analysis/stage3-static-analysis/raw-outputs/security-code-scan-report.json
```

**Tool 4: Snyk** (SAST + Dependencies)
```bash
if command -v snyk >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/snyk-runner.sh . .analysis/stage3-static-analysis/raw-outputs
fi
```

**Tool 5: dotnet-outdated** (Dependency versions)
```bash
bash .claude/skills/audit-dotnet/tools/dotnet-outdated-runner.sh . .analysis/stage3-static-analysis/raw-outputs/dotnet-outdated-report.json
```

**Tool 6: Trivy** (Container/IaC)
```bash
if command -v trivy >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/trivy-runner.sh . .analysis/stage3-static-analysis/raw-outputs/trivy-report.json
fi
```

**Tool 7: SonarQube** (if configured)
```bash
if command -v sonar-scanner >/dev/null 2>&1; then
  bash .claude/skills/audit-dotnet/tools/sonarqube-runner.sh . .analysis/stage3-static-analysis/raw-outputs/sonarqube-report.json
fi
```

Unify results:
```bash
node .claude/skills/audit-dotnet/tools/format-static-results.js .analysis/stage3-static-analysis
```

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

**.NET Security Bonus** (add +0.5 to priority_score):
- ASP.NET Core Identity misconfigurations
- CSRF token validation missing
- XSS in Razor views
- SQL injection in Entity Framework
- Async/await deadlock patterns

---

## Error Handling

**If Stage 0 fails (build)**: STOP - Cannot analyze code that doesn't compile

(Rest same as Java)

---

## Important Reminders

1. **Actually execute each stage**
2. **Use Task tool** to invoke agents
3. **Run Stage 2 agents in PARALLEL**
4. **Update todos** after each stage
5. **.NET-specific focus** - Prioritize ASP.NET Core security, EF Core issues, async/await patterns

Begin execution now!
