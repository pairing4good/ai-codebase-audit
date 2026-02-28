# AI Codebase Audit System

A production-ready, reusable analytical system for auditing JavaScript, Java, and .NET codebases with maximum accuracy using Claude Code.

## Overview

This system uses a **6-stage analytical funnel** with **independent sub-agents** to provide the most accurate and defensible code quality assessments possible with AI-assisted analysis.

### Why This Approach?

- **Independent Analysis**: 4 specialist agents analyze your code in complete isolation, eliminating confirmation bias
- **Evidence-Based**: Findings that converge across multiple agents AND static analysis tools are statistically high-confidence
- **Transparent**: Every stage produces reviewable artifacts so you can audit the audit
- **Actionable**: Final top 10 includes exact locations, code examples, and specific fixes

## Quick Start

### Prerequisites

- [Claude Code](https://code.claude.com) installed
- For JavaScript: Node.js, npm, ESLint
- For Java: JDK, Maven/Gradle, SpotBugs
- For .NET: .NET SDK, dotnet CLI

### Installation

1. Clone this repository into your workspace
2. The `.claude/` directory contains all agents and skills
3. Navigate to the repository you want to audit
4. Run the appropriate audit command

### Basic Usage

```bash
# From within the target repository you want to audit
/audit-javascript    # For JavaScript/TypeScript projects
/audit-java          # For Java projects
/audit-dotnet        # For C#/F# projects
```

### What You Get

After the audit completes, you'll find these files in your target repository:

1. **ANALYSIS-REPORT.md** - Executive summary with top 10 prioritized improvements
2. **ARCHITECTURE-OVERVIEW.md** - System architecture documentation with diagrams
3. **FINDINGS-DETAILED.json** - Complete structured data for all findings
4. **CONFIDENCE-MATRIX.md** - Evidence transparency showing what converged across sources
5. **.analysis/** - All stage-by-stage outputs for detailed review

## The 6-Stage Analytical Funnel

### Stage 1: Artifact Generation
Creates comprehensive architecture documentation before any analysis:
- Architecture overview
- Component dependency diagrams (Mermaid)
- Data flow diagrams
- Critical path sequence diagrams
- Entity relationship overview
- Tech debt surface map

**Output**: `.analysis/stage1-artifacts/`

### Stage 2: Parallel Independent Analysis
Four specialist agents analyze your codebase in complete isolation:
- **Architecture Analyzer**: Structural and design issues
- **Security Analyzer**: Vulnerabilities and attack surfaces
- **Maintainability Analyzer**: Code quality and technical debt
- **Dependency Analyzer**: Supply chain and versioning risks

Each agent produces an independent longlist with zero knowledge of what the others found.

**Output**: `.analysis/stage2-parallel-analysis/`

### Stage 3: Static Analysis
Runs stack-specific static analysis tools in parallel:

**JavaScript**: ESLint + security plugins, SonarQube, npm audit, Istanbul coverage
**Java**: SpotBugs + Find Security Bugs, PMD, SonarQube, OWASP Dependency Check
**.NET**: Roslyn analyzers, Security Code Scan, SonarQube, dotnet-outdated

Results are unified into a standardized JSON format for easy consumption.

**Output**: `.analysis/stage3-static-analysis/`

### Stage 4: Reconciliation
A fresh agent (with no prior analysis) synthesizes all findings:
- Identifies convergence across independent agents
- Maps findings to static analysis evidence
- Assigns confidence scores based on convergence
- Produces merged longlist with evidence tracking

**Output**: `.analysis/stage4-reconciliation/`

### Stage 5: Adversarial Challenge
An independent agent challenges every finding to eliminate false positives:
- Reviews each finding with fresh eyes
- Identifies overstatements and false positives
- Verifies severity classifications
- Produces verdicts: upheld/downgraded/dismissed

**Output**: `.analysis/stage5-adversarial/`

### Stage 6: Final Synthesis
Generates final top 10 prioritized by:
- **Severity**: Critical > High > Medium > Low
- **Confidence**: High (converged) > Medium > Low
- **Effort-to-Value**: Quick wins prioritized

**Output**: `.analysis/stage6-final-synthesis/` + top-level deliverables

## Understanding Output Confidence Levels

### High Confidence
Finding identified by **multiple independent agents AND static analysis tools**

Example: SQL injection found by Security Agent + Architecture Agent + SonarQube + ESLint

### Medium Confidence
Finding identified by **agents OR static tools, but not both**

Example: Architectural issue found by Architecture Agent + Maintainability Agent, but no static tool detected it

### Low Confidence
Finding from **single source only**

Example: Only one agent or one tool identified it

## Evaluating Stage Outputs

### After Stage 1
Review `.analysis/stage1-artifacts/architecture-overview.md` to verify Claude understood your system correctly. If the architecture description is wrong, the rest of the analysis will be compromised.

### After Stage 2
Review `.analysis/stage2-parallel-analysis/convergence-preview.md` to see what multiple agents independently flagged. These are your highest-signal findings.

### After Stage 3
Check `.analysis/stage3-static-analysis/tool-comparison.md` to see which tools found what. If a tool failed to run, you'll see it here.

### After Stage 4
Review `.analysis/stage4-reconciliation/contradictions.md` to see where agents disagreed with static tools. These areas often need human judgment.

### After Stage 5
Check `.analysis/stage5-adversarial/false-positives-identified.md` to see what was dismissed. This builds trust in the final recommendations.

### After Stage 6
The top-level `ANALYSIS-REPORT.md` contains your final top 10 with complete evidence and recommendations.

## Customization

### Adjusting Prioritization
Edit the scoring weights in the Stage 6 synthesis:
```json
{
  "severity_weight": 0.4,      // How much to weight severity
  "confidence_weight": 0.3,    // How much to weight evidence
  "effort_to_value_weight": 0.3  // How much to prioritize quick wins
}
```

### Running Individual Stages
For debugging or iterative refinement:
```bash
/audit-javascript --stages=1      # Just artifacts
/audit-javascript --stages=1,2,3  # Stop after static analysis
```

### Custom Static Analysis Tools
Add your own tools by:
1. Creating a runner script in `.claude/skills/audit-{stack}/tools/`
2. Ensuring it outputs to the standardized JSON format
3. Updating `unified-results.json` formatter to include it

## Tech Stack Details

### JavaScript/TypeScript Support
- **Frameworks**: React, Vue, Angular, Node.js, Express, Next.js, NestJS
- **Tools**: ESLint, eslint-plugin-security, eslint-plugin-sonarjs, SonarQube, npm audit, Istanbul/nyc
- **Focus**: Async patterns, promise handling, dependency vulnerabilities, security misconfigurations

### Java Support
- **Frameworks**: Spring, Spring Boot, Jakarta EE, Hibernate, Micronaut
- **Tools**: SpotBugs, Find Security Bugs, PMD, SonarQube, OWASP Dependency Check, JaCoCo
- **Focus**: Concurrency issues, memory leaks, exception handling, SQL injection, XXE

### .NET Support
- **Frameworks**: ASP.NET Core, Entity Framework, Blazor, SignalR
- **Tools**: Roslyn analyzers, Security Code Scan, SonarQube, dotnet-outdated, coverlet
- **Focus**: LINQ patterns, async/await misuse, dependency injection, authentication

## Customizing Output Formats

### Design Philosophy: Embedded Format Examples

This system uses **embedded format examples** in agent and skill files rather than external templates. This follows Claude Code best practices (2025) and provides:

- ✅ **Flexibility**: Claude adapts format to content dynamically
- ✅ **Simplicity**: No template engine or file I/O overhead
- ✅ **Maintainability**: Format defined with context in one place
- ✅ **Speed**: Direct generation from prompts with examples

### How to Customize Outputs

**Agent Outputs** (Stage 1-5):
- Edit `.claude/agents/[agent-name].md`
- Find the "Output Format" section
- Modify the JSON schema or markdown examples
- Example: To change architecture analysis format, edit `architecture-analyzer.md` lines 227-329

**Final Deliverables** (Stage 6):
- Edit `.claude/skills/audit-javascript/SKILL.md`
- Find the "Stage 6 Prompt" section (lines 500-540)
- Modify the ANALYSIS-REPORT.md template
- Changes apply to all future audits

**Tool Output Formatting**:
- Edit `.claude/skills/audit-javascript/tools/format-static-results.js`
- Modify the `createFinding()` function or output schema
- This controls how static analysis results are unified

**Why No Templates Directory?**

You may notice there's no `templates/` directory. This is intentional. External template files would:
- Add complexity (template engine, file I/O)
- Reduce flexibility (rigid formats vs adaptive generation)
- Be harder to maintain (format separated from context)
- Not follow Claude Code conventions

Instead, formats are defined inline where they're used, making the system simpler and more maintainable.

## Troubleshooting

### "Static analysis tools not found"
Install the required tools for your tech stack. See the tech stack section for tool lists.

### "Agent produced empty output"
Check `.analysis/stage{N}/metadata.json` for error messages. The agent may have hit context limits or permission issues.

### "Convergence score is low"
This is normal for codebases where issues are very specific to one domain. Low convergence doesn't mean findings are wrong, just that they're specialized.

### "Top 10 doesn't match my expectations"
Review `.analysis/stage6-final-synthesis/all_candidates_ranked.json` to see the complete prioritization. You can adjust weights and re-run Stage 6.

## Contributing

This system is designed to be extended:

1. **New Tech Stacks**: Copy `.claude/skills/audit-javascript/` and adapt static tools
2. **New Specialist Agents**: Add new agents to Stage 2 for additional perspectives
3. **Custom Output Formats**: Modify embedded examples in agent/skill `.md` files (see "Customizing Output Formats" above)
4. **Additional Static Tools**: Add runners in `tools/` directories with standardized JSON output

## License

[Add your license here]

## Support

For issues, questions, or contributions, please see the project repository.

## Acknowledgments

Built with [Claude Code](https://code.claude.com) using best practices for agent-based code analysis.
