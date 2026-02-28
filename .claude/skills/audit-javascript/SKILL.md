---
name: audit-javascript
description: "Performs comprehensive 6-stage audit of JavaScript/TypeScript codebases with maximum accuracy using independent agents and static analysis"
user-invocable: true
---

# JavaScript Codebase Audit - Executable Orchestration

You are orchestrating a complete 6-stage analytical funnel to produce the top 10 highest-priority improvements for this JavaScript/TypeScript codebase.

## Your Mission

Execute all 6 stages sequentially, using specialized agents at each stage. Track progress with TodoWrite and present evaluation checkpoints to the user after key stages.

**IMPORTANT**: You MUST actually execute this audit, not just describe what would happen. Use the Task tool to invoke agents, Bash tool to run commands, and Write tool to create outputs.

---

## Stage 1: Architecture Artifact Generation

**Objective**: Build comprehensive mental model before any analysis begins.

### Your Actions

1. Create the directory structure:
```bash
mkdir -p .analysis/stage1-artifacts
```

2. Initialize todo tracking with all 6 stages

3. Mark Stage 1 as in_progress

4. Invoke the `artifact-generator` agent using the Task tool with subagent_type="artifact-generator":

**Prompt for artifact-generator**:
```
You are generating architecture artifacts for this JavaScript/TypeScript codebase.

Your task:
1. Analyze the repository structure comprehensively
2. Generate ALL required artifacts in .analysis/stage1-artifacts/:
   - architecture-overview.md (system purpose, tech stack, architecture layers)
   - component-dependency.mermaid (module dependency graph)
   - data-flow-diagrams/ directory with flows for authentication, business operations
   - sequence-diagrams/ directory for critical paths
   - entity-relationship.mermaid (data model)
   - tech-debt-surface-map.md (high churn files, complexity hotspots, TODO debt)
   - metadata.json (statistics: file counts, LOC, languages, dependencies count)

Follow the complete process outlined in your agent definition (.claude/agents/artifact-generator.md).

Output all files to .analysis/stage1-artifacts/
```

5. After the agent completes, read `.analysis/stage1-artifacts/architecture-overview.md` and present a summary to the user

6. Ask the user: "Does this architecture overview correctly describe your system? (Y/n)"

7. Mark Stage 1 as completed

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
You are analyzing this JavaScript/TypeScript codebase for architectural issues.

Read Stage 1 artifacts from .analysis/stage1-artifacts/ for context.

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

Output your findings to: .analysis/stage2-parallel-analysis/architecture-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/architecture-analyzer.md).
```

**Agent 2: security-analyzer**
```
You are analyzing this JavaScript/TypeScript codebase for security vulnerabilities.

Read Stage 1 artifacts from .analysis/stage1-artifacts/ for context.

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

Output your findings to: .analysis/stage2-parallel-analysis/security-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/security-analyzer.md).
```

**Agent 3: maintainability-analyzer**
```
You are analyzing this JavaScript/TypeScript codebase for code quality and technical debt.

Read Stage 1 artifacts from .analysis/stage1-artifacts/ for context.

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

Output your findings to: .analysis/stage2-parallel-analysis/maintainability-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/maintainability-analyzer.md).
```

**Agent 4: dependency-analyzer**
```
You are analyzing this JavaScript/TypeScript codebase for dependency and supply chain issues.

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

**Objective**: Run JavaScript-specific static analysis tools for objective validation.

### Your Actions

1. Create directory:
```bash
mkdir -p .analysis/stage3-static-analysis/raw-outputs
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
npx eslint . --format json --output-file .analysis/stage3-static-analysis/raw-outputs/eslint-report.json 2>&1 || echo "ESLint failed or not configured"
```

**npm audit**:
```bash
npm audit --json > .analysis/stage3-static-analysis/raw-outputs/npm-audit.json 2>&1 || echo "{}" > .analysis/stage3-static-analysis/raw-outputs/npm-audit.json
```

