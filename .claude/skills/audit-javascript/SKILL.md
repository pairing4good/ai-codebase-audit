---
name: audit-javascript
description: "Performs comprehensive 6-stage audit of JavaScript/TypeScript codebases with maximum accuracy using independent agents and static analysis"
user-invocable: true
---

# JavaScript Codebase Audit - Executable Orchestration

You are orchestrating a complete 7-stage analytical funnel to produce the top 10 highest-priority improvements for this JavaScript/TypeScript codebase.

## Your Mission

Execute all 7 stages sequentially (Stage 0 is build/dependency validation), using specialized agents at each stage. Track progress with TodoWrite and present evaluation checkpoints to the user after key stages.

**IMPORTANT**: You MUST actually execute this audit, not just describe what would happen. Use the Task tool to invoke agents, Bash tool to run commands, and Write tool to create outputs.

---

## Stage 0: Build and Dependency Validation (CRITICAL - MANDATORY)

**Objective**: Ensure Node.js is installed and dependencies are available before analysis. **DO NOT PROCEED** without successful dependency installation.

### Your Actions

1. Create todo tracking with all 7 stages (including Stage 0)

2. Mark Stage 0 as in_progress

3. **Check for Node.js** (MANDATORY - STOP IF MISSING):

```bash
if ! command -v node >/dev/null 2>&1; then
  echo "❌ ERROR: Node.js is not installed!"
  echo ""
  echo "Node.js is required to:"
  echo "  - Install and verify dependencies (npm/yarn/pnpm)"
  echo "  - Run build scripts and validate project setup"
  echo "  - Execute static analysis tools (ESLint, etc.)"
  echo "  - Ensure accurate analysis of JavaScript/TypeScript code"
  echo ""
  echo "Please install Node.js (recommend LTS version 18+ or 20+):"
  echo "  • macOS: brew install node"
  echo "  • Linux (Ubuntu): sudo apt install nodejs npm"
  echo "  • Linux (using nvm): curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash && nvm install --lts"
  echo "  • Windows: https://nodejs.org/en/download/"
  echo ""
  echo "After installation, verify with: node --version"
  echo ""
  echo "⛔ Audit cannot proceed without Node.js."
  exit 1
fi
```

4. Verify Node.js version:

```bash
echo "✅ Node.js detected: $(node --version)"
echo "✅ npm version: $(npm --version)"
```

5. Detect package manager and project files (STOP IF MISSING):

```bash
# Check for JavaScript/TypeScript project
if [ -f "package.json" ]; then
  echo "✅ JavaScript/TypeScript project detected: package.json found"
else
  echo "❌ ERROR: No package.json found!"
  echo "Is this a JavaScript/TypeScript project? Change to the project directory and try again."
  exit 1
fi

# Detect package manager
if [ -f "package-lock.json" ]; then
  echo "✅ Package manager: npm (package-lock.json detected)"
  PKG_MANAGER="npm"
elif [ -f "yarn.lock" ]; then
  if ! command -v yarn >/dev/null 2>&1; then
    echo "⚠️ WARNING: yarn.lock found but yarn not installed. Will use npm instead."
    PKG_MANAGER="npm"
  else
    echo "✅ Package manager: yarn (yarn.lock detected)"
    PKG_MANAGER="yarn"
  fi
elif [ -f "pnpm-lock.yaml" ]; then
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "⚠️ WARNING: pnpm-lock.yaml found but pnpm not installed. Will use npm instead."
    PKG_MANAGER="npm"
  else
    echo "✅ Package manager: pnpm (pnpm-lock.yaml detected)"
    PKG_MANAGER="pnpm"
  fi
else
  echo "✅ Package manager: npm (default - no lockfile detected)"
  PKG_MANAGER="npm"
fi
```

6. Install dependencies:

