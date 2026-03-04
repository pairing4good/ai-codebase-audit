---
name: audit-java
description: "Performs comprehensive 6-stage audit of Java codebases with maximum accuracy using independent agents and static analysis (OWASP Top 10, CWE/SANS 25, Spring Security)"
user-invokable: true
---

# Java Codebase Audit - Executable Orchestration

You are orchestrating a complete 6-stage analytical funnel to produce the top 10 highest-priority improvements for this Java codebase.

## Your Mission

Execute all 7 stages sequentially (Stage 0 is NEW - build validation), using specialized agents at each stage. Track progress with TodoWrite and present evaluation checkpoints to the user after key stages.

**IMPORTANT**: You MUST actually execute this audit, not just describe what would happen. Use the Task tool to invoke agents, Bash tool to run commands, and Write tool to create outputs.

---

## Stage 0: Build Validation (CRITICAL - MANDATORY)

**Objective**: Ensure Java/JDK is installed and the project compiles before analysis. **DO NOT PROCEED** without a successful build.

### Your Actions

1. Create todo tracking with all 7 stages (including Stage 0)

2. Mark Stage 0 as in_progress

3. **Check for Java/JDK** (MANDATORY - STOP IF MISSING):

```bash
if ! command -v java >/dev/null 2>&1; then
  echo "❌ ERROR: Java (JDK) is not installed!"
  echo ""
  echo "Java/JDK is required to:"
  echo "  - Build the project (validate it compiles)"
  echo "  - Run SpotBugs, PMD, Checkstyle (bytecode analysis)"
  echo "  - Execute Maven/Gradle build tools"
  echo "  - Ensure accurate analysis of Java code"
  echo ""
  echo "Please install Java JDK 11+ (recommend JDK 17 or 21):"
  echo "  • macOS: brew install openjdk@17"
  echo "  • Linux (Ubuntu): sudo apt install openjdk-17-jdk"
  echo "  • Linux (RHEL): sudo yum install java-17-openjdk-devel"
  echo "  • Windows: https://adoptium.net/"
  echo ""
  echo "After installation, verify with: java -version"
  echo ""
  echo "⛔ Audit cannot proceed without Java/JDK."
  exit 1
fi
```

4. Verify Java version:

```bash
echo "✅ Java detected: $(java -version 2>&1 | head -1)"
```

5. Detect build tool (STOP IF MISSING):

```bash
# Check which build tool is present
if [ -f "pom.xml" ]; then
  if ! command -v mvn >/dev/null 2>&1; then
    echo "❌ ERROR: Maven project detected (pom.xml) but mvn is not installed!"
    echo ""
    echo "Install Maven:"
    echo "  • macOS: brew install maven"
    echo "  • Linux: sudo apt install maven"
    echo "  • Windows: https://maven.apache.org/download.cgi"
    echo ""
    echo "⛔ Audit cannot proceed without Maven."
    exit 1
  fi
  echo "✅ Maven project detected: pom.xml"
  BUILD_TOOL="maven"
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  if [ ! -f "./gradlew" ]; then
    if ! command -v gradle >/dev/null 2>&1; then
      echo "❌ ERROR: Gradle project detected but ./gradlew wrapper not found and gradle not in PATH!"
      echo ""
      echo "Install Gradle:"
      echo "  • macOS: brew install gradle"
      echo "  • Linux: sudo apt install gradle"
      echo "  • Windows: https://gradle.org/install/"
      echo ""
      echo "⛔ Audit cannot proceed without Gradle."
      exit 1
    fi
  fi
  echo "✅ Gradle project detected: build.gradle"
  BUILD_TOOL="gradle"
else
  echo "❌ ERROR: No Java build files found!"
  echo "Expected to find: pom.xml (Maven) or build.gradle (Gradle)"
  echo "Is this a Java project? Change to the project directory and try again."
  exit 1
fi
```

6. Run build with compilation (skip tests for speed):

```bash
echo "Building project to verify it compiles..."

if [ "$BUILD_TOOL" = "maven" ]; then
  mvn clean compile -DskipTests -q
  BUILD_STATUS=$?
elif [ "$BUILD_TOOL" = "gradle" ]; then
  if [ -f "./gradlew" ]; then
    ./gradlew clean compileJava compileTestJava --no-daemon --quiet
  else
    gradle clean compileJava compileTestJava --no-daemon --quiet
  fi
  BUILD_STATUS=$?
fi
```

7. Check build status (STOP IF FAILED):

