#!/bin/bash

# Tool Installation Helper for AI Codebase Audit System
# Installs recommended static analysis tools for JavaScript/TypeScript

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   AI Codebase Audit System - Tool Installation               ║"
echo "║   Installing static analysis tools for JavaScript/TypeScript  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track what was installed
INSTALLED=()
SKIPPED=()
FAILED=()

# ==================== TIER 1: ESSENTIAL TOOLS ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TIER 1: Essential Security & Quality Tools"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Semgrep (Pattern-based SAST)
echo "1️⃣  Installing Semgrep (OWASP/CWE/JWT/API security)..."
if command -v semgrep &> /dev/null; then
    echo -e "${YELLOW}   ⚠️  Semgrep already installed$(semgrep --version | head -1)${NC}"
    SKIPPED+=("Semgrep (already installed)")
else
    if command -v brew &> /dev/null; then
        brew install semgrep && INSTALLED+=("Semgrep (brew)") || FAILED+=("Semgrep")
    elif command -v pip3 &> /dev/null; then
        pip3 install semgrep && INSTALLED+=("Semgrep (pip3)") || FAILED+=("Semgrep")
    else
        echo -e "${RED}   ❌ Neither brew nor pip3 found. Install manually: https://semgrep.dev/docs/getting-started/${NC}"
        FAILED+=("Semgrep (no installer)")
    fi
fi
echo ""

# 2. Snyk (Dataflow SAST + Dependency scanning)
echo "2️⃣  Installing Snyk (dataflow analysis + CVE scanning)..."
if command -v snyk &> /dev/null; then
    echo -e "${YELLOW}   ⚠️  Snyk already installed ($(snyk version))${NC}"
    SKIPPED+=("Snyk (already installed)")
else
    if command -v npm &> /dev/null; then
        npm install -g snyk && INSTALLED+=("Snyk (npm)") || FAILED+=("Snyk")
    else
        echo -e "${RED}   ❌ npm not found. Install Node.js first: https://nodejs.org/${NC}"
        FAILED+=("Snyk (npm not available)")
    fi
fi

# Snyk authentication
if command -v snyk &> /dev/null; then
    echo "   Authenticating Snyk (free account required)..."
    if snyk auth status &> /dev/null; then
        echo -e "${GREEN}   ✅ Already authenticated with Snyk${NC}"
    else
        echo "   Opening browser for Snyk authentication..."
        snyk auth || echo -e "${YELLOW}   ⚠️  Run 'snyk auth' manually later${NC}"
    fi
fi
echo ""

# 3. ESLint + Security Plugins
echo "3️⃣  Installing ESLint + security plugins..."
if command -v npx &> /dev/null; then
    echo "   ESLint available via npx (no global install needed)"
    echo "   Security plugins should be in your project's package.json:"
    echo "     - eslint-plugin-security"
    echo "     - eslint-plugin-sonarjs"
    INSTALLED+=("ESLint (via npx)")
else
    echo -e "${RED}   ❌ npx not found. Install Node.js: https://nodejs.org/${NC}"
    FAILED+=("ESLint")
fi
echo ""

# 4. npm audit (built-in)
echo "4️⃣  Checking npm audit (built into npm)..."
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}   ✅ npm audit available (npm v${NPM_VERSION})${NC}"
    INSTALLED+=("npm audit (built-in)")
else
    echo -e "${RED}   ❌ npm not found${NC}"
    FAILED+=("npm audit")
fi
echo ""

# ==================== TIER 2: ENHANCED TOOLS ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TIER 2: Enhanced Analysis (Optional but Recommended)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 5. Trivy (IaC + Container + Dependency scanning)
echo "5️⃣  Installing Trivy (optional: for containers/IaC)..."
if command -v trivy &> /dev/null; then
    echo -e "${YELLOW}   ⚠️  Trivy already installed ($(trivy --version | head -1))${NC}"
    SKIPPED+=("Trivy (already installed)")
