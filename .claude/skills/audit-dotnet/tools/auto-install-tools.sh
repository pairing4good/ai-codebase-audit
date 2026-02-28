#!/bin/bash

# Tool Auto-Installation for AI Codebase Audit System
# Installs static analysis tools for .NET/C#/F# automatically

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   AI Codebase Audit System - Tool Auto-Installation          ║"
echo "║   Installing static analysis tools for .NET/C#/F#             ║"
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

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}❌ .NET SDK not installed. Please install .NET 6 or higher.${NC}"
    echo "   Download from: https://dotnet.microsoft.com/download"
    exit 1
fi

DOTNET_VERSION=$(dotnet --version 2>&1)
echo -e "${GREEN}✅ .NET SDK $DOTNET_VERSION detected${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Required for result formatting.${NC}"
    echo "   Install from: https://nodejs.org/"
    exit 1
fi
echo -e "${GREEN}✅ Node.js detected${NC}"
echo ""

# ==================== TIER 1: ESSENTIAL TOOLS ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TIER 1: Essential Security & Quality Tools"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Semgrep
echo "1️⃣  Installing Semgrep (OWASP/CWE for C#)..."
if command -v semgrep &> /dev/null; then
    echo -e "${YELLOW}   ⚠️  Semgrep already installed: $(semgrep --version | head -1)${NC}"
    SKIPPED+=("Semgrep (already installed)")
else
    if command -v brew &> /dev/null; then
        echo "   Installing via Homebrew..."
        brew install semgrep --quiet 2>&1 | tail -3 && INSTALLED+=("Semgrep (brew)") || FAILED+=("Semgrep")
    elif command -v pip3 &> /dev/null; then
        echo "   Installing via pip3..."
        pip3 install --user semgrep --quiet 2>&1 | tail -3
        export PATH="$HOME/.local/bin:$HOME/Library/Python/3.*/bin:$PATH"
        if command -v semgrep &> /dev/null; then
            INSTALLED+=("Semgrep (pip3)")
        else
            echo -e "${YELLOW}   ⚠️  Installed but not in PATH. Add: export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
            SKIPPED+=("Semgrep (PATH issue)")
        fi
    else
        echo -e "${RED}   ❌ Neither brew nor pip3 found${NC}"
        FAILED+=("Semgrep (no installer)")
    fi
fi
echo ""

# 2. Snyk
echo "2️⃣  Installing Snyk (dataflow SAST + NuGet CVE scanning)..."
if command -v snyk &> /dev/null; then
    echo -e "${YELLOW}   ⚠️  Snyk already installed: $(snyk --version 2>&1)${NC}"
    SKIPPED+=("Snyk (already installed)")
else
    if command -v npm &> /dev/null; then
        echo "   Installing via npm (global)..."
        npm install -g snyk --silent 2>&1 | tail -3 && INSTALLED+=("Snyk (npm)") || FAILED+=("Snyk")
    else
        echo -e "${RED}   ❌ npm not found${NC}"
        FAILED+=("Snyk (npm required)")
    fi
fi

# Snyk authentication
if command -v snyk &> /dev/null; then
    echo "   Checking Snyk authentication..."
    if snyk auth status &> /dev/null; then
        echo -e "${GREEN}   ✅ Already authenticated${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Not authenticated. Run 'snyk auth' later (free account required)${NC}"
    fi
fi
echo ""

# 3. Roslyn Analyzers + Security Code Scan (NuGet packages)
echo "3️⃣  Checking Roslyn Analyzers & Security Code Scan (NuGet)..."
if ls *.csproj >/dev/null 2>&1 || ls *.fsproj >/dev/null 2>&1; then
    echo -e "${GREEN}   ✅ .NET project detected - analyzers will run during build${NC}"
    INSTALLED+=("Roslyn/Security Code Scan (NuGet)")
else
    echo -e "${YELLOW}   ⚠️  No .csproj or .fsproj found${NC}"
    SKIPPED+=("Roslyn/Security Code Scan (no project)")
fi
echo ""

# 4. dotnet-outdated
echo "4️⃣  Installing dotnet-outdated (dependency version checking)..."
if command -v dotnet-outdated &> /dev/null; then
    echo -e "${YELLOW}   ⚠️  Already installed${NC}"
    SKIPPED+=("dotnet-outdated (already installed)")
else
    echo "   Installing as .NET global tool..."
    dotnet tool install --global dotnet-outdated-tool --quiet 2>&1 | tail -3 && INSTALLED+=("dotnet-outdated") || {
        echo -e "${YELLOW}   ⚠️  Installation failed (optional tool)${NC}"
        SKIPPED+=("dotnet-outdated (optional, failed)")
    }
fi
echo ""

# ==================== TIER 2: ENHANCED TOOLS ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TIER 2: Enhanced Analysis (Optional but Recommended)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 5. Trivy
echo "5️⃣  Installing Trivy (container/IaC scanning)..."
if command -v trivy &> /dev/null; then
    echo -e "${YELLOW}   ⚠️  Trivy already installed: $(trivy --version | head -1)${NC}"
    SKIPPED+=("Trivy (already installed)")
else
    if command -v brew &> /dev/null; then
        echo "   Installing via Homebrew..."
        brew install aquasecurity/trivy/trivy --quiet 2>&1 | tail -3 && INSTALLED+=("Trivy (brew)") || {
            echo -e "${YELLOW}   ⚠️  Optional tool - installation failed${NC}"
            SKIPPED+=("Trivy (optional, failed)")
        }
    else
        echo -e "${YELLOW}   ⚠️  Trivy skipped (optional, requires Homebrew)${NC}"
        SKIPPED+=("Trivy (optional)")
    fi
fi
echo ""

# 6. SonarQube Scanner
echo "6️⃣  Checking SonarQube Scanner (optional: requires server)..."
if command -v sonar-scanner &> /dev/null; then
    echo -e "${GREEN}   ✅ Already installed${NC}"
    INSTALLED+=("SonarQube Scanner")
else
    echo -e "${YELLOW}   ℹ️  Not installed (optional - requires SonarQube/SonarCloud server)${NC}"
    SKIPPED+=("SonarQube Scanner (optional)")
fi
echo ""

# ==================== SUMMARY ====================

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
    echo -e "${YELLOW}⚠️  SKIPPED (${#SKIPPED[@]} items):${NC}"
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

# Calculate coverage
TOOL_COUNT=$((${#INSTALLED[@]} - ${#FAILED[@]}))
if [ $TOOL_COUNT -ge 5 ]; then
    echo -e "${GREEN}✅ Excellent! Comprehensive tool coverage for .NET audit.${NC}"
elif [ $TOOL_COUNT -ge 3 ]; then
    echo -e "${GREEN}✅ Good! Sufficient tools for quality analysis.${NC}"
elif [ $TOOL_COUNT -ge 2 ]; then
    echo -e "${YELLOW}⚠️  Basic coverage. Consider installing more tools.${NC}"
else
    echo -e "${RED}❌ Limited coverage. Install at least Semgrep and Snyk.${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting Stage 3 static analysis with available tools..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