```bash
if [ $BUILD_STATUS -ne 0 ]; then
  echo ""
  echo "❌ ERROR: Project does not compile!"
  echo ""
  echo "Build errors must be fixed before running the audit."
  echo "Reasons:"
  echo "  - SpotBugs analyzes .class files (requires compilation)"
  echo "  - PMD benefits from resolved classpaths"
  echo "  - Cannot analyze code that doesn't build"
  echo ""
  echo "To see detailed build errors, run:"
  if [ "$BUILD_TOOL" = "maven" ]; then
    echo "  mvn compile"
  else
    echo "  ./gradlew compileJava"
  fi
  echo ""
  echo "⛔ Audit cannot proceed with build failures."
  exit 1
fi
```

8. Extract classpath for tools (used by SpotBugs, PMD):

```bash
mkdir -p "$PROJECT_ROOT/.analysis/java"

if [ "$BUILD_TOOL" = "maven" ]; then
  mvn dependency:build-classpath -Dmdep.outputFile="$PROJECT_ROOT/.analysis/java/classpath.txt" -q
elif [ "$BUILD_TOOL" = "gradle" ]; then
  if [ -f "./gradlew" ]; then
    ./gradlew dependencies --configuration compileClasspath > "$PROJECT_ROOT/.analysis/java/gradle-dependencies.txt"
  else
    gradle dependencies --configuration compileClasspath > "$PROJECT_ROOT/.analysis/java/gradle-dependencies.txt"
  fi
fi
```

9. Inform user:
```
✅ Build successful! Java classes compiled.
📦 Build tool: [Maven/Gradle]
📂 Compiled output ready for static analysis tools.
```

10. Mark Stage 0 as completed

**CRITICAL**: If any of steps 3, 5, or 7 fail, **STOP IMMEDIATELY** and inform the user. Do NOT proceed to Stage 1.

**Why this matters**:
- SpotBugs analyzes .class files, not .java files
- PMD benefits from resolved classpaths
- SonarQube requires successful compilation
- Prevents wasting time analyzing code that doesn't compile

---

## Stage 1: Architecture Artifact Generation

**Objective**: Build comprehensive mental model of the Java application before analysis.

### Your Actions

1. Determine project root and create the directory structure:
```bash
# Find git repository root, or use current directory if not a git repo
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
else
  PROJECT_ROOT=$(pwd)
fi

mkdir -p "$PROJECT_ROOT/.analysis/java/stage1-artifacts"
```

2. Mark Stage 1 as in_progress

3. Detect Java framework and architecture:

```bash
# Check for Spring Boot
if grep -q "spring-boot" pom.xml build.gradle 2>/dev/null; then
  echo "Spring Boot application detected"
fi

# Check for Jakarta EE / Java EE
if grep -q "jakarta.ee\|javax.enterprise" pom.xml build.gradle 2>/dev/null; then
  echo "Jakarta EE application detected"
fi

# Check for database access
if grep -q "hibernate\|spring-data\|jpa" pom.xml build.gradle 2>/dev/null; then
  echo "JPA/Hibernate detected"
fi
```

4. Invoke the `artifact-generator` agent using the Task tool with subagent_type="artifact-generator":

**Prompt for artifact-generator**:
```
You are generating architecture artifacts for this Java codebase.

IMPORTANT: This is a JAVA project. Focus on Java-specific patterns:
- Spring Framework architecture (if detected)
- Layered architecture: Controllers → Services → Repositories → Entities
- REST API endpoints (look for @RestController, @GetMapping, @PostMapping)
- Database access patterns (JPA @Entity, @Repository)
- Exception handling architecture (@ControllerAdvice, custom exceptions)
- Security configuration (Spring Security, @Secured, @PreAuthorize)

Your task:
1. Analyze the repository structure comprehensively
2. Generate ALL required artifacts in $PROJECT_ROOT/.analysis/java/stage1-artifacts/:
   - architecture-overview.md (system purpose, tech stack, Spring Boot vs Jakarta EE, architecture layers)
   - component-dependency.mermaid (module/package dependency graph)
   - data-flow-diagrams/ directory with flows for:
     * Authentication flow (Spring Security if present)
     * Business operation flows (REST API → Service → Repository → Database)
   - sequence-diagrams/ directory for critical paths:
     * Request handling (HTTP → Controller → Service → Repository)
     * Transaction management (if @Transactional detected)
   - entity-relationship.mermaid (JPA entity relationships, @OneToMany, @ManyToOne)
   - tech-debt-surface-map.md (high churn files, cyclomatic complexity hotspots, TODO/FIXME debt)
   - metadata.json (statistics: file counts, LOC, dependencies count, Java version)

Java-specific items to include:
- Identify all @RestController and @Controller classes (these are API endpoints)
- Map @Service classes (business logic layer)
- Map @Repository classes (data access layer)
- Identify @Entity classes (data model)
- Document Spring Security configuration (if present)
- List database connections (DataSource configuration)
- Identify async processing (@Async, ExecutorService)
- Document scheduled tasks (@Scheduled)

Follow the complete process outlined in your agent definition (.claude/agents/artifact-generator.md).

Output all files to $PROJECT_ROOT/.analysis/java/stage1-artifacts/
```