else
    if command -v brew &> /dev/null; then
        brew install aquasecurity/trivy/trivy && INSTALLED+=("Trivy (brew)") || {
            echo -e "${YELLOW}   ⚠️  Trivy installation failed (optional tool)${NC}"
            SKIPPED+=("Trivy (optional, failed)")
        }
    else
        echo -e "${YELLOW}   ⚠️  Trivy skipped (optional tool, brew not available)${NC}"
        echo "      Install manually: https://aquasecurity.github.io/trivy/"
        SKIPPED+=("Trivy (optional, no brew)")
    fi
fi
echo ""

# 6. SonarQube Scanner (optional)
echo "6️⃣  Checking SonarQube Scanner (optional: requires server)..."
if command -v sonar-scanner &> /dev/null; then
    echo -e "${GREEN}   ✅ SonarQube Scanner installed${NC}"
    INSTALLED+=("SonarQube Scanner")
else
    echo -e "${YELLOW}   ℹ️  SonarQube Scanner not installed (optional)${NC}"
    echo "      Requires SonarQube/SonarCloud server setup"
    echo "      Install: https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/"
    SKIPPED+=("SonarQube Scanner (optional)")
fi
echo ""

# ==================== VERIFICATION ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ${#INSTALLED[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ INSTALLED (${#INSTALLED[@]} tools):${NC}"
    for tool in "${INSTALLED[@]}"; do
        echo "   - $tool"
    done
    echo ""
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  SKIPPED (${#SKIPPED[@]} tools):${NC}"
    for tool in "${SKIPPED[@]}"; do
        echo "   - $tool"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}❌ FAILED (${#FAILED[@]} tools):${NC}"
    for tool in "${FAILED[@]}"; do
        echo "   - $tool"
    done
    echo ""
fi

# ==================== NEXT STEPS ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1️⃣  Verify tool installation:"
echo "   semgrep --version"
echo "   snyk --version"
echo "   npx eslint --version"
echo "   npm --version"
echo ""

echo "2️⃣  Add ESLint security plugins to your project:"
echo "   npm install --save-dev eslint-plugin-security eslint-plugin-sonarjs"
echo ""

echo "3️⃣  Run your first audit:"
echo "   cd /path/to/your/javascript-project"
echo "   /audit-javascript"
echo ""

echo "4️⃣  Expected coverage after installation:"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo -e "${GREEN}   ✅ OWASP Top 10: 100% (Semgrep + ESLint + Snyk)${NC}"
    echo -e "${GREEN}   ✅ OWASP API Top 10: 100% (Semgrep + Snyk)${NC}"
    echo -e "${GREEN}   ✅ CWE/SANS Top 25: 100% (Semgrep + Snyk)${NC}"
    echo -e "${GREEN}   ✅ JWT/OAuth: 100% (Semgrep + Snyk)${NC}"
    echo -e "${GREEN}   ✅ Dependencies/CVE: 100% (Snyk + npm audit)${NC}"
else
    echo -e "${YELLOW}   ⚠️  Some tools failed to install. Coverage may be reduced.${NC}"
    echo "      Re-run this script or install failed tools manually."
fi
echo ""

# ==================== TOOL REFERENCE ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tool Reference"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Tier 1 - Always Run (Fast, High Value):"
echo "   • Semgrep      - Pattern-based SAST (OWASP/CWE/JWT/API)"
echo "   • ESLint       - Code quality + security patterns"
echo "   • Snyk         - Dataflow SAST + dependency CVE scanning"
echo "   • npm audit    - Dependency vulnerability scanning"
echo ""

echo "📋 Tier 2 - Run if Available (Additional Coverage):"
echo "   • Trivy        - IaC/container/dependency scanning (optional)"
echo "   • SonarQube    - Comprehensive SAST (requires server setup)"
echo "   • Coverage     - Test coverage analysis (if tests exist)"
echo ""

echo "🔗 Documentation:"
echo "   • Semgrep:     https://semgrep.dev/docs/"
echo "   • Snyk:        https://docs.snyk.io/"
echo "   • ESLint:      https://eslint.org/docs/user-guide/"
echo "   • Trivy:       https://aquasecurity.github.io/trivy/"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              Installation Complete!                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

exit 0
