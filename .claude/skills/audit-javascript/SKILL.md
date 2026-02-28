---
name: audit-javascript
description: "Performs comprehensive 6-stage audit of JavaScript/TypeScript codebases with maximum accuracy using independent agents and static analysis"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Task, Write
context: main
---

# JavaScript Codebase Audit Skill

This skill orchestrates a complete 6-stage analytical funnel to produce the top 10 highest-priority improvements for a JavaScript/TypeScript codebase.

## Usage

```bash
/audit-javascript [options]
```

### Options

- `--stages=1,2,3` - Run only specific stages (default: all)
- `--output=<dir>` - Output directory (default: current directory)
- `--severity=critical,high` - Filter by severity (default: all)
- `--skip-static` - Skip static analysis tools (Stage 3)

### Examples

```bash
# Full audit
/audit-javascript

# Run only stages 1-3 (stop before reconciliation)
/audit-javascript --stages=1,2,3

# Focus on critical issues only
/audit-javascript --severity=critical
```

## Prerequisites

Before running this audit, ensure the target repository has:
- `package.json` (JavaScript/TypeScript project indicator)
- Node.js and npm installed
- (Optional) ESLint, SonarQube Scanner, and coverage tools installed

## Audit Process

### Stage 1: Artifact Generation

**Objective**: Build comprehensive mental model before analysis

**Agent**: `artifact-generator`

**Actions**:
1. Create `.analysis/stage1-artifacts/` directory
2. Invoke artifact-generator agent with instructions to:
   - Analyze repository structure
   - Generate architecture overview (Markdown)
   - Create component dependency diagram (Mermaid)
   - Map data flows (Mermaid)
   - Create sequence diagrams for critical paths (Mermaid)
   - Document entity relationships (Mermaid)
   - Create tech debt surface map (Markdown)
3. Verify all artifacts generated successfully

**Outputs**:
- `.analysis/stage1-artifacts/architecture-overview.md`
- `.analysis/stage1-artifacts/component-dependency.mermaid`
- `.analysis/stage1-artifacts/data-flow-diagrams/*.mermaid`
- `.analysis/stage1-artifacts/sequence-diagrams/*.mermaid`
- `.analysis/stage1-artifacts/entity-relationship.mermaid`
- `.analysis/stage1-artifacts/tech-debt-surface-map.md`
- `.analysis/stage1-artifacts/metadata.json`

**Evaluation Checkpoint**:
After Stage 1 completes, verify that the architecture overview correctly describes the system. If not, Stage 1 artifacts will mislead all subsequent stages.

---

### Stage 2: Parallel Independent Analysis

**Objective**: Four specialist agents analyze in complete isolation

**Agents**:
- `architecture-analyzer`
- `security-analyzer`
- `maintainability-analyzer`
- `dependency-analyzer`

**Actions**:
1. Create `.analysis/stage2-parallel-analysis/` directory
2. **Launch all 4 agents in parallel** using Task tool:
   - Each agent receives only Stage 1 artifacts
   - No agent sees other agents' outputs
   - Each generates independent findings JSON
3. Wait for all agents to complete
4. Generate convergence preview (quick summary of what multiple agents flagged)

**Outputs**:
- `.analysis/stage2-parallel-analysis/architecture-analysis.json`
- `.analysis/stage2-parallel-analysis/security-analysis.json`
- `.analysis/stage2-parallel-analysis/maintainability-analysis.json`
- `.analysis/stage2-parallel-analysis/dependency-analysis.json`
- `.analysis/stage2-parallel-analysis/convergence-preview.md`
- `.analysis/stage2-parallel-analysis/metadata.json`

**Evaluation Checkpoint**:
Review `convergence-preview.md` to see what multiple agents independently identified. High-convergence findings are your highest-signal candidates.

---

### Stage 3: Static Analysis

**Objective**: Run JavaScript-specific static analysis tools

**Tools**:
- **ESLint** + eslint-plugin-security + eslint-plugin-sonarjs
- **SonarQube Scanner** (if available)
- **npm audit** for dependency vulnerabilities
- **Istanbul/nyc** for test coverage (if configured)

