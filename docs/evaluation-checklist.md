# Evaluation Checklist

Use this checklist to review audit quality at each stage. Catching issues early prevents wasted time in later stages.

## Stage 1: Artifact Generation ✓

**Goal**: Verify Claude understood the codebase correctly

### Quick Check (2 minutes)

Read `.analysis/stage1-artifacts/architecture-overview.md` and answer:

- [ ] **System purpose correct?** Does it accurately describe what your application does?
- [ ] **Tech stack identified?** Are the language, framework, and database correct?
- [ ] **Major components listed?** Are all important modules/services mentioned?

**If any answer is NO**: Stage 1 failed. Regenerate before continuing.

### Detailed Review (10 minutes)

Review additional artifacts:

#### Component Dependency Diagram
- [ ] Open `.analysis/stage1-artifacts/component-dependency.mermaid`
- [ ] Render in Mermaid viewer (VS Code extension or mermaid.live)
- [ ] All major components shown?
- [ ] Dependencies arrows point the right direction? (A → B means A depends on B)
- [ ] Missing any key modules?

#### Data Flow Diagrams
- [ ] Check `.analysis/stage1-artifacts/data-flow-diagrams/`
- [ ] Critical business operations documented? (auth, checkout, etc.)
- [ ] Data flows make sense?
- [ ] Trust boundaries identified?

#### Tech Debt Surface Map
- [ ] Open `.analysis/stage1-artifacts/tech-debt-surface-map.md`
- [ ] High-churn files identified? (frequently modified)
- [ ] Large files (>500 lines) found?
- [ ] Git churn analysis included?

### Common Stage 1 Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| **Wrong tech stack** | Says "Java" but it's JavaScript | Check package.json/pom.xml detection |
| **Incomplete component diagram** | Missing major modules | Verify all source directories were scanned |
| **Generic descriptions** | "This is a web app" | Re-run with instruction to be specific |
| **Missing data flows** | No auth/payment flows | Explicitly request critical path analysis |

### Stage 1 Sign-Off

**Before proceeding to Stage 2, confirm**:
- [ ] Architecture overview is accurate
- [ ] Component diagram is complete
- [ ] At least 2-3 data flow diagrams created
- [ ] Tech debt surface map includes git analysis

**Confidence Level**: ____ / 10 that Stage 1 accurately represents the codebase

---

## Stage 2: Parallel Independent Analysis ✓

**Goal**: Verify agents produced quality findings independently

### Quick Check (5 minutes)

Check that all 4 agents completed:

- [ ] `.analysis/stage2-parallel-analysis/architecture-analysis.json` exists
- [ ] `.analysis/stage2-parallel-analysis/security-analysis.json` exists
- [ ] `.analysis/stage2-parallel-analysis/maintainability-analysis.json` exists
- [ ] `.analysis/stage2-parallel-analysis/dependency-analysis.json` exists

Open `convergence-preview.md`:
- [ ] Are there 3+ findings that appeared in multiple agents?
- [ ] Do convergent findings have specific file:line locations?

**If no convergence**: Agents may have analyzed different aspects (normal) OR agents may have failed.

### Detailed Review (20 minutes)

Review each agent's output:

#### Architecture Analyzer
Open `architecture-analysis.json`:

- [ ] **Findings count**: 10-20 findings (typical range)
- [ ] **Specific locations**: Every finding has file:line reference?
- [ ] **Categories**: Mix of pattern violations, coupling issues, layer violations?
- [ ] **Code examples**: Every finding includes actual code snippet?
- [ ] **Reasoning**: Agent explains WHY each issue is architecturally significant?

**Sample finding to check**:
```json
{
  "id": "ARCH-001",
  "title": "Layer Violation: Controllers Directly Accessing Database",
  "severity": "high",
  "locations": ["src/controllers/UserController.js:45-52"],
  "example": { "file": "...", "code": "actual code here" },
  "reasoning": "Violates MVC + Service Layer architecture because...",
  "recommendation": { "summary": "...", "example": "fixed code here" }
}
```