```bash
echo "Installing dependencies..."

if [ "$PKG_MANAGER" = "npm" ]; then
  npm install --legacy-peer-deps 2>&1 | tail -20
  INSTALL_STATUS=$?
elif [ "$PKG_MANAGER" = "yarn" ]; then
  yarn install 2>&1 | tail -20
  INSTALL_STATUS=$?
elif [ "$PKG_MANAGER" = "pnpm" ]; then
  pnpm install 2>&1 | tail -20
  INSTALL_STATUS=$?
fi
```

7. Check installation status:

```bash
if [ $INSTALL_STATUS -ne 0 ]; then
  echo ""
  echo "⚠️ WARNING: Dependency installation had errors!"
  echo ""
  echo "This may affect analysis accuracy. Common issues:"
  echo "  - Peer dependency conflicts"
  echo "  - Outdated lockfiles"
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

8. Attempt build validation (optional - continue if fails):

```bash
# Check if there's a build script
if grep -q '"build"' package.json; then
  echo "Build script detected. Attempting build validation..."

  if [ "$PKG_MANAGER" = "npm" ]; then
    timeout 120 npm run build 2>&1 | tail -20
    BUILD_STATUS=$?
  elif [ "$PKG_MANAGER" = "yarn" ]; then
    timeout 120 yarn build 2>&1 | tail -20
    BUILD_STATUS=$?
  elif [ "$PKG_MANAGER" = "pnpm" ]; then
    timeout 120 pnpm build 2>&1 | tail -20
    BUILD_STATUS=$?
  fi

  if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ Build successful!"
  else
    echo "⚠️ Build failed or timed out. Continuing with analysis (many projects don't require build for analysis)."
  fi
else
  echo "ℹ️ No build script found. Skipping build validation."
fi
```

9. Inform user:
```
✅ Stage 0 Complete: Dependencies validated
📦 Package manager: [npm/yarn/pnpm]
📂 node_modules installed
🔍 Ready for static analysis
```

10. Mark Stage 0 as completed

**CRITICAL**: If step 3 (Node.js check) or step 5 (package.json check) fail, **STOP IMMEDIATELY** and inform the user. Do NOT proceed to Stage 1.

For dependency installation failures (step 7), prompt user whether to continue with reduced coverage.

---

## Stage 1: Architecture Artifact Generation

**Objective**: Build comprehensive mental model before any analysis begins.

### Your Actions

1. Determine project root and create the directory structure:
```bash
# Find git repository root, or use current directory if not a git repo
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
else
  PROJECT_ROOT=$(pwd)
fi

mkdir -p "$PROJECT_ROOT/.analysis/javascript/stage1-artifacts"
```

2. Mark Stage 1 as in_progress (todos already initialized in Stage 0)

3. Invoke the `artifact-generator` agent using the Task tool with subagent_type="artifact-generator":

**Prompt for artifact-generator**:
```
You are generating architecture artifacts for this JavaScript/TypeScript codebase.

CRITICAL: Determine the project root directory first:
- If this is a git repository, use the git root: $(git rev-parse --show-toplevel)
- Otherwise, use the current working directory

Your task:
1. Analyze the repository structure comprehensively
2. Generate ALL required artifacts in $PROJECT_ROOT/.analysis/javascript/stage1-artifacts/:
   - architecture-overview.md (system purpose, tech stack, architecture layers)
   - component-dependency.mermaid (module dependency graph)
   - data-flow-diagrams/ directory with flows for authentication, business operations
   - sequence-diagrams/ directory for critical paths
   - entity-relationship.mermaid (data model)
   - tech-debt-surface-map.md (high churn files, complexity hotspots, TODO debt)
   - metadata.json (statistics: file counts, LOC, languages, dependencies count)

Follow the complete process outlined in your agent definition (.claude/agents/artifact-generator.md).