**Semgrep** (if available):
```bash
if command -v semgrep >/dev/null 2>&1; then
  bash .claude/skills/audit-javascript/tools/semgrep-runner.sh . .analysis/stage3-static-analysis/raw-outputs/semgrep-report.json
fi
```

**Snyk** (if available and authenticated):
```bash
if command -v snyk >/dev/null 2>&1; then
  bash .claude/skills/audit-javascript/tools/snyk-runner.sh . .analysis/stage3-static-analysis/raw-outputs
fi
```

6. Unify results using format-static-results.js:
```bash
node .claude/skills/audit-javascript/tools/format-static-results.js .analysis/stage3-static-analysis
```

This creates:
- `.analysis/stage3-static-analysis/unified-results.json` (normalized format)
- `.analysis/stage3-static-analysis/tool-comparison.md` (which tools found what)
- `.analysis/stage3-static-analysis/overlap-analysis.json` (convergence across tools)

7. Read `tool-comparison.md` and present summary to user

8. Write `.analysis/stage3-static-analysis/metadata.json` with tool execution status

9. Mark Stage 3 as completed

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
You are synthesizing findings from multiple independent sources.

You have NEVER analyzed this codebase before. You are coming to this fresh with no prior analytical bias.

Your inputs:
- Stage 1 artifacts: .analysis/stage1-artifacts/ (architecture context)
- Stage 2 agent outputs: .analysis/stage2-parallel-analysis/*.json (4 independent analyses)
- Stage 3 static analysis: .analysis/stage3-static-analysis/unified-results.json (tool findings)

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
You are challenging reconciled findings to eliminate false positives.

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
   - `.analysis/stage6-final-synthesis/prioritization-matrix.json` (all findings with scores)
   - `.analysis/stage6-final-synthesis/top-10-detailed.json` (top 10 with full details)
   - `.analysis/stage6-final-synthesis/honorable-mentions.md` (findings 11-20)
   - `.analysis/stage6-final-synthesis/quick-wins.md` (low effort, high impact items)
   - `.analysis/stage6-final-synthesis/systemic-patterns.md` (recurring issue patterns)
   - `.analysis/stage6-final-synthesis/metadata.json` (statistics)

8. Generate the 4 executive deliverables at repository root:

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
2. See `FINDINGS-DETAILED.json` for complete structured data
3. See `CONFIDENCE-MATRIX.md` for evidence transparency matrix
4. See `.analysis/` directory for complete stage-by-stage outputs
5. Consider running `/audit-javascript` again after fixes to measure improvement

## Full Details

All stage-by-stage outputs available in `.analysis/`:
- Stage 1: Architecture artifacts
- Stage 2: 4 independent agent analyses
- Stage 3: Static analysis tool results
- Stage 4: Reconciliation and convergence analysis
- Stage 5: Adversarial challenge results
- Stage 6: Prioritization matrix and patterns
```

**ARCHITECTURE-OVERVIEW.md**: Copy from `.analysis/stage1-artifacts/architecture-overview.md`

**FINDINGS-DETAILED.json**: Export all upheld findings with complete structure

**CONFIDENCE-MATRIX.md**: Create evidence transparency table showing which agents/tools found each finding

9. Present final summary to user:
```
## Analysis Complete! 🎯

**Executive Deliverables** (at repository root):
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

**Next Step**: Review ANALYSIS-REPORT.md for your prioritized improvements.
```

10. Mark Stage 6 as completed

---

## Error Handling

**If Stage 1 fails**: STOP - Cannot continue without architecture artifacts

**If Stage 2 agent fails**: Log warning, continue with available agents (minimum 2 required)

**If Stage 3 tools unavailable**: Continue with agent-only analysis (note lower confidence in report)

**If Stage 4 reconciliation fails**: STOP - Cannot continue to adversarial challenge

**If Stage 5 adversarial fails**: Fallback to Stage 4 reconciled findings (note in report)

**If Stage 6 fails**: Debug and retry - all inputs should be ready

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

Begin execution now!