**Red flags**:
- Generic findings without specific locations ("throughout the codebase")
- Severity mismatch (style issues marked "critical")
- Missing code examples
- No actionable recommendations

#### Security Analyzer
Open `security-analysis.json`:

- [ ] **Findings count**: 5-20 findings (more is normal for first audit)
- [ ] **OWASP categories**: Mix of injection, auth issues, crypto, etc.?
- [ ] **Attack scenarios**: Findings explain HOW to exploit?
- [ ] **Severity appropriate**: Critical only for RCE, data breach, auth bypass?

**Check for**:
- [ ] SQL injection findings (if app uses SQL database)
- [ ] XSS findings (if app renders user content)
- [ ] Auth/authorization checks (if app has user accounts)
- [ ] Hardcoded secrets (common issue)
- [ ] Dependency vulnerabilities (should appear here AND in dependency-analyzer)

**Red flags**:
- No findings (suspicious for any real application)
- All findings are "critical" (severity inflation)
- Findings without exploit scenarios
- Test code flagged as production vulnerabilities

#### Maintainability Analyzer
Open `maintainability-analysis.json`:

- [ ] **Findings count**: 15-30 findings (technical debt is common)
- [ ] **Categories**: Mix of complexity, duplication, testing, code smells?
- [ ] **Metrics included**: Cyclomatic complexity, file size, duplication percentage?
- [ ] **Test coverage analysis**: Files without tests identified?

**Check for**:
- [ ] High complexity findings (functions >15 complexity)
- [ ] Code duplication (same logic in multiple places)
- [ ] Missing tests (especially for business logic)
- [ ] Code smells (long parameter lists, god objects, etc.)

**Red flags**:
- Only style issues (missing actual quality problems)
- Test code flagged as "duplicate" of production code
- Complexity metrics without context

#### Dependency Analyzer
Open `dependency-analysis.json`:

- [ ] **Findings count**: 5-15 findings (every project has some outdated deps)
- [ ] **Vulnerability summary**: CVE IDs for known vulnerabilities?
- [ ] **Version analysis**: Packages multiple major versions behind?
- [ ] **Deprecated packages**: Unmaintained libraries identified?

**Check for**:
- [ ] Known CVEs in dependencies (check npm audit/OWASP results)
- [ ] Deprecated packages (request, moment, etc.)
- [ ] Major version lags (using v2 when v5 exists)
- [ ] Missing lockfile (if applicable)

**Red flags**:
- No findings (unlikely unless very well-maintained project)
- All dev dependencies treated as production issues
- No CVE details for vulnerability findings

### Convergence Analysis

Open `convergence-preview.md`:

**High-signal findings** (multiple agents flagged independently):
- [ ] List 3-5 findings that appeared in 2+ agents
- [ ] These should be your highest-priority candidates
- [ ] Verify these are genuinely the same issue (same file:line)

**Example of good convergence**:
```
SQL Injection in Payment Processing (src/services/payment.js:156)
- Security Agent: Unsafe SQL query construction
- Architecture Agent: Layer violation (controller accessing DB directly)
CONVERGENCE: Both agents independently identified this code as problematic
```

### Stage 2 Sign-Off

**Before proceeding to Stage 3, confirm**:
- [ ] All 4 agents completed successfully
- [ ] Each agent produced 5+ specific findings
- [ ] Findings have file:line locations and code examples
- [ ] Convergence preview shows 3+ multi-agent findings
- [ ] No obvious false positives (test code flagged, framework features misunderstood)

**Confidence Level**: ____ / 10 that agent findings are high quality

---

## Stage 3: Static Analysis ✓

**Goal**: Verify static tools ran successfully and produced useful results

### Quick Check (3 minutes)

Check which tools ran:

- [ ] `.analysis/stage3-static-analysis/unified-results.json` exists
- [ ] Open unified-results.json and check `tool_results` section
- [ ] All expected tools have `"status": "success"`?

Expected tools for JavaScript:
- [ ] ESLint (or similar linter)
- [ ] npm audit (dependency vulnerabilities)
- [ ] Coverage tool (if tests exist)
- [ ] SonarQube (if configured)

### Detailed Review (15 minutes)