**Actions**:
1. Create `.analysis/stage3-static-analysis/` directory
2. Create `.analysis/stage3-static-analysis/raw-outputs/` directory
3. Detect which tools are available
4. Run available tools:
   ```bash
   # ESLint (if .eslintrc or eslint config exists)
   npx eslint . --format json --output-file .analysis/stage3-static-analysis/raw-outputs/eslint-report.json

   # npm audit
   npm audit --json > .analysis/stage3-static-analysis/raw-outputs/npm-audit.json

   # Coverage (if nyc or jest configured)
   npm test -- --coverage --coverageReporters=json
   cp coverage/coverage-final.json .analysis/stage3-static-analysis/raw-outputs/coverage.json

   # SonarQube (if sonar-scanner available)
   sonar-scanner -Dsonar.projectBaseDir=. -Dsonar.json.reportPaths=.analysis/stage3-static-analysis/raw-outputs/sonar-report.json
   ```
5. Run `format-static-results.js` to unify all tool outputs
6. Generate tool comparison summary

**Outputs**:
- `.analysis/stage3-static-analysis/unified-results.json` (standardized format)
- `.analysis/stage3-static-analysis/raw-outputs/eslint-report.json`
- `.analysis/stage3-static-analysis/raw-outputs/npm-audit.json`
- `.analysis/stage3-static-analysis/raw-outputs/coverage.json`
- `.analysis/stage3-static-analysis/tool-comparison.md`
- `.analysis/stage3-static-analysis/coverage-gaps.md`
- `.analysis/stage3-static-analysis/metadata.json`

**Evaluation Checkpoint**:
Check `tool-comparison.md` to see which tools ran successfully. If key tools failed, investigate before continuing.

---

### Stage 4: Reconciliation

**Objective**: Synthesize findings from agents and static tools

**Agent**: `reconciliation-agent`

**Actions**:
1. Create `.analysis/stage4-reconciliation/` directory
2. Invoke reconciliation-agent with inputs:
   - All Stage 1 artifacts
   - All Stage 2 agent outputs
   - Stage 3 unified results
3. Agent performs convergence analysis and generates merged longlist

**Outputs**:
- `.analysis/stage4-reconciliation/reconciled-longlist.json`
- `.analysis/stage4-reconciliation/convergence-analysis.md`
- `.analysis/stage4-reconciliation/agent-only-findings.md`
- `.analysis/stage4-reconciliation/tool-only-findings.md`
- `.analysis/stage4-reconciliation/contradictions.md`
- `.analysis/stage4-reconciliation/metadata.json`

**Evaluation Checkpoint**:
Review `contradictions.md` to see where agents disagreed with static tools. These may require human judgment.

---

### Stage 5: Adversarial Challenge

**Objective**: Independent agent challenges findings to eliminate false positives

**Agent**: `adversarial-agent`

**Actions**:
1. Create `.analysis/stage5-adversarial/` directory
2. Invoke adversarial-agent with ONLY reconciled findings (no prior analysis)
3. Agent verifies each finding, checks for false positives, challenges severity

**Outputs**:
- `.analysis/stage5-adversarial/challenged-findings.json`
- `.analysis/stage5-adversarial/false-positives-identified.md`
- `.analysis/stage5-adversarial/severity-adjustments.md`
- `.analysis/stage5-adversarial/missing-context.md`
- `.analysis/stage5-adversarial/metadata.json`

**Evaluation Checkpoint**:
Review `false-positives-identified.md` to see what was dismissed. This builds confidence in final recommendations.

---

### Stage 6: Final Synthesis

**Objective**: Generate top 10 prioritized findings

**Actions**:
1. Create `.analysis/stage6-final-synthesis/` directory
2. Read challenged findings from Stage 5
3. Apply prioritization formula:
   ```
   priority_score = (severity_weight * severity_score) +
                    (confidence_weight * confidence_score) +
                    (effort_to_value_weight * effort_value_score)

   Default weights:
   - severity_weight: 0.4
   - confidence_weight: 0.3
   - effort_to_value_weight: 0.3
   ```
4. Rank all upheld findings
5. Select top 10
6. Generate executive reports

**Outputs**:
- `.analysis/stage6-final-synthesis/prioritization-matrix.json`
- `.analysis/stage6-final-synthesis/top-10-detailed.json`
- `.analysis/stage6-final-synthesis/honorable-mentions.md`
- `.analysis/stage6-final-synthesis/quick-wins.md`
- `.analysis/stage6-final-synthesis/systemic-patterns.md`
- `.analysis/stage6-final-synthesis/metadata.json`