5. After the agent completes, read `$PROJECT_ROOT/.analysis/java/stage1-artifacts/architecture-overview.md` and present a summary to the user

6. Mark Stage 1 as completed

---

## Stage 2: Parallel Independent Analysis

**Objective**: Four specialist agents analyze in complete isolation (no cross-contamination).

### Your Actions

1. Create directory:
```bash
mkdir -p "$PROJECT_ROOT/.analysis/java/stage2-parallel-analysis"
```

2. Mark Stage 2 as in_progress

3. **Launch all 4 agents IN PARALLEL** using a single message with 4 Task tool calls:

**CRITICAL**: You MUST send all 4 Task invocations in a SINGLE message to run them in parallel. Do NOT run them sequentially.

**Agent 1: architecture-analyzer**
```
You are analyzing this Java codebase for architectural issues.

IMPORTANT: This is a JAVA project. Focus on Java-specific architectural patterns.

CRITICAL: Use PROJECT_ROOT for all paths. Determine it with:
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

Read Stage 1 artifacts from $PROJECT_ROOT/.analysis/java/stage1-artifacts/ for context.

Analyze for Java-specific issues:
- **Spring Framework patterns**: Proper use of @Autowired, @Component, @Service, @Repository
- **Layered architecture violations**: Controllers calling Repositories directly (should go through Services)
- **RESTful API design**: Proper HTTP methods, proper use of @PathVariable vs @RequestParam
- **Dependency injection**: Constructor injection vs field injection (prefer constructor)
- **Transaction boundaries**: @Transactional on service methods, not controllers or repositories
- **Exception handling**: Proper use of @ControllerAdvice for global exception handling
- **Concurrency patterns**: Thread-safety of @Singleton beans, proper use of synchronized
- **JPA patterns**: N+1 query problems, proper use of FetchType.LAZY, @EntityGraph
- **Microservices patterns** (if Spring Cloud detected): Circuit breakers, service discovery
- **Security architecture**: Spring Security configuration, JWT token handling, OAuth2 setup

Common Java architectural anti-patterns to detect:
- God classes (>500 lines, >20 methods)
- Anemic domain model (entities with no behavior, all logic in services)
- Circular dependencies between packages
- Tight coupling to frameworks
- Missing abstraction layers
- Business logic in controllers

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/java/stage2-parallel-analysis/architecture-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/architecture-analyzer.md).
```

**Agent 2: security-analyzer**
```
You are analyzing this Java codebase for security vulnerabilities.

IMPORTANT: This is a JAVA project. Focus on Java-specific security issues.

CRITICAL: Use PROJECT_ROOT for all paths. Determine it with:
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

Read Stage 1 artifacts from $PROJECT_ROOT/.analysis/java/stage1-artifacts/ for context.

Analyze for Java-specific OWASP Top 10 vulnerabilities:
1. **SQL Injection**:
   - String concatenation in JDBC queries or JPQL
   - Missing parameterized queries
   - Example: "SELECT * FROM users WHERE id = " + userId (VULNERABLE)

2. **XML External Entity (XXE)**:
   - Unsafe XML parsing (DocumentBuilderFactory without secure features)
   - Look for: XMLInputFactory, SAXParser without XXE protection

3. **Insecure Deserialization**:
   - Use of ObjectInputStream without validation
   - Java serialization without SerialVersionUID
   - Accepting serialized objects from untrusted sources

4. **Authentication and Authorization Flaws**:
   - Spring Security misconfigurations
   - Missing @PreAuthorize or @Secured annotations
   - Weak password policies in UserDetailsService
   - JWT tokens without signature verification
   - OAuth2 misconfiguration

5. **Sensitive Data Exposure**:
   - Passwords or API keys in source code
   - Logging sensitive data (passwords, tokens, SSNs)
   - Missing encryption for data at rest
   - Weak cryptography (DES, MD5 instead of AES, SHA-256)

6. **Security Misconfiguration**:
   - Spring Security with .permitAll() on sensitive endpoints
   - CORS misconfiguration (overly permissive origins)
   - Missing CSRF protection
   - Debug mode enabled in production

7. **Cross-Site Scripting (XSS)**:
   - Unescaped data in JSP/Thymeleaf templates
   - Missing @ResponseBody or produces="application/json"

8. **Server-Side Request Forgery (SSRF)**:
   - User-controlled URLs in URL.openConnection()
   - Missing URL validation in HTTP clients

9. **Path Traversal**:
   - File operations with user input: new File(userInput)
   - Missing validation for file paths

10. **LDAP Injection**:
    - User input in LDAP queries without escaping

JWT/OAuth2 specific checks:
- JWT tokens stored in localStorage (should be httpOnly cookies)
- Missing token expiration validation
- Weak JWT signing algorithms (HS256 with weak secret)
- OAuth2 redirect_uri validation missing

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/java/stage2-parallel-analysis/security-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/security-analyzer.md).
```