#### Unified Results
Open `.analysis/stage3-static-analysis/unified-results.json`:

**Check totals**:
- [ ] **Total findings**: 20-100 (typical range)
- [ ] **Severity breakdown**: Not all "low" (tools should find real issues)
- [ ] **Findings by category**: Mix of categories (security, quality, dependencies)

**Check findings array**:
```json
{
  "source": "eslint",
  "rule": "security/detect-unsafe-query",
  "severity": "high",
  "location": "src/services/payment.js:156",
  "file": "src/services/payment.js",
  "line": 156,
  "message": "Unsafe SQL query construction"
}
```

- [ ] Each finding has source, rule, severity, location?
- [ ] Locations are specific (file:line)?
- [ ] Messages are meaningful?

#### Tool Comparison
Open `.analysis/stage3-static-analysis/tool-comparison.md`:

- [ ] Lists which tools found which issues?
- [ ] Shows overlap between tools?
- [ ] Identifies tool-specific findings?

**Example**:
```markdown
## Overlap Analysis

Finding: SQL Injection in payment.js:156
- Found by: SonarQube (sqli-001), ESLint (security/detect-unsafe-query)
- Convergence: HIGH

Finding: Hardcoded secret in config.js:12
- Found by: SonarQube only
- Convergence: LOW (tool-specific)
```

#### Coverage Gaps
If coverage tool ran, open `.analysis/stage3-static-analysis/coverage-gaps.md`:

- [ ] Critical files identified? (from Stage 1 sequence diagrams)
- [ ] Coverage percentage for critical paths?
- [ ] Files with <50% coverage listed?

### Common Stage 3 Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| **Tool not found** | "eslint: command not found" | Install missing tool or skip |
| **Empty results** | 0 findings from tool | Check tool config, may need .eslintrc |
| **Wrong tech stack** | Trying to run Java tools on JS project | Verify tech stack detection in Stage 1 |
| **Tool errors** | "status": "error" in unified-results.json | Check raw outputs for error messages |

### Stage 3 Sign-Off

**Before proceeding to Stage 4, confirm**:
- [ ] At least 2 static tools ran successfully
- [ ] Unified results contain 10+ findings
- [ ] Tool comparison shows some overlap (good sign)
- [ ] npm audit ran (even if 0 vulnerabilities)

**Confidence Level**: ____ / 10 that static analysis is comprehensive

---

## Stage 4: Reconciliation ✓

**Goal**: Verify findings were synthesized correctly with proper convergence analysis

### Quick Check (5 minutes)

Open `.analysis/stage4-reconciliation/reconciled-longlist.json`:

**Check summary**:
- [ ] `total_reconciled_findings`: 30-60 (typical range after merging duplicates)
- [ ] `high_confidence`: 10-20 findings (convergent across agents + tools)
- [ ] `agent_only`: 5-15 findings (architectural insights)
- [ ] `tool_only`: 5-15 findings (pattern matches)

**Sanity check**:
- Input findings (Stages 2+3): ~70-150 total
- Output findings (Stage 4): 30-60 reconciled
- **Reduction expected**: Reconciliation should merge duplicates

### Detailed Review (20 minutes)

#### Reconciled Findings
Pick 3 high-confidence findings and verify structure:

```json
{
  "id": "RECON-001",
  "title": "SQL Injection in Payment Processing",
  "confidence": "high",
  "convergence_score": 0.95,
  "severity": "critical",
  "evidence": {
    "agents": [
      { "source": "security-analyzer", "finding_id": "SEC-001" },
      { "source": "architecture-analyzer", "finding_id": "ARCH-005" }
    ],
    "static_tools": [
      { "source": "sonarqube", "rule": "sqli-001" },
      { "source": "eslint", "rule": "security/detect-unsafe-query" }
    ],
    "convergence": {
      "agent_count": 2,
      "static_tool_count": 2,
      "total_sources": 4
    }
  }
}
```

**Verify**:
- [ ] Evidence lists both agents AND static tools (for high confidence)
- [ ] Convergence score matches source count (4 sources = high score)
- [ ] Original finding IDs are referenced (traceability)