**Final Deliverables** (written to repository root):
- `ANALYSIS-REPORT.md` - Executive summary with top 10
- `ARCHITECTURE-OVERVIEW.md` - System architecture documentation
- `FINDINGS-DETAILED.json` - Complete structured data
- `CONFIDENCE-MATRIX.md` - Evidence transparency

---

## Implementation

!`mkdir -p .analysis/stage{1..6}-{artifacts,parallel-analysis,static-analysis,reconciliation,adversarial,final-synthesis} 2>/dev/null || true`

### Dynamic Variables

- `$ARGUMENTS[0]` - Options string (e.g., "--stages=1,2,3")
- `${CLAUDE_PROJECT_DIR}` - Project root directory
- `!`pwd`` - Current directory (where audit runs)

### Execution Flow

```javascript
// Pseudo-code for orchestration

const options = parseArguments($ARGUMENTS);
const stages = options.stages || [1,2,3,4,5,6];

if (stages.includes(1)) {
  await runStage1ArtifactGeneration();
  showEvaluationCheckpoint("Stage 1");
}

if (stages.includes(2)) {
  await runStage2ParallelAnalysis();
  showEvaluationCheckpoint("Stage 2");
}

if (stages.includes(3) && !options.skipStatic) {
  await runStage3StaticAnalysis();
  showEvaluationCheckpoint("Stage 3");
}

if (stages.includes(4)) {
  await runStage4Reconciliation();
  showEvaluationCheckpoint("Stage 4");
}

if (stages.includes(5)) {
  await runStage5AdversarialChallenge();
  showEvaluationCheckpoint("Stage 5");
}

if (stages.includes(6)) {
  await runStage6FinalSynthesis();
  generateFinalDeliverables();
}
```

---

## Prompts for Each Stage

### Stage 1 Prompt

You are running Stage 1 of the codebase audit: Artifact Generation.

**Your task**:
1. Navigate to `.analysis/stage1-artifacts/`
2. Invoke the `artifact-generator` agent
3. Wait for completion
4. Verify all required artifacts were created
5. Display summary of what was generated

Use the Task tool to launch the artifact-generator agent with this prompt:

```
You are the artifact-generator agent. Generate comprehensive architecture artifacts for this JavaScript/TypeScript codebase.

Output all files to `.analysis/stage1-artifacts/`:
- architecture-overview.md
- component-dependency.mermaid
- data-flow-diagrams/*.mermaid
- sequence-diagrams/*.mermaid
- entity-relationship.mermaid
- tech-debt-surface-map.md
- metadata.json

Follow the complete process outlined in your agent definition.
```

After completion, read the architecture overview and present it to the user for validation.

---

### Stage 2 Prompt

You are running Stage 2 of the codebase audit: Parallel Independent Analysis.

**Your task**:
1. Launch 4 specialist agents **in parallel** (in a SINGLE message with multiple Task calls)
2. Each agent operates in complete isolation
3. Wait for all to complete
4. Generate convergence preview

Use the Task tool to launch all 4 agents simultaneously:

**Architecture Analyzer**:
```
You are the architecture-analyzer agent. Analyze this JavaScript/TypeScript codebase for architectural issues.

Read Stage 1 artifacts from `.analysis/stage1-artifacts/`.
Output your findings to `.analysis/stage2-parallel-analysis/architecture-analysis.json`.

You have NO ACCESS to other agents' outputs. Operate independently.
```

**Security Analyzer**:
```
You are the security-analyzer agent. Analyze this JavaScript/TypeScript codebase for security vulnerabilities.

Read Stage 1 artifacts from `.analysis/stage1-artifacts/`.
Output your findings to `.analysis/stage2-parallel-analysis/security-analysis.json`.

You have NO ACCESS to other agents' outputs. Operate independently.
```

**Maintainability Analyzer**:
```
You are the maintainability-analyzer agent. Analyze this JavaScript/TypeScript codebase for code quality and technical debt.

Read Stage 1 artifacts from `.analysis/stage1-artifacts/`.
Output your findings to `.analysis/stage2-parallel-analysis/maintainability-analysis.json`.

You have NO ACCESS to other agents' outputs. Operate independently.
```