IMPORTANT: All outputs must be written to the PROJECT ROOT .analysis/javascript/ directory, not a subdirectory.
Output all files to $PROJECT_ROOT/.analysis/javascript/stage1-artifacts/
```

4. After the agent completes, read `$PROJECT_ROOT/.analysis/javascript/stage1-artifacts/architecture-overview.md` and present a summary to the user

5. Mark Stage 1 as completed

---

## Stage 2: Parallel Independent Analysis

**Objective**: Four specialist agents analyze in complete isolation (no cross-contamination).

### Your Actions

1. Create directory:
```bash
mkdir -p "$PROJECT_ROOT/.analysis/javascript/stage2-parallel-analysis"
```

2. Mark Stage 2 as in_progress

3. **Launch all 4 agents IN PARALLEL** using a single message with 4 Task tool calls:

**CRITICAL**: You MUST send all 4 Task invocations in a SINGLE message to run them in parallel. Do NOT run them sequentially.

**Agent 1: architecture-analyzer**
```
You are analyzing this JavaScript/TypeScript codebase for architectural issues.

CRITICAL: Use PROJECT_ROOT for all paths. Determine it with:
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

Read Stage 1 artifacts from $PROJECT_ROOT/.analysis/javascript/stage1-artifacts/ for context.

Analyze for:
- System design patterns
- Abstraction and coupling issues
- Design pattern usage
- Separation of concerns
- Modularity and boundaries
- Data flow architecture
- Error handling architecture
- Scalability patterns
- Consistency issues
- Integration patterns

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/javascript/stage2-parallel-analysis/architecture-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/architecture-analyzer.md).
```

**Agent 2: security-analyzer**
```
You are analyzing this JavaScript/TypeScript codebase for security vulnerabilities.

CRITICAL: Use PROJECT_ROOT for all paths. Determine it with:
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

Read Stage 1 artifacts from $PROJECT_ROOT/.analysis/javascript/stage1-artifacts/ for context.

Analyze for:
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication and authorization flaws
- Sensitive data exposure
- XML external entities (XXE)
- Broken access control
- Security misconfiguration
- Cross-site request forgery (CSRF)
- Insecure deserialization
- Using components with known vulnerabilities
- Insufficient logging and monitoring

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/javascript/stage2-parallel-analysis/security-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/security-analyzer.md).
```

**Agent 3: maintainability-analyzer**
```
You are analyzing this JavaScript/TypeScript codebase for code quality and technical debt.

CRITICAL: Use PROJECT_ROOT for all paths. Determine it with:
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

Read Stage 1 artifacts from $PROJECT_ROOT/.analysis/javascript/stage1-artifacts/ for context.

Analyze for:
- Code complexity (cyclomatic, cognitive)
- Code duplication
- Test coverage and quality
- Documentation gaps
- Naming conventions
- Function and class size
- Dead code
- Magic numbers and strings
- Error handling completeness
- Code smells

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/javascript/stage2-parallel-analysis/maintainability-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/maintainability-analyzer.md).
```

**Agent 4: dependency-analyzer**
```
You are analyzing this JavaScript/TypeScript codebase for dependency and supply chain issues.

CRITICAL: Use PROJECT_ROOT for all paths. Determine it with:
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

Read package.json and package-lock.json.

Analyze for:
- Outdated dependencies
- Known vulnerabilities in dependencies
- License compliance issues
- Dependency version conflicts
- Unused dependencies
- Circular dependencies
- Transitive dependency risks
- Missing peer dependencies
- Dependency freshness
- Supply chain security

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/javascript/stage2-parallel-analysis/dependency-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/dependency-analyzer.md).
```

4. After ALL agents complete, read all 4 JSON outputs

5. Generate a convergence preview by identifying findings that appear in multiple agent outputs:
   - Group findings by file:line location
   - Count how many agents flagged each location
   - Write `$PROJECT_ROOT/.analysis/javascript/stage2-parallel-analysis/convergence-preview.md` showing multi-agent findings
   - Write `$PROJECT_ROOT/.analysis/javascript/stage2-parallel-analysis/metadata.json` with counts

6. Present convergence preview to user showing high-confidence findings

7. Mark Stage 2 as completed

---

## Stage 3: Static Analysis Tools

**Objective**: Run JavaScript-specific static analysis tools for objective validation.

### Your Actions

1. Create directory:
```bash
mkdir -p "$PROJECT_ROOT/$PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/raw-outputs"
```

2. Mark Stage 3 as in_progress

3. **Auto-install missing tools** (attempts automatic installation where possible):
```bash
echo "Checking and installing static analysis tools..."
bash .claude/skills/audit-javascript/tools/auto-install-tools.sh
```

4. Detect available tools:
   - Check for ESLint configuration (.eslintrc.*, package.json scripts)
   - Check for npm (always available)
   - Check for test coverage configuration
   - Check if Semgrep is installed
   - Check if Snyk is available

5. Run available tools:

**ESLint** (if configured):
```bash
npx eslint . --format json --output-file $PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/raw-outputs/eslint-report.json 2>&1 || echo "ESLint failed or not configured"
```

**npm audit**:
```bash
npm audit --json > $PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/raw-outputs/npm-audit.json 2>&1 || echo "{}" > $PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/raw-outputs/npm-audit.json
```

**Semgrep** (if available):
```bash
if command -v semgrep >/dev/null 2>&1; then
  bash .claude/skills/audit-javascript/tools/semgrep-runner.sh . $PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/raw-outputs/semgrep-report.json