#### Convergence Analysis
Open `.analysis/stage4-reconciliation/convergence-analysis.md`:

**Check for**:
- [ ] Explanation of high-confidence findings (why convergence matters)
- [ ] Examples of convergent findings with source lists
- [ ] Discussion of agent-only vs. tool-only findings

**Example to look for**:
```markdown
### Pattern 1: Security + Architecture Convergence
When Security and Architecture agents both flag the same code, it's typically a security vulnerability caused by architectural violation.

Example: SQL injection from layer boundary violation (SEC-001 + ARCH-005)
```

#### Contradictions
Open `.analysis/stage4-reconciliation/contradictions.md`:

**If contradictions exist**:
- [ ] Are they genuine disagreements (not just severity differences)?
- [ ] Is there a recommended resolution?
- [ ] Does the resolution make sense?

**Example contradiction**:
```markdown
## Hardcoded JWT Secret Severity Disagreement

Security Agent: CRITICAL (enables token forgery)
SonarQube: MINOR (hardcoded string pattern)

Resolution: CRITICAL is correct - SonarQube lacks context to understand security implication.
```

**Check resolution**:
- [ ] For security issues, trust security-context-aware analysis
- [ ] For quality issues, trust metrics-based static analysis
- [ ] For architecture issues, trust architectural reasoning

### Agent-Only vs. Tool-Only Findings

#### Agent-Only Findings
Open `.analysis/stage4-reconciliation/agent-only-findings.md`:

**These should be**:
- Architectural insights (circular dependencies, design patterns)
- Context-aware security issues (authentication flows)
- Qualitative assessments (code organization, naming)

**Red flags**:
- Agent flagged something tools should catch (basic syntax errors)
- Agent missed something tools found (suggests prompt issues)

#### Tool-Only Findings
Open `.analysis/stage4-reconciliation/tool-only-findings.md`:

**These should be**:
- Granular style issues (missing semicolons)
- Pattern matches (magic numbers, unused variables)
- Specific rule violations

**Red flags**:
- Tool found critical security issue agents missed
- Tool flagged false positives agents would recognize

### Stage 4 Sign-Off

**Before proceeding to Stage 5, confirm**:
- [ ] Reconciled findings are properly merged (no duplicates)
- [ ] High-confidence findings have 3+ sources
- [ ] Contradictions are resolved sensibly
- [ ] Agent-only findings are architectural insights
- [ ] Tool-only findings are pattern matches

**Confidence Level**: ____ / 10 that reconciliation is accurate

---

## Stage 5: Adversarial Challenge ✓

**Goal**: Verify findings survived rigorous challenge and false positives were caught

### Quick Check (5 minutes)

Open `.analysis/stage5-adversarial/challenged-findings.json`:

**Check summary**:
- [ ] `total_challenged`: Should match Stage 4 reconciled count
- [ ] `upheld`: 60-80% (most findings should survive)
- [ ] `downgraded`: 10-20% (some severity inflation is normal)
- [ ] `dismissed`: 5-15% (some false positives expected)

**Sanity check**:
- If >50% dismissed: Adversarial agent may be too aggressive
- If <5% dismissed: Adversarial agent may not be challenging enough
- If 0% dismissed: Suspicious - every audit has some false positives

### Detailed Review (15 minutes)

#### False Positives
Open `.analysis/stage5-adversarial/false-positives-identified.md`:

**For each dismissed finding**:
- [ ] Read the original claim
- [ ] Read the challenge reasoning
- [ ] Verify the code location yourself
- [ ] Agree with dismissal?

**Common valid false positives**:
- Test code flagged as production code
- Framework features misunderstood (middleware, decorators)
- Intentional design decisions (documented in comments)
- Deprecated but still valid code

**Example to review**:
```markdown
## RECON-012: Hardcoded Database Password (DISMISSED)

Original Claim: Critical - hardcoded password
Reality: Test fixture code
Location: src/__tests__/fixtures/testDb.js:8

Why False Positive:
Test fixtures intentionally use simple credentials for test databases.
Production code (src/config/database.js) correctly uses environment variables.
```