**Dependency Analyzer**:
```
You are the dependency-analyzer agent. Analyze this JavaScript/TypeScript codebase for dependency issues.

Read package.json and package-lock.json.
Output your findings to `.analysis/stage2-parallel-analysis/dependency-analysis.json`.

You have NO ACCESS to other agents' outputs. Operate independently.
```

After all agents complete, create convergence-preview.md showing which findings appeared across multiple agents.

---

### Stage 3 Prompt

You are running Stage 3 of the codebase audit: Static Analysis.

**Your task**:
1. Detect available static analysis tools
2. Run each tool and capture output
3. Use format-static-results.js to unify outputs
4. Generate tool comparison

**Detection**:
- Check for `.eslintrc*` or `eslint` in package.json scripts
- Check for `sonar-project.properties` or SonarQube config
- npm audit is always available
- Check for test coverage configuration

**Execution**:
```bash
# Create directories
mkdir -p .analysis/stage3-static-analysis/raw-outputs

# ESLint (if available)
if [ -f .eslintrc.js ] || [ -f .eslintrc.json ] || grep -q "eslint" package.json; then
  npx eslint . --format json --output-file .analysis/stage3-static-analysis/raw-outputs/eslint-report.json 2>&1 || true
fi

# npm audit
npm audit --json > .analysis/stage3-static-analysis/raw-outputs/npm-audit.json 2>&1 || true

# Unify results
node ${CLAUDE_PROJECT_DIR}/.claude/skills/audit-javascript/tools/format-static-results.js \
  .analysis/stage3-static-analysis \
  --eslint=.analysis/stage3-static-analysis/raw-outputs/eslint-report.json \
  --npm-audit=.analysis/stage3-static-analysis/raw-outputs/npm-audit.json
```

After completion, read unified-results.json and present summary to user.

---

### Stage 4 Prompt

You are running Stage 4 of the codebase audit: Reconciliation.

**Your task**:
Invoke the reconciliation-agent to synthesize findings from Stages 2 and 3.