**Agent 3: maintainability-analyzer**
```
You are analyzing this Java codebase for code quality and technical debt.

IMPORTANT: This is a JAVA project. Focus on Java-specific code quality issues.

CRITICAL: Use PROJECT_ROOT for all paths. Determine it with:
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

Read Stage 1 artifacts from $PROJECT_ROOT/.analysis/java/stage1-artifacts/ for context.

Analyze for Java-specific code quality issues:
- **Cyclomatic complexity**: Methods with >10 decision points
- **Method length**: Methods >50 lines (should be refactored)
- **Class size**: Classes >500 lines (God classes)
- **Code duplication**: Copy-pasted code blocks
- **Magic numbers**: Hardcoded values (should be constants)
- **Proper use of Optional<T>**: Avoid .get() without .isPresent()
- **Stream API anti-patterns**:
  - Nested streams (hard to read)
  - Side effects in lambda expressions
  - Using .forEach() when .map() or .filter() is better
- **Exception handling**:
  - Empty catch blocks (swallowing exceptions)
  - Catching Exception instead of specific exceptions
  - Rethrowing exceptions without adding context
- **Null checks**: Missing null validation, NPE risks
- **Test coverage**: JUnit test presence, coverage %
- **Logging practices**:
  - Using System.out.println instead of logger
  - Logging at wrong levels (DEBUG vs INFO vs ERROR)
  - String concatenation in log messages (should use SLF4J {})
- **Resource management**: Missing try-with-resources for Closeable
- **Naming conventions**: Non-descriptive variable names (x, temp, data)
- **Comments**: Outdated comments, TODO/FIXME debt
- **Deprecated API usage**: Using deprecated Java or Spring methods

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/java/stage2-parallel-analysis/maintainability-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/maintainability-analyzer.md).
```

**Agent 4: dependency-analyzer**
```
You are analyzing this Java codebase for dependency and supply chain issues.

IMPORTANT: This is a JAVA project. Analyze Maven or Gradle dependencies.

Read pom.xml or build.gradle/build.gradle.kts.

Analyze for Java-specific dependency issues:
- **Outdated dependencies**:
  - Old Spring Boot versions (check against latest)
  - Old Spring Framework versions
  - Old Java version (Java 8 is outdated, recommend Java 17+)
- **Known CVEs**:
  - Log4j vulnerabilities (CVE-2021-44228, CVE-2021-45046)
  - Spring Framework CVEs
  - Jackson databind vulnerabilities
  - Apache Commons vulnerabilities
- **Dependency conflicts**:
  - Multiple versions of same library (transitive conflicts)
  - Incompatible dependency versions
- **Unused dependencies**:
  - Dependencies declared but not used in code
- **Missing dependencies**:
  - Code using classes not declared in pom.xml/build.gradle
- **Scope issues**:
  - Runtime dependencies declared as compile
  - Test dependencies missing test scope
- **License compliance**:
  - GPL/LGPL dependencies in commercial applications
  - Incompatible license combinations
- **Transitive dependency risks**:
  - Large dependency trees (>50 transitive deps per library)
  - Circular dependency chains

Supply chain security:
- Check for dependencies from untrusted repositories
- Look for SNAPSHOT versions in production builds
- Verify dependency signatures (if available)

You have NO ACCESS to other agents' outputs. Operate completely independently.

Output your findings to: $PROJECT_ROOT/.analysis/java/stage2-parallel-analysis/dependency-analysis.json

Use the exact JSON schema defined in your agent definition (.claude/agents/dependency-analyzer.md).
```

4. After ALL agents complete, read all 4 JSON outputs

