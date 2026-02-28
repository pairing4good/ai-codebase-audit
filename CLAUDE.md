# AI Codebase Audit System

This project provides a reusable, production-ready analytical system for auditing JavaScript/TypeScript, Java, and .NET codebases with maximum accuracy.

**Current Status**: All three stacks fully implemented and production-ready!

## System Overview

The audit system uses a **6-stage analytical funnel** with **independent sub-agents** to eliminate bias and maximize finding confidence:

1. **Stage 1: Artifact Generation** - Creates architecture diagrams and documentation
2. **Stage 2: Parallel Independent Analysis** - 4 specialist agents analyze in isolation
3. **Stage 3: Static Analysis** - Stack-specific tools provide objective metrics
4. **Stage 4: Reconciliation** - Synthesizes findings with convergence analysis
5. **Stage 5: Adversarial Challenge** - Independent agent challenges findings
6. **Stage 6: Final Synthesis** - Produces top 10 prioritized improvements

## Project Conventions

### Analysis Framework Principles

1. **Independence First**: Specialist agents must never see each other's outputs until reconciliation
2. **Evidence-Based Prioritization**: Findings ranked by severity × confidence × effort-to-value
3. **Transparency Through Stages**: Every stage produces reviewable artifacts in `.analysis/` directories
4. **Convergence = Confidence**: Findings that appear across multiple independent agents/tools are high-confidence

### Output Standards

All findings must include:
- **Location**: Exact file:line reference with clickable links
- **Evidence**: Which agents AND which static tools identified it
- **Confidence Level**: High (converged), Medium (single category), Low (single source)
- **Code Example**: Actual problematic code snippet
- **Recommendation**: Specific, actionable fix with example code
- **Effort Estimate**: High/Medium/Low time investment
- **Impact Estimate**: Critical/High/Medium/Low business impact

### Code Quality Standards

- Use functional programming patterns where possible
- All analysis logic must be deterministic and reproducible
- Static analysis tool integrations must handle tool failures gracefully
- Output JSON schemas must be validated before writing files

### File Structure Conventions

```
When auditing a target repository, outputs go to:

target-repo/
├── ANALYSIS-REPORT.md           # Executive summary (main deliverable)
├── ARCHITECTURE-OVERVIEW.md     # System architecture docs
├── FINDINGS-DETAILED.json       # Complete structured data
├── CONFIDENCE-MATRIX.md         # Evidence transparency matrix
└── .analysis/                   # All stage-by-stage outputs
    ├── stage1-artifacts/
    ├── stage2-parallel-analysis/
    ├── stage3-static-analysis/
    ├── stage4-reconciliation/
    ├── stage5-adversarial/
    └── stage6-final-synthesis/
```

## Agent-Specific Instructions

### Artifact Generator (Stage 1)
**Objective**: Build comprehensive mental model before analysis
**Output**: Architecture diagrams, data flows, sequence diagrams, ER models
**Must Include**: Component dependencies, critical paths, tech debt surface map
**Permission Mode**: Plan (read-only)

### Architecture Analyzer (Stage 2)
**Objective**: Identify structural, design, and architectural issues
**Focus**: Abstractions, coupling, design patterns, layer violations
**Isolation**: No access to other agent outputs
**Permission Mode**: Plan (read-only)

### Security Analyzer (Stage 2)
**Objective**: Identify vulnerabilities, attack surfaces, trust boundaries
**Focus**: OWASP Top 10, injection flaws, auth issues, data exposure
**Isolation**: No access to other agent outputs
**Permission Mode**: Plan (read-only)

### Maintainability Analyzer (Stage 2)
**Objective**: Identify code quality issues and technical debt
**Focus**: Complexity, duplication, test coverage, documentation
**Isolation**: No access to other agent outputs
**Permission Mode**: Plan (read-only)

### Dependency Analyzer (Stage 2)
**Objective**: Identify supply chain risks and dependency issues
**Focus**: Outdated packages, known vulnerabilities, license issues
**Isolation**: No access to other agent outputs
**Permission Mode**: Plan (read-only)