```
You are the reconciliation-agent. Synthesize findings from multiple sources.

**Inputs**:
- Stage 1 artifacts: `.analysis/stage1-artifacts/`
- Stage 2 agent outputs: `.analysis/stage2-parallel-analysis/*.json`
- Stage 3 static analysis: `.analysis/stage3-static-analysis/unified-results.json`

**Outputs** (write to `.analysis/stage4-reconciliation/`):
- reconciled-longlist.json
- convergence-analysis.md
- agent-only-findings.md
- tool-only-findings.md
- contradictions.md
- metadata.json

Identify convergent findings (high confidence) and contradictions (needs review).
```

After completion, read convergence-analysis.md and show user the high-confidence findings.

---

### Stage 5 Prompt

You are running Stage 5 of the codebase audit: Adversarial Challenge.

**Your task**:
Invoke the adversarial-agent to challenge findings and eliminate false positives.

```
You are the adversarial-agent. Challenge reconciled findings to eliminate false positives.

**Input**:
- Reconciled findings: `.analysis/stage4-reconciliation/reconciled-longlist.json`

**Outputs** (write to `.analysis/stage5-adversarial/`):
- challenged-findings.json
- false-positives-identified.md
- severity-adjustments.md
- missing-context.md
- metadata.json

Your job is to be SKEPTICAL. Make findings prove they deserve to be in the top 10.
```

After completion, read false-positives-identified.md and show user what was dismissed.

---

### Stage 6 Prompt

You are running Stage 6 of the codebase audit: Final Synthesis.

**Your task**:
Generate the final top 10 prioritized findings and create executive deliverables.

1. Read challenged-findings.json from Stage 5
2. Filter to upheld findings only (dismiss false positives)
3. Apply prioritization formula:
   - Severity: critical=4, high=3, medium=2, low=1
   - Confidence: high=3, medium=2, low=1
   - Effort-to-value: Estimate based on effort (low effort=high score)
4. Rank and select top 10
5. Generate final deliverables

**Create these files at repository root**:

**ANALYSIS-REPORT.md**:
```markdown
# Codebase Analysis Report
*Generated: [DATE] | Confidence: [OVERALL] | [X] findings analyzed*

## Executive Summary
[1-paragraph overview]

## Top 10 Improvements

### 1. [Critical] [Title]
**Location**: [file:line]
**Confidence**: High (converged: [agents] + [tools])
**Impact**: [Description]
**Effort**: [Low/Medium/High]
**Evidence**: [List sources]

**Example**:
```javascript
[Code snippet]
```

**Recommendation**:
[Specific fix with example]

**Survived Adversarial Challenge**: Yes - [reasoning]

---

[Repeat for findings #2-10]

## Analysis Methodology
[Describe 6-stage process]

## Full Details
See `.analysis/` directory for complete stage-by-stage outputs.
```

**ARCHITECTURE-OVERVIEW.md**: Copy from Stage 1 artifacts

**FINDINGS-DETAILED.json**: Complete structured export

**CONFIDENCE-MATRIX.md**: Evidence transparency table

Show user final summary and location of deliverables.

---

## Error Handling

- If Stage 1 fails: Cannot continue (artifacts required for all other stages)
- If Stage 2 agent fails: Log warning, continue with available agents
- If Stage 3 tools unavailable: Skip static analysis, proceed with agent-only findings
- If Stage 4 reconciliation fails: Cannot continue to Stage 5
- If Stage 5 adversarial fails: Use Stage 4 reconciled findings as fallback

## Success Criteria

The audit is successful when:
- [ ] All 6 stages completed without fatal errors
- [ ] 4 top-level deliverables created at repository root
- [ ] `.analysis/` directory contains all stage outputs
- [ ] Top 10 findings have high confidence scores
- [ ] User can review each stage's outputs independently

---

## Example Usage Session

```
User: /audit-javascript

Claude: Starting comprehensive JavaScript codebase audit...

[Stage 1] Generating architecture artifacts...
  ✓ Architecture overview created
  ✓ Component dependency diagram created
  ✓ Data flow diagrams created (3 flows)
  ✓ Sequence diagrams created (2 critical paths)
  ✓ Entity relationship diagram created
  ✓ Tech debt surface map created

Evaluation Checkpoint: Please review .analysis/stage1-artifacts/architecture-overview.md
Does this correctly describe your system? (Y/n)

User: Y

Claude: [Stage 2] Launching 4 independent analysis agents in parallel...
  ⏳ Architecture Analyzer running...
  ⏳ Security Analyzer running...
  ⏳ Maintainability Analyzer running...
  ⏳ Dependency Analyzer running...

  ✓ Architecture: 15 findings
  ✓ Security: 18 findings
  ✓ Maintainability: 22 findings
  ✓ Dependency: 12 findings

Convergence Preview: 8 findings identified by multiple agents (high confidence)

[Stage 3] Running static analysis tools...
  ✓ ESLint: 34 findings
  ✓ npm audit: 5 vulnerabilities
  ✓ Coverage: 12 low-coverage files
  ✓ Results unified to .analysis/stage3-static-analysis/unified-results.json

[Stage 4] Reconciling findings...
  ✓ 67 total raw findings reconciled to 45 unique findings
  ✓ 15 high-confidence (convergent across agents + tools)
  ✓ 3 contradictions identified for review

[Stage 5] Adversarial challenge...
  ✓ 45 findings challenged
  ✓ 31 upheld
  ✓ 8 downgraded
  ✓ 6 dismissed as false positives

[Stage 6] Final synthesis...
  ✓ Top 10 selected based on severity × confidence × effort-to-value
  ✓ Executive reports generated

## Analysis Complete

**Deliverables**:
- ANALYSIS-REPORT.md (Top 10 with detailed recommendations)
- ARCHITECTURE-OVERVIEW.md (System architecture documentation)
- FINDINGS-DETAILED.json (Complete structured data)
- CONFIDENCE-MATRIX.md (Evidence transparency)

**Summary**:
- 31 valid findings identified
- Top 10 prioritized for immediate action
- 5 critical, 3 high, 2 medium severity in top 10
- Average confidence: High (82% convergence across sources)

Review ANALYSIS-REPORT.md for your top 10 prioritized improvements.
```

---

This skill provides maximum accuracy through independent agent analysis, static tool validation, adversarial challenge, and evidence-based prioritization.