5. Generate a convergence preview by identifying findings that appear in multiple agent outputs:
   - Group findings by file:line location
   - Count how many agents flagged each location
   - Write `$PROJECT_ROOT/.analysis/java/stage2-parallel-analysis/convergence-preview.md` showing multi-agent findings
   - Write `$PROJECT_ROOT/.analysis/java/stage2-parallel-analysis/metadata.json` with counts

6. Present convergence preview to user showing high-confidence findings

7. Mark Stage 2 as completed

---

## Stage 3: Static Analysis Tools

**Objective**: Run Java-specific static analysis tools for objective validation.

### Your Actions

1. Create directory:
```bash
mkdir -p "$PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs"
```

2. Mark Stage 3 as in_progress

3. Verify static analysis tools are available:
```bash
echo "Verifying static analysis tools..."
echo "✓ Semgrep: $(semgrep --version 2>&1 | head -1)"
echo "✓ Snyk: $(snyk --version 2>&1)"
echo "✓ Trivy: $(trivy --version 2>&1 | head -1)"
echo ""
echo "Note: All tools are pre-installed in the Docker container."
echo "If running outside Docker, ensure tools are installed manually."
```

4. Run static analysis tools:

**Tool 1: Semgrep** (OWASP Top 10, CWE/SANS 25, JWT/OAuth)
```bash
if command -v semgrep >/dev/null 2>&1; then
  echo "Running Semgrep with Java OWASP/CWE/JWT rulesets..."
  bash .claude/skills/audit-java/tools/semgrep-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs/semgrep-report.json
else
  echo "⚠️ Semgrep not installed (optional but recommended)"
fi
```

**Tool 2: SpotBugs + Find Security Bugs** (OWASP Top 10, CWE)
```bash
if command -v mvn >/dev/null 2>&1 || command -v gradle >/dev/null 2>&1; then
  echo "Running SpotBugs with Find Security Bugs plugin..."
  bash .claude/skills/audit-java/tools/spotbugs-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs/spotbugs-report.xml
else
  echo "⚠️ Maven or Gradle not found for SpotBugs"
fi
```

**Tool 3: PMD** (Code quality, complexity)
```bash
if command -v mvn >/dev/null 2>&1 || command -v gradle >/dev/null 2>&1; then
  echo "Running PMD for code quality analysis..."
  bash .claude/skills/audit-java/tools/pmd-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs/pmd-report.xml
else
  echo "⚠️ Maven or Gradle not found for PMD"
fi
```

**Tool 4: Checkstyle** (Code style, consistency)
```bash
if command -v mvn >/dev/null 2>&1 || command -v gradle >/dev/null 2>&1; then
  echo "Running Checkstyle..."
  bash .claude/skills/audit-java/tools/checkstyle-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs/checkstyle-report.xml
else
  echo "⚠️ Maven or Gradle not found for Checkstyle"
fi
```

**Tool 5: Snyk** (OWASP Top 10, Deps/CVE)
```bash
if command -v snyk >/dev/null 2>&1; then
  echo "Running Snyk Code and Open Source analysis..."
  bash .claude/skills/audit-java/tools/snyk-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs
else
  echo "⚠️ Snyk not installed (optional but recommended for CVE detection)"
fi
```

**Tool 6: OWASP Dependency-Check** (CVE scanning)
```bash
if command -v dependency-check >/dev/null 2>&1; then
  echo "Running OWASP Dependency-Check..."
  bash .claude/skills/audit-java/tools/dependency-check-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs/dependency-check-report.json
else
  echo "⚠️ OWASP Dependency-Check not installed (optional)"
fi
```

**Tool 7: Trivy** (Container/IaC/12-Factor)
```bash
if command -v trivy >/dev/null 2>&1; then
  echo "Running Trivy for container and IaC scanning..."
  bash .claude/skills/audit-java/tools/trivy-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs/trivy-report.json
else
  echo "⚠️ Trivy not installed (optional)"
fi
```

**Tool 8: SonarQube** (if configured)
```bash
if [ -f "sonar-project.properties" ] && command -v sonar-scanner >/dev/null 2>&1; then
  echo "Running SonarQube Scanner..."
  bash .claude/skills/audit-java/tools/sonarqube-runner.sh . $PROJECT_ROOT/.analysis/java/stage3-static-analysis/raw-outputs/sonarqube-report.json
else
  echo "⚠️ SonarQube not configured (optional)"
fi
```

5. Unify results using format-static-results.js:
```bash
node .claude/skills/audit-java/tools/format-static-results.js $PROJECT_ROOT/.analysis/java/stage3-static-analysis
```

