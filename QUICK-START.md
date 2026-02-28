# Quick Start Guide - AI Codebase Audit System

**Get started in under 5 minutes!**

This guide shows you how to audit any JavaScript/TypeScript repository using the AI Codebase Audit System.

---

## What You Need

1. [Claude Code](https://code.claude.com) installed
2. A JavaScript/TypeScript repository you want to audit
3. (Optional) Static analysis tools for deeper insights

---

## Installation Methods

Choose the method that works best for your workflow:

### Method 1: Copy to Target Repository (Recommended for Quick Audits)

This method copies the audit system directly into the repository you want to analyze.

**When to use**: One-time audits, quick assessments, isolated projects

#### Step 1: Copy the `.claude/` Directory

```bash
# From this repository's directory
cp -r .claude /path/to/your/target/repo/

# Or if you prefer a one-liner from your target repo:
cd /path/to/your/target/repo
cp -r /path/to/ai-codebase-audit/.claude .
```

#### Step 2: Navigate to Your Target Repository

```bash
cd /path/to/your/target/repo
```

#### Step 3: Open in Claude Code

```bash
# Open the target repository in Claude Code
code .  # or however you launch your editor with Claude Code
```

#### Step 4: Run the Audit

In Claude Code, run the appropriate command for your project type:

```bash
# For JavaScript/TypeScript projects (✅ Fully Implemented)
/audit-javascript

# For Java projects (✅ Fully Implemented)
/audit-java

# For .NET/C#/F# projects (✅ Fully Implemented)
/audit-dotnet
```

**All three stacks are now fully implemented!** Each runs through 7 stages (Stage 0-6) including build validation.

The audit will run automatically through all stages.

---

### Method 2: Shared Installation (Recommended for Multiple Projects)

This method installs the audit system once and reuses it across multiple repositories.

**When to use**: Regular audits, multiple projects, team environments

#### Step 1: Clone This Repository to a Permanent Location

```bash
# Clone to a shared location (e.g., ~/tools/)
git clone <this-repo-url> ~/tools/ai-codebase-audit
```

#### Step 2: Configure Claude Code Workspace

Create a workspace configuration that includes both:
- This audit system repository
- Your target repository

In Claude Code, add both folders to your workspace.

#### Step 3: Run Audits

Navigate to any project in your workspace and run the appropriate command:

```bash
# For JavaScript/TypeScript projects (✅ Fully Implemented)
/audit-javascript

# For Java projects (✅ Fully Implemented)
/audit-java

# For .NET/C#/F# projects (✅ Fully Implemented)
/audit-dotnet
```

**All three stacks are now fully implemented!**

The skills and agents from the audit system will be available to all projects in the workspace.

---

## What Gets Copied?

When you copy the `.claude/` directory, you get:

### Required Files (Total: ~20 files)

```
.claude/
├── settings.json                    # Permissions and configuration
├── settings.local.json              # Local overrides (optional)
│
├── agents/                          # 7 specialist agents
│   ├── artifact-generator.md        # Stage 1: Architecture artifacts
│   ├── architecture-analyzer.md     # Stage 2: Structural analysis
│   ├── security-analyzer.md         # Stage 2: Security analysis
│   ├── maintainability-analyzer.md  # Stage 2: Code quality analysis
│   ├── dependency-analyzer.md       # Stage 2: Dependency analysis
│   ├── reconciliation-agent.md      # Stage 4: Finding synthesis
│   └── adversarial-agent.md         # Stage 5: False positive elimination
│
└── skills/
    └── audit-javascript/
        ├── SKILL.md                 # Main orchestration skill
        └── tools/
            ├── format-static-results.js    # Unifies tool outputs
            ├── install-tools.sh            # Tool installation guide
            ├── semgrep-runner.sh           # Semgrep integration
            ├── snyk-runner.sh              # Snyk integration
            └── trivy-runner.sh             # Trivy integration
```

**Total Size**: ~2-3 MB (mostly text files)

---

## Optional: Install Static Analysis Tools

The audit works without any additional tools installed, but you'll get much higher quality results with them.

### Quick Installation

```bash
# Navigate to the audit system directory
cd .claude/skills/audit-javascript/tools

# Run the installation script
bash install-tools.sh
```

This will guide you through installing:

**Tier 1 (Essential)**:
- ✅ npm (usually pre-installed)
- ✅ Node.js (usually pre-installed)

**Tier 2 (Recommended)**:
- Semgrep (security patterns)
- Snyk (vulnerability scanning)
- ESLint (code quality)
- Trivy (container/IaC scanning)

**Note**: The system gracefully handles missing tools. If a tool isn't installed, it continues with what's available.

### Manual Installation

```bash
# Semgrep
pip3 install semgrep

# Snyk
npm install -g snyk
snyk auth  # Authenticate (free account required)

# ESLint (if not already in your project)
npm install -g eslint

# Trivy (macOS)
brew install aquasecurity/trivy/trivy

# Trivy (Linux)
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

---

## Running Your First Audit

### Step 1: Ensure You're in the Target Repository

```bash
# Verify you're in a JavaScript/TypeScript project
ls package.json  # Should exist

# Open in Claude Code
code .
```

### Step 2: Run the Audit Skill

In Claude Code, type:

```
/audit-javascript
```

### Step 3: Wait for Completion

The audit runs through 6 stages:

1. **Stage 1** (~2-5 min): Generating architecture artifacts
2. **Stage 2** (~5-10 min): Running 4 parallel independent analyses
3. **Stage 3** (~2-5 min): Executing static analysis tools
4. **Stage 4** (~2-4 min): Reconciling findings
5. **Stage 5** (~2-4 min): Adversarial challenge
6. **Stage 6** (~1-2 min): Generating top 10 and deliverables

**Total Time**: 15-30 minutes for typical projects

### Step 4: Review Your Results

After completion, you'll find these files in your repository:

#### Executive Deliverables (Repository Root)

```
your-repo/
├── ANALYSIS-REPORT.md           # 📊 Top 10 prioritized improvements
├── ARCHITECTURE-OVERVIEW.md     # 🏗️ System architecture documentation
├── FINDINGS-DETAILED.json       # 📋 Complete structured data
└── CONFIDENCE-MATRIX.md         # ✅ Evidence transparency matrix
```

#### Detailed Stage Outputs (`.analysis/` Directory)

```
your-repo/.analysis/
├── stage1-artifacts/           # Architecture diagrams and docs
├── stage2-parallel-analysis/   # 4 independent agent analyses
├── stage3-static-analysis/     # Unified tool results
├── stage4-reconciliation/      # Merged findings with confidence scores
├── stage5-adversarial/         # False positive elimination results
└── stage6-final-synthesis/     # Prioritization matrix and patterns
```

**Start Here**: Open `ANALYSIS-REPORT.md` to see your top 10 prioritized improvements.

---

## Understanding Your Results

### Confidence Levels

Every finding includes a confidence level based on evidence convergence:

- **High Confidence** ⭐⭐⭐: Found by multiple agents AND static tools
  - Example: 2+ agents + 2+ tools identified it
  - These are your highest-priority, most reliable findings

- **Medium Confidence** ⭐⭐: Found by multiple sources in one category
  - Example: 3 agents found it, but no tools did
  - Still valuable, but may need human verification

- **Low Confidence** ⭐: Found by single source only
  - Example: Only one agent or one tool identified it
  - May be false positives or edge cases

### Severity Classifications

- **Critical** 🔴: Security vulnerabilities, data loss risks, system-breaking bugs
- **High** 🟠: Performance issues, significant tech debt, scalability blockers
- **Medium** 🟡: Code quality issues, maintainability concerns, minor bugs
- **Low** 🟢: Style inconsistencies, documentation gaps, nice-to-haves

### Prioritization

The top 10 is ranked by:

```
Priority Score = (Severity × 0.4) + (Confidence × 0.3) + (Effort-to-Value × 0.3)
```

This means high-severity, high-confidence, quick-win items appear first.

---

## What If Tools Are Missing?

**Don't worry!** The audit system is designed to work gracefully with whatever tools are available.

### Without Any Tools

- ✅ All 4 specialist agents still run
- ✅ Architecture analysis still happens
- ✅ You still get findings
- ⚠️ Confidence scores will be lower (agent-only, no tool validation)
- ⚠️ May miss some issues that tools would catch

### With Minimal Tools (npm only)

- ✅ npm audit runs (dependency vulnerabilities)
- ✅ Agent analyses run
- ✅ Some convergence validation
- ⚠️ Missing specialized security patterns (Semgrep)
- ⚠️ Missing dataflow analysis (Snyk)

### With All Tools Installed

- ✅ Maximum confidence scores
- ✅ 8 different static analysis perspectives
- ✅ Overlap detection shows convergence
- ✅ Highest-quality findings
- ✅ Fewest false positives

**Recommendation**: Start without tools to see the system work, then gradually add tools for better results.

---

## Troubleshooting

### "Skill not found" or "/audit-javascript doesn't work"

**Cause**: The `.claude/` directory isn't in your current repository.

**Fix**:
```bash
# Verify .claude exists
ls -la .claude

# If missing, copy it:
cp -r /path/to/ai-codebase-audit/.claude .
```

### "Permission denied" errors

**Cause**: Claude Code permissions may be too restrictive.

**Fix**: Check `.claude/settings.json` permissions section. The default permissions allow:
- Reading all files except secrets (.env, .key, .pem)
- Writing to `.analysis/` and deliverable files
- Running git, npm, node, and analysis tools

### "Agent produced empty output"

**Cause**: The agent may have hit context limits or permission issues.

**Fix**:
1. Check `.analysis/stage{N}/metadata.json` for error messages
2. Verify the repository has a `package.json` (must be JavaScript/TypeScript project)
3. Try running on a smaller repository first

### "Low convergence scores"

**Cause**: This is often normal! It means findings are specialized to one domain.

**Fix**: This isn't necessarily a problem. Low convergence doesn't mean findings are wrong, just that they're specific. Review `.analysis/stage4-reconciliation/agent-only-findings.md` for context.

### "Tools failed to run"

**Cause**: Tools may not be installed or not configured properly.

**Fix**:
1. Check `.analysis/stage3-static-analysis/metadata.json` for tool status
2. Install missing tools using `install-tools.sh`
3. The system will continue with available tools - this is by design

### "Results don't match my expectations"

**Cause**: Prioritization formula may not align with your priorities.

**Fix**: Review `.analysis/stage6-final-synthesis/prioritization-matrix.json` to see all candidates ranked. You can adjust weights and re-run Stage 6.

---

## Advanced Usage

### Reviewing Stage-by-Stage Outputs

After each stage, you can review intermediate outputs:

**After Stage 1**: Verify architecture understanding
```bash
cat .analysis/stage1-artifacts/architecture-overview.md
```

**After Stage 2**: See what agents independently found
```bash
cat .analysis/stage2-parallel-analysis/convergence-preview.md
```

**After Stage 3**: Check which tools ran
```bash
cat .analysis/stage3-static-analysis/tool-comparison.md
```

**After Stage 4**: See high-confidence findings
```bash
cat .analysis/stage4-reconciliation/convergence-analysis.md
```

**After Stage 5**: See what was dismissed as false positives
```bash
cat .analysis/stage5-adversarial/false-positives-identified.md
```

### Customizing the Audit

**Adjust Prioritization Weights**: Edit `.claude/skills/audit-javascript/SKILL.md` Stage 6 section (lines 395-420)

**Add Custom Static Tools**: Create a runner script in `.claude/skills/audit-javascript/tools/` following the pattern of existing runners

**Modify Output Formats**: Edit agent definitions in `.claude/agents/*.md` to change JSON schemas or markdown templates

---

## Cleaning Up After Audit

### Keep Results, Remove Audit System

If you want to commit the results but not the audit system:

```bash
# Keep deliverables, remove audit system
rm -rf .claude

# Keep the 4 main deliverables:
# - ANALYSIS-REPORT.md
# - ARCHITECTURE-OVERVIEW.md
# - FINDINGS-DETAILED.json
# - CONFIDENCE-MATRIX.md

# Optionally keep .analysis/ for detailed review
```

### Remove Everything

```bash
# Remove all audit outputs
rm -rf .claude .analysis ANALYSIS-REPORT.md ARCHITECTURE-OVERVIEW.md FINDINGS-DETAILED.json CONFIDENCE-MATRIX.md
```

### Add to .gitignore

If you want to run audits regularly but not commit results:

```bash
# Add to your .gitignore
echo ".analysis/" >> .gitignore
echo "ANALYSIS-REPORT.md" >> .gitignore
echo "ARCHITECTURE-OVERVIEW.md" >> .gitignore
echo "FINDINGS-DETAILED.json" >> .gitignore
echo "CONFIDENCE-MATRIX.md" >> .gitignore
```

---

## Next Steps

1. **Run your first audit** on a small JavaScript/TypeScript project
2. **Review the top 10** in ANALYSIS-REPORT.md
3. **Install static tools** for better results (optional)
4. **Run again** to see how convergence scores improve
5. **Fix high-priority findings** and re-audit to measure improvement

---

## Getting Help

### Documentation

- **Full README**: See `README.md` for complete documentation
- **Deliverables Guide**: See `docs/deliverables-guide.md` for output format reference
- **Architecture Decisions**: See `ARCHITECTURE-DECISIONS.md` for design rationale
- **Implementation Status**: See `IMPLEMENTATION-STATUS.md` for current capabilities

### Common Questions

**Q: Can I run this on non-JavaScript projects?**
A: Not yet. Java and .NET support are planned but not implemented.

**Q: How much does it cost?**
A: The audit system is free. Static tools like Snyk may require free accounts.

**Q: Can I customize the top 10 count?**
A: Currently it's fixed at 10. Future versions will support customization.

**Q: Will this modify my code?**
A: No! The audit is read-only. It only generates analysis reports.

**Q: Can I run this in CI/CD?**
A: Not yet, but it's a planned feature. Currently requires interactive Claude Code.

---

## Summary: The Fastest Way to Get Started

```bash
# 1. Copy the audit system
cd /path/to/your/project
cp -r /path/to/ai-codebase-audit/.claude .

# 2. Open in Claude Code
code .

# 3. Run the audit (in Claude Code)
# All three stacks are now available:
/audit-javascript  # For JavaScript/TypeScript
/audit-java        # For Java/Spring Boot
/audit-dotnet      # For .NET/ASP.NET Core

# 4. Wait 15-30 minutes

# 5. Review results
open ANALYSIS-REPORT.md
```

**That's it!** You now have a comprehensive analysis of your codebase with prioritized improvements.

**Current Status**: JavaScript/TypeScript, Java, and .NET are all fully implemented and production-ready!

---

**Questions?** See the troubleshooting section above or review the full documentation in README.md.