### Reconciliation Agent (Stage 4)
**Objective**: Synthesize findings with no prior analytical bias
**Input**: All Stage 2 outputs + Stage 3 static results + Stage 1 artifacts
**Output**: Confidence-weighted merged longlist with convergence analysis
**Fresh Context**: Must not have performed any prior analysis

### Adversarial Agent (Stage 5)
**Objective**: Challenge findings to eliminate false positives
**Input**: Only reconciled findings (no prior reasoning)
**Output**: Verdicts on each finding (upheld/downgraded/dismissed)
**Fresh Context**: Must not have performed any prior analysis

## Compact Instructions

When compacting this context, preserve:
- 6-stage funnel structure and sequencing
- Independence requirement for Stage 2 agents
- Output format requirements (file:line, evidence sources, confidence levels)
- Deliverables structure (4 top-level files + .analysis/ directory)
- Convergence = high confidence principle

## Tech Stack Support

### JavaScript/TypeScript ✅ (Fully Implemented)
- **Status**: Production-ready with complete 6-stage pipeline
- **Static Tools**: ESLint + security plugins, Semgrep, Snyk, SonarQube, npm audit, Trivy, Coverage
- **Frameworks**: React, Vue, Angular, Node.js, Express, Next.js
- **Focus Areas**: Async patterns, promise handling, dependency management
- **Command**: `/audit-javascript`

### Java ✅ (Fully Implemented)
- **Status**: Production-ready with complete 7-stage pipeline (Stage 0 = build validation)
- **Static Tools**: Semgrep, SpotBugs + Find Security Bugs, PMD, Checkstyle, Snyk, OWASP Dependency-Check, Trivy, SonarQube
- **Frameworks**: Spring, Spring Boot, Jakarta EE, Hibernate, Micronaut
- **Focus Areas**: Spring Security, SQL injection, XXE, deserialization, concurrency, JPA performance
- **Command**: `/audit-java`

### .NET (C#/F#) ✅ (Fully Implemented)
- **Status**: Production-ready with complete 7-stage pipeline (Stage 0 = build validation)
- **Static Tools**: Semgrep, Roslyn Analyzers, Security Code Scan, Snyk, dotnet-outdated, Trivy, SonarQube
- **Frameworks**: ASP.NET Core, Entity Framework, Blazor, SignalR
- **Focus Areas**: ASP.NET Core Identity, CSRF, XSS in Razor, EF Core SQL injection, async/await patterns
- **Command**: `/audit-dotnet`

## Severity Classification

- **Critical**: Security vulnerabilities, data loss risks, system-breaking bugs
- **High**: Performance issues, significant tech debt, scalability blockers
- **Medium**: Code quality issues, maintainability concerns, minor bugs
- **Low**: Style inconsistencies, documentation gaps, nice-to-haves

## Usage Examples

```bash
# Run full JavaScript/TypeScript audit (currently the only available option)
/audit-javascript

# The skill will automatically:
# 1. Generate architecture artifacts
# 2. Run 4 parallel independent agent analyses
# 3. Execute static analysis tools (ESLint, Semgrep, Snyk, npm audit, etc.)
# 4. Reconcile findings with convergence analysis
# 5. Run adversarial challenge to eliminate false positives
# 6. Generate top 10 prioritized improvements

# Output deliverables:
# - ANALYSIS-REPORT.md (executive summary with top 10)
# - ARCHITECTURE-OVERVIEW.md (system documentation)
# - FINDINGS-DETAILED.json (complete structured data)
# - CONFIDENCE-MATRIX.md (evidence transparency)
# - .analysis/ directory (all stage-by-stage outputs)
```

## Custom Memory Sections

### Learned Patterns
<!-- Claude auto-populates if memory enabled -->

### Common Frameworks Encountered
<!-- Claude tracks across sessions -->

### False Positive Patterns
<!-- Track what gets dismissed in Stage 5 to improve future runs -->