This creates:
- `$PROJECT_ROOT/.analysis/java/stage3-static-analysis/unified-results.json` (normalized format)
- `$PROJECT_ROOT/.analysis/java/stage3-static-analysis/tool-comparison.md` (which tools found what)
- `$PROJECT_ROOT/.analysis/java/stage3-static-analysis/overlap-analysis.json` (convergence across tools)

6. Read `tool-comparison.md` and present summary to user

7. Write `$PROJECT_ROOT/.analysis/java/stage3-static-analysis/metadata.json` with tool execution status

8. Mark Stage 3 as completed

---

## Stage 4: Reconciliation

**Objective**: Synthesize findings from all sources with statistical confidence scoring.

### Your Actions

1. Create directory:
```bash
mkdir -p "$PROJECT_ROOT/.analysis/java/stage4-reconciliation"
```

2. Mark Stage 4 as in_progress

3. Invoke the `reconciliation-agent` using Task tool with subagent_type="reconciliation-agent":

**Prompt for reconciliation-agent**:
```
You are synthesizing findings from multiple independent sources for a JAVA codebase.

You have NEVER analyzed this codebase before. You are coming to this fresh with no prior analytical bias.

Your inputs:
- Stage 1 artifacts: $PROJECT_ROOT/.analysis/java/stage1-artifacts/ (Java architecture context)
- Stage 2 agent outputs: $PROJECT_ROOT/.analysis/java/stage2-parallel-analysis/*.json (4 independent analyses)
- Stage 3 static analysis: $PROJECT_ROOT/.analysis/java/stage3-static-analysis/unified-results.json (Java tool findings)

Your task:
1. Read ALL inputs
2. Index findings by location (file:line)
3. Perform convergence analysis (which findings appear across multiple sources?)
4. Calculate confidence scores using the formula in your agent definition
5. Identify contradictions (agent vs tool disagreements)
6. Generate merged longlist with evidence tracking

Output to $PROJECT_ROOT/.analysis/java/stage4-reconciliation/:
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
mkdir -p "$PROJECT_ROOT/.analysis/java/stage5-adversarial"
```

2. Mark Stage 5 as in_progress

3. Invoke the `adversarial-agent` using Task tool with subagent_type="adversarial-agent":

**Prompt for adversarial-agent**:
```
You are challenging reconciled findings from a JAVA codebase to eliminate false positives.

You have NEVER been involved in this audit before. You are the independent skeptic.

Your input:
- Reconciled findings: $PROJECT_ROOT/.analysis/java/stage4-reconciliation/reconciled-longlist.json

Your task:
Attack each finding using the 5-point challenge framework:
1. Is this actually a problem? (false positive detection)
2. Is severity overstated? (inflation detection)
3. Is evidence valid? (verification)
4. Is this intentional design? (context understanding)
5. Does this matter in context? (priority assessment)

Java-specific false positive patterns to watch for:
- Test code misidentified as production code
- Framework "magic" (Spring auto-configuration, Lombok-generated code)
- Intentional design patterns (singleton beans, factory patterns)
- Generated code (JPA metamodel classes, Swagger generated APIs)
- Overridden framework methods (intentional null returns, empty implementations)

For each finding, issue one of three verdicts:
- UPHELD: Finding is valid as stated
- DOWNGRADED: Valid but severity overstated (adjust severity)
- DISMISSED: False positive (remove from consideration)

Expected metrics:
- Upheld: 70-85%
- Downgraded: 10-20%
- Dismissed: 5-15%

Output to $PROJECT_ROOT/.analysis/java/stage5-adversarial/:
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
mkdir -p "$PROJECT_ROOT/.analysis/java/stage6-final-synthesis"
```

2. Mark Stage 6 as in_progress

3. Read `$PROJECT_ROOT/.analysis/java/stage5-adversarial/challenged-findings.json`

4. Filter to UPHELD findings only (exclude DISMISSED)

5. Apply prioritization formula to rank findings:

**Prioritization Formula** (Java-specific weighting):
```
priority_score = (severity_weight × severity_score) +
                 (confidence_weight × confidence_score) +
                 (effort_to_value_weight × effort_value_score) +
                 (java_security_bonus)

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

Java Security Bonus (add +0.5 to priority_score):
- SQL Injection vulnerabilities
- XXE vulnerabilities
- Insecure deserialization
- Spring Security misconfigurations
- JWT/OAuth2 authentication flaws
```

6. Sort by priority_score descending and select top 10