fi
```

**Snyk** (if available and authenticated):
```bash
if command -v snyk >/dev/null 2>&1; then
  bash .claude/skills/audit-javascript/tools/snyk-runner.sh . $PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/raw-outputs
fi
```

6. Unify results using format-static-results.js:
```bash
node .claude/skills/audit-javascript/tools/format-static-results.js $PROJECT_ROOT/.analysis/javascript/stage3-static-analysis
```

This creates:
- `$PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/unified-results.json` (normalized format)
- `$PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/tool-comparison.md` (which tools found what)
- `$PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/overlap-analysis.json` (convergence across tools)

7. Read `tool-comparison.md` and present summary to user

8. Write `$PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/metadata.json` with tool execution status

9. Mark Stage 3 as completed

---

## Stage 4: Reconciliation

**Objective**: Synthesize findings from all sources with statistical confidence scoring.

### Your Actions

1. Create directory:
```bash
mkdir -p $PROJECT_ROOT/.analysis/javascript/stage4-reconciliation
```

2. Mark Stage 4 as in_progress

3. Invoke the `reconciliation-agent` using Task tool with subagent_type="reconciliation-agent":

**Prompt for reconciliation-agent**:
```
You are synthesizing findings from multiple independent sources.

You have NEVER analyzed this codebase before. You are coming to this fresh with no prior analytical bias.