**Verify**:
- [ ] Is this actually test code? (check file path)
- [ ] Is production code secure? (check referenced file)
- [ ] Decision correct?

#### Severity Adjustments
Open `.analysis/stage5-adversarial/severity-adjustments.md`:

**For each downgrade**:
- [ ] Original severity
- [ ] Adjusted severity
- [ ] Reason for downgrade

**Valid reasons for downgrade**:
- Mitigating controls found (rate limiting at infrastructure level)
- Lower exploitability than assumed (internal-only API)
- Context reduces impact (dev dependency, not production)

**Example**:
```markdown
## RECON-023: Missing Rate Limiting
Original: HIGH
Adjusted: MEDIUM
Reason: Nginx rate limiting + account lockout provide adequate protection
```

**Red flags**:
- Critical security issues downgraded without good reason
- Downgrades based on "low likelihood" (likelihood != severity)
- All findings of a certain type downgraded (suggests bias)

#### Upheld Findings
Review 3-5 upheld findings:

```json
{
  "original_finding_id": "RECON-001",
  "challenge_verdict": "UPHELD",
  "challenge_reasoning": "Verified code at location. SQL injection is genuine. No mitigation found.",
  "code_verification": {
    "location": "src/services/payment.js:156-162",
    "code_matches_claim": true,
    "mitigating_controls_found": false
  },
  "final_severity": "critical"
}
```

**Check**:
- [ ] Challenge reasoning is thorough
- [ ] Code was actually verified (not just accepted)
- [ ] Mitigating controls were checked for
- [ ] Verdict makes sense

### Stage 5 Sign-Off

**Before proceeding to Stage 6, confirm**:
- [ ] False positives dismissed with good reasoning
- [ ] Severity adjustments are justified
- [ ] Upheld findings were genuinely verified
- [ ] 60-80% of findings survived challenge

**Confidence Level**: ____ / 10 that challenged findings are accurate

---

## Stage 6: Final Synthesis ✓

**Goal**: Verify top 10 prioritization is sensible and final deliverables are complete

### Quick Check (5 minutes)

**Check file existence**:
- [ ] `ANALYSIS-REPORT.md` exists at repository root
- [ ] `ARCHITECTURE-OVERVIEW.md` exists at repository root
- [ ] `FINDINGS-DETAILED.json` exists at repository root
- [ ] `CONFIDENCE-MATRIX.md` exists at repository root

Open `ANALYSIS-REPORT.md`:
- [ ] Contains exactly 10 findings (or fewer if not enough qualified)
- [ ] Each finding has location, evidence, code example, recommendation

### Detailed Review (20 minutes)

#### Prioritization Matrix
Open `.analysis/stage6-final-synthesis/prioritization-matrix.json`:

**Check scoring criteria**:
```json
{
  "scoring_criteria": {
    "severity_weight": 0.4,
    "confidence_weight": 0.3,
    "effort_to_value_weight": 0.3
  }
}
```

- [ ] Weights sum to 1.0?
- [ ] Severity has highest weight (typical)?
- [ ] Confidence weighted appropriately?

**Check ranked findings**:
- [ ] All upheld findings from Stage 5 are included?
- [ ] Findings sorted by `priority_score`?
- [ ] Top 10 have highest scores?

**Verify scoring**:
Pick the #1 finding and recalculate:
```
priority_score = (0.4 * severity_score) + (0.3 * confidence_score) + (0.3 * effort_value_score)

severity_score: critical=4, high=3, medium=2, low=1
confidence_score: high=3, medium=2, low=1
effort_value_score: (effort: low=3, medium=2, high=1) * (impact: critical=4, high=3, etc.)
```

- [ ] Math checks out?

#### Top 10 Detailed
Open `.analysis/stage6-final-synthesis/top-10-detailed.json`:

**For each of the top 10**:
- [ ] Finding is from upheld (not dismissed) findings?
- [ ] Has high confidence or critical severity?
- [ ] Includes complete recommendation?
- [ ] Has adversarial challenge result?

#### Honorable Mentions
Open `.analysis/stage6-final-synthesis/honorable-mentions.md`:

**Check findings #11-20**:
- [ ] Are these genuinely less important than top 10?
- [ ] Or is prioritization wrong?
- [ ] Any critical issues that should be in top 10?

**Example**:
```markdown
## #11: Missing Input Validation on User Registration
Severity: High | Confidence: High | Priority Score: 7.8

This narrowly missed the top 10 but is still important...
```

**Review**:
- [ ] If #11 is critical severity, why not in top 10? (may need reprioritization)
- [ ] If top 10 has low/medium, why prioritized over high-severity #11?

#### Quick Wins
Open `.analysis/stage6-final-synthesis/quick-wins.md`:

**Low-effort, high-impact findings**:
- [ ] These should be genuinely quick (<4 hours)
- [ ] High value despite not being top 10?
- [ ] Consider doing these first for momentum

### Final Deliverable Review

#### ANALYSIS-REPORT.md
Open `ANALYSIS-REPORT.md` at repository root:

**Executive summary**:
- [ ] 1-paragraph overview of system health?
- [ ] High-level themes (security issues, tech debt, etc.)?

**Each of top 10**:
- [ ] Title clearly describes the issue
- [ ] Location is clickable link
- [ ] Confidence level shown with evidence
- [ ] Impact clearly stated
- [ ] Effort estimate (low/medium/high)
- [ ] Code example shows the problem
- [ ] Recommendation shows the fix
- [ ] Adversarial challenge result included

**Format check**:
- [ ] Markdown renders correctly
- [ ] Code blocks have syntax highlighting
- [ ] Links are relative (work when shared)

#### CONFIDENCE-MATRIX.md
Open `CONFIDENCE-MATRIX.md`:

**Check table**:
| Finding | Agents | Static Tools | Convergence Score |
|---------|--------|--------------|-------------------|
| SQL Injection | Security, Architecture | SonarQube, ESLint | 95% |

- [ ] All top 10 findings listed?
- [ ] Evidence sources shown?
- [ ] Convergence scores accurate?

### Stage 6 Sign-Off

**Before delivering to stakeholders, confirm**:
- [ ] Top 10 findings are correctly prioritized
- [ ] All findings have complete recommendations
- [ ] ANALYSIS-REPORT.md is well-formatted and professional
- [ ] CONFIDENCE-MATRIX.md shows strong evidence
- [ ] Honorable mentions reviewed (none more critical than top 10)

**Confidence Level**: ____ / 10 that final deliverables are stakeholder-ready

---

## Overall Audit Quality Assessment

### Final Checklist

- [ ] All 6 stages completed successfully
- [ ] Stage 1 artifacts accurately represent codebase
- [ ] Stage 2 agents produced quality findings independently
- [ ] Stage 3 static tools ran successfully
- [ ] Stage 4 reconciliation identified convergent findings
- [ ] Stage 5 adversarial challenge caught false positives
- [ ] Stage 6 top 10 is sensibly prioritized

### Confidence Score

Calculate overall confidence:
```
Overall Confidence =
  (Stage 1 confidence × 0.15) +
  (Stage 2 confidence × 0.25) +
  (Stage 3 confidence × 0.15) +
  (Stage 4 confidence × 0.20) +
  (Stage 5 confidence × 0.15) +
  (Stage 6 confidence × 0.10)
```

**Example**:
- Stage 1: 9/10 (architecture correct)
- Stage 2: 8/10 (quality findings)
- Stage 3: 7/10 (some tools failed)
- Stage 4: 9/10 (good convergence)
- Stage 5: 8/10 (caught false positives)
- Stage 6: 9/10 (sensible prioritization)

Overall: (9×0.15) + (8×0.25) + (7×0.15) + (9×0.20) + (8×0.15) + (9×0.10) = **8.35/10**

### Quality Grades

- **9-10**: Excellent - High confidence in all findings
- **7-8**: Good - Minor issues, findings are trustworthy
- **5-6**: Fair - Some concerns, manual review recommended
- **<5**: Poor - Re-run audit with corrections

---

Use this checklist at each stage to ensure maximum audit accuracy and catch issues before they compound in later stages.