7. Write Stage 6 outputs:
   - `$PROJECT_ROOT/.analysis/java/stage6-final-synthesis/prioritization-matrix.json` (all findings with scores)
   - `$PROJECT_ROOT/.analysis/java/stage6-final-synthesis/top-10-detailed.json` (top 10 with full details)
   - `$PROJECT_ROOT/.analysis/java/stage6-final-synthesis/honorable-mentions.md` (findings 11-20)
   - `$PROJECT_ROOT/.analysis/java/stage6-final-synthesis/quick-wins.md` (low effort, high impact items)
   - `$PROJECT_ROOT/.analysis/java/stage6-final-synthesis/systemic-patterns.md` (recurring Java issues)
   - `$PROJECT_ROOT/.analysis/java/stage6-final-synthesis/metadata.json` (statistics)

8. Create the final report directory and generate the 4 executive deliverables:

```bash
mkdir -p "$PROJECT_ROOT/.analysis/java/final-report"
```

**ANALYSIS-REPORT.md**:
```markdown
# Java Codebase Analysis Report

*Generated: [DATE] | Overall Confidence: [High/Medium] | [X] findings analyzed → Top 10 selected*

## Executive Summary

[1-2 paragraph overview: what was analyzed, methodology (6-stage funnel), key findings summary, overall codebase health assessment for Java application]

## Methodology

This audit used a 6-stage analytical funnel with independent agents and static analysis:

1. **Build Validation**: Ensured project compiles (Maven/Gradle)
2. **Artifact Generation**: Architecture mapping and tech debt surface analysis
3. **Parallel Independent Analysis**: 4 specialist agents (architecture, security, maintainability, dependency) operating in isolation
4. **Static Analysis**: Java-specific tools (Semgrep, SpotBugs, PMD, Checkstyle, Snyk, OWASP Dependency-Check)
5. **Reconciliation**: Statistical convergence analysis across all sources
6. **Adversarial Challenge**: Independent skeptic eliminated false positives
7. **Final Synthesis**: Evidence-based prioritization

**Confidence Principle**: Findings that converged across multiple independent agents AND static tools receive "High" confidence.

## Top 10 Improvements

[For each finding 1-10:]

### [#]. [Critical/High/Medium] [Title]

**Location**: [src/main/java/com/example/Service.java:42-56] (clickable link)
**Confidence**: [High/Medium/Low] (converged: [list agent names] + [list tool names])
**Priority Score**: [X.XX]
**Effort**: [Low/Medium/High]
**Impact**: [Critical/High/Medium/Low]

**Problem**:
[Clear description of what's wrong with Java-specific context]

**Evidence**:
- Identified by agents: [architecture-analyzer, security-analyzer]
- Identified by tools: [Semgrep (owasp/java/sql-injection), SpotBugs (SQL_INJECTION_JDBC)]
- Convergence score: [0.85] (high confidence - multiple independent sources)

**Code Example**:
```java
// src/main/java/com/example/UserService.java:156-162
public List<User> getUsersByRole(String role) {
    String query = "SELECT * FROM users WHERE role = '" + role + "'";  // VULNERABLE
    Statement stmt = connection.createStatement();
    ResultSet rs = stmt.executeQuery(query);
    return mapResultSet(rs);
}
```

**Impact**:
[Business/technical impact - why this matters for Java/Spring applications]
- Allows SQL injection attacks via role parameter
- Entire user database could be compromised
- Violates OWASP Top 10 (A03:2021 - Injection)
- CWE-89: SQL Injection vulnerability

**Recommendation**:
Use PreparedStatement for all database queries:

```java
// Fixed version:
public List<User> getUsersByRole(String role) {
    String query = "SELECT * FROM users WHERE role = ?";
    PreparedStatement pstmt = connection.prepareStatement(query);
    pstmt.setString(1, role);  // Parameterized query prevents injection
    ResultSet rs = pstmt.executeQuery();
    return mapResultSet(rs);
}
```

**Survived Adversarial Challenge**: Yes - Confirmed as genuine SQL injection risk, not a false positive. Both pattern-based (Semgrep) and bytecode-based (SpotBugs) tools identified it independently.

---

[Repeat for all 10 findings - EACH MUST INCLUDE actual code snippets from the codebase]

## Summary Statistics

- **Total Findings Analyzed**: [X]
- **High Confidence**: [X] findings (converged across agents + tools)
- **Medium Confidence**: [X] findings
- **Low Confidence**: [X] findings
- **False Positives Dismissed**: [X] findings
- **Severity Adjustments**: [X] findings downgraded

## Java-Specific Insights

**Most Common Issues**:
1. SQL Injection (JPQL string concatenation): [X] instances
2. Missing @Transactional boundaries: [X] instances
3. Thread-safety issues in @Singleton beans: [X] instances
4. N+1 query problems in JPA: [X] instances

## What Makes These Recommendations Trustworthy

1. **Independent Analysis**: 4 specialist agents analyzed separately (no confirmation bias)
2. **Tool Validation**: 7-8 Java-specific static analysis tools provided objective verification
3. **Convergence Scoring**: Findings appearing across multiple sources scored higher
4. **Adversarial Challenge**: Independent skeptic eliminated [X] false positives
5. **Evidence Transparency**: Every finding shows which agents/tools identified it AND includes actual code snippets

## Next Steps

1. Review this report and prioritize which findings to address first
2. See `$PROJECT_ROOT/.analysis/java/final-report/FINDINGS-DETAILED.json` for complete structured data
3. See `$PROJECT_ROOT/.analysis/java/final-report/CONFIDENCE-MATRIX.md` for evidence transparency matrix
4. See `$PROJECT_ROOT/.analysis/java/` directory for complete stage-by-stage outputs
5. Consider running `/audit-java` again after fixes to measure improvement

## Full Details

All stage-by-stage outputs available in `$PROJECT_ROOT/.analysis/java/`:
- Stage 0: Build validation logs
- Stage 1: Architecture artifacts
- Stage 2: 4 independent agent analyses
- Stage 3: Static analysis tool results (Semgrep, SpotBugs, PMD, Checkstyle, Snyk, Dependency-Check, Trivy)
- Stage 4: Reconciliation and convergence analysis
- Stage 5: Adversarial challenge results
- Stage 6: Prioritization matrix and patterns
```