Your inputs:
- Stage 1 artifacts: .analysis/javascript/stage1-artifacts/ (architecture context)
- Stage 2 agent outputs: .analysis/javascript/stage2-parallel-analysis/*.json (4 independent analyses)
- Stage 3 static analysis: $PROJECT_ROOT/.analysis/javascript/stage3-static-analysis/unified-results.json (tool findings)

Your task:
1. Read ALL inputs
2. Index findings by location (file:line)
3. Perform convergence analysis (which findings appear across multiple sources?)
4. Calculate confidence scores using the formula in your agent definition
5. Identify contradictions (agent vs tool disagreements)
6. Generate merged longlist with evidence tracking

Output to $PROJECT_ROOT/.analysis/javascript/stage4-reconciliation/:
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
mkdir -p $PROJECT_ROOT/.analysis/javascript/stage5-adversarial
```

2. Mark Stage 5 as in_progress

3. Invoke the `adversarial-agent` using Task tool with subagent_type="adversarial-agent":

**Prompt for adversarial-agent**:
```
You are challenging reconciled findings to eliminate false positives.

You have NEVER been involved in this audit before. You are the independent skeptic.

Your input:
- Reconciled findings: $PROJECT_ROOT/.analysis/javascript/stage4-reconciliation/reconciled-longlist.json

Your task:
Attack each finding using the 5-point challenge framework:
1. Is this actually a problem? (false positive detection)
2. Is severity overstated? (inflation detection)
3. Is evidence valid? (verification)
4. Is this intentional design? (context understanding)
5. Does this matter in context? (priority assessment)

For each finding, issue one of three verdicts:
- UPHELD: Finding is valid as stated
- DOWNGRADED: Valid but severity overstated (adjust severity)
- DISMISSED: False positive (remove from consideration)

Expected metrics:
- Upheld: 70-85%
- Downgraded: 10-20%
- Dismissed: 5-15%

Output to $PROJECT_ROOT/.analysis/javascript/stage5-adversarial/:
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
mkdir -p $PROJECT_ROOT/.analysis/javascript/stage6-final-synthesis
```

2. Mark Stage 6 as in_progress

3. Read `$PROJECT_ROOT/.analysis/javascript/stage5-adversarial/challenged-findings.json`

4. Filter to UPHELD findings only (exclude DISMISSED)

5. Apply prioritization formula to rank findings:

**Prioritization Formula**:
```
priority_score = (severity_weight × severity_score) +
                 (confidence_weight × confidence_score) +
                 (effort_to_value_weight × effort_value_score)

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
```

6. Sort by priority_score descending and select top 10

7. Write Stage 6 outputs:
   - `$PROJECT_ROOT/.analysis/javascript/stage6-final-synthesis/prioritization-matrix.json` (all findings with scores)
   - `$PROJECT_ROOT/.analysis/javascript/stage6-final-synthesis/top-10-detailed.json` (top 10 with full details)
   - `$PROJECT_ROOT/.analysis/javascript/stage6-final-synthesis/honorable-mentions.md` (findings 11-20)
   - `$PROJECT_ROOT/.analysis/javascript/stage6-final-synthesis/quick-wins.md` (low effort, high impact items)
   - `$PROJECT_ROOT/.analysis/javascript/stage6-final-synthesis/systemic-patterns.md` (recurring issue patterns)
   - `$PROJECT_ROOT/.analysis/javascript/stage6-final-synthesis/metadata.json` (statistics)

8. Create the final report directory and generate the 4 executive deliverables:

```bash
mkdir -p $PROJECT_ROOT/.analysis/javascript/final-report
```

**ANALYSIS-REPORT.md**:
```markdown
# Codebase Analysis Report

*Generated: [DATE] | Overall Confidence: [High/Medium] | [X] findings analyzed → Top 10 selected*

## Executive Summary

[1-2 paragraph overview: what was analyzed, methodology (6-stage funnel), key findings summary, overall codebase health assessment]

## Methodology

This audit used a 6-stage analytical funnel with independent agents and static analysis:

1. **Artifact Generation**: Architecture mapping and tech debt surface analysis
2. **Parallel Independent Analysis**: 4 specialist agents (architecture, security, maintainability, dependency) operating in isolation
3. **Static Analysis**: JavaScript-specific tools (ESLint, npm audit, Semgrep, Snyk)
4. **Reconciliation**: Statistical convergence analysis across all sources
5. **Adversarial Challenge**: Independent skeptic eliminated false positives
6. **Final Synthesis**: Evidence-based prioritization

**Confidence Principle**: Findings that converged across multiple independent agents AND static tools receive "High" confidence.

## Top 10 Improvements

[For each finding 1-10:]

### [#]. [Critical/High/Medium] [Title]

**Location**: [file:line] (clickable links)
**Confidence**: [High/Medium/Low] (converged: [list agent names] + [list tool names])
**Priority Score**: [X.XX]
**Effort**: [Low/Medium/High]
**Impact**: [Critical/High/Medium/Low]

**Problem**:
[Clear description of what's wrong]

**Evidence**:
- Identified by agents: [list]
- Identified by tools: [list]
- Convergence score: [0.0-1.0]

**Code Example**:
```javascript
// file:line
[Actual problematic code snippet]
```

**Impact**:
[Business/technical impact - why this matters]

**Recommendation**:
[Specific, actionable fix with example code showing the solution]

**Survived Adversarial Challenge**: Yes - [brief reasoning from adversarial agent]

---

[Repeat for all 10 findings]

## Summary Statistics

- **Total Findings Analyzed**: [X]
- **High Confidence**: [X] findings (converged across agents + tools)
- **Medium Confidence**: [X] findings
- **Low Confidence**: [X] findings
- **False Positives Dismissed**: [X] findings
- **Severity Adjustments**: [X] findings downgraded

## What Makes These Recommendations Trustworthy

1. **Independent Analysis**: 4 specialist agents analyzed separately (no confirmation bias)
2. **Tool Validation**: Static analysis tools provided objective verification
3. **Convergence Scoring**: Findings appearing across multiple sources scored higher
4. **Adversarial Challenge**: Independent skeptic eliminated [X] false positives
5. **Evidence Transparency**: Every finding shows which agents/tools identified it

## Next Steps

1. Review this report and prioritize which findings to address first
2. See `$PROJECT_ROOT/.analysis/javascript/final-report/FINDINGS-DETAILED.json` for complete structured data
3. See `$PROJECT_ROOT/.analysis/javascript/final-report/CONFIDENCE-MATRIX.md` for evidence transparency matrix
4. See `.analysis/javascript/` directory for complete stage-by-stage outputs
5. Consider running `/audit-javascript` again after fixes to measure improvement

## Full Details

All stage-by-stage outputs available in `.analysis/javascript/`:
- Stage 1: Architecture artifacts
- Stage 2: 4 independent agent analyses
- Stage 3: Static analysis tool results
- Stage 4: Reconciliation and convergence analysis
- Stage 5: Adversarial challenge results
- Stage 6: Prioritization matrix and patterns
```

9. **Create ARCHITECTURE-OVERVIEW.md**:
```bash
cp .analysis/javascript/stage1-artifacts/architecture-overview.md $PROJECT_ROOT/.analysis/javascript/final-report/ARCHITECTURE-OVERVIEW.md
```

10. **Create FINDINGS-DETAILED.json**: Export all upheld findings with complete structure (must include `example` field with `file`, `line_start`, `line_end`, and `code` for each finding)

11. **Create CONFIDENCE-MATRIX.md**: Generate evidence transparency table showing which agents/tools found each finding

Example format:
```markdown
# Confidence Matrix

| Finding | Location | security-analyzer | architecture-analyzer | maintainability-analyzer | dependency-analyzer | ESLint | Semgrep | Snyk | npm audit | Confidence |
|---------|----------|-------------------|----------------------|-------------------------|---------------------|--------|---------|------|-----------|------------|
| XSS Vulnerability | app.js:42 | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | High (3 sources) |
...
```

12. Present final summary to user:
```
## Analysis Complete! 🎯

**Executive Deliverables** (in $PROJECT_ROOT/.analysis/javascript/final-report/):
- ANALYSIS-REPORT.md - Top 10 with detailed recommendations
- ARCHITECTURE-OVERVIEW.md - System architecture documentation
- FINDINGS-DETAILED.json - Complete structured data
- CONFIDENCE-MATRIX.md - Evidence transparency matrix

**Summary**:
- [X] total findings analyzed
- Top 10 selected via evidence-based prioritization
- [X] critical, [X] high, [X] medium severity in top 10
- Average confidence: [High/Medium] ([X]% convergence rate)
- [X] false positives eliminated

**Next Step**: Review `$PROJECT_ROOT/.analysis/javascript/final-report/ANALYSIS-REPORT.md` for your prioritized improvements.
```

13. Mark Stage 6 as completed

---

## Error Handling

**If Stage 0 fails** (any of these):
- ❌ Node.js not installed → **STOP** - Provide installation instructions, do NOT proceed
- ❌ No package.json found → **STOP** - Verify this is a JavaScript/TypeScript project
- ❌ Dependency installation fails → **PROMPT USER** - Ask whether to continue with reduced coverage or stop

**DO NOT**:
- Proceed without Node.js installed
- Skip dependency installation entirely
- Ignore missing package.json

**ALWAYS**:
- Stop immediately when Node.js is missing
- Provide clear installation instructions
- Give user choice on dependency failures (continue with warnings vs. stop)

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
7. **Include clickable file:line references** in all outputs
8. **Be thorough** - This is a comprehensive audit, not a quick scan

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