9. **Create ARCHITECTURE-OVERVIEW.md**:
```bash
cp "$PROJECT_ROOT/.analysis/java/stage1-artifacts/architecture-overview.md" "$PROJECT_ROOT/.analysis/java/final-report/ARCHITECTURE-OVERVIEW.md"
```

10. **Create FINDINGS-DETAILED.json**: Export all upheld findings with complete structure (must include `example` field with `file`, `line_start`, `line_end`, and `code` for each finding)

11. **Create CONFIDENCE-MATRIX.md**: Generate evidence transparency table showing which agents/tools found each finding

Example format:
```markdown
# Confidence Matrix

| Finding | Location | security-analyzer | architecture-analyzer | maintainability-analyzer | dependency-analyzer | Semgrep | SpotBugs | PMD | Snyk | Confidence |
|---------|----------|-------------------|----------------------|-------------------------|---------------------|---------|----------|-----|------|------------|
| SQL Injection | UserService.java:156 | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | High (3 sources) |
...
```

12. Present final summary to user:
```
## Analysis Complete! 🎯

**Executive Deliverables** (in $PROJECT_ROOT/.analysis/java/final-report/):
- ANALYSIS-REPORT.md - Top 10 with detailed recommendations
- ARCHITECTURE-OVERVIEW.md - Java system architecture documentation
- FINDINGS-DETAILED.json - Complete structured data
- CONFIDENCE-MATRIX.md - Evidence transparency matrix

**Summary**:
- [X] total findings analyzed
- Top 10 selected via evidence-based prioritization
- [X] critical, [X] high, [X] medium severity in top 10
- Average confidence: [High/Medium] ([X]% convergence rate)
- [X] false positives eliminated

**Java-Specific Findings**:
- Spring Security issues: [X]
- SQL Injection risks: [X]
- Concurrency problems: [X]
- JPA performance issues: [X]

**Next Step**: Review `$PROJECT_ROOT/.analysis/java/final-report/ANALYSIS-REPORT.md` for your prioritized improvements.
```

13. Mark Stage 6 as completed

---

## Error Handling

**If Stage 0 fails** (any of these):
- ❌ Java/JDK not installed → **STOP** - Provide installation instructions, do NOT proceed
- ❌ Maven/Gradle not installed → **STOP** - Provide installation instructions, do NOT proceed
- ❌ No build files found → **STOP** - Verify this is a Java project
- ❌ Build fails → **STOP** - Instruct user to fix build errors first

**DO NOT**:
- Proceed with "partial analysis" when build fails
- Try to analyze without Java/JDK or build tools
- Suggest workarounds to skip build validation

**ALWAYS**:
- Stop immediately when Stage 0 validation fails
- Provide clear installation/fix instructions
- Wait for user to resolve the issue before proceeding

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
7. **Include clickable file:line references** in all outputs (format: `src/main/java/com/example/Service.java:42`)
8. **Be thorough** - This is a comprehensive audit, not a quick scan
9. **Java-specific focus** - Prioritize Spring Security, SQL injection, XXE, concurrency issues

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
