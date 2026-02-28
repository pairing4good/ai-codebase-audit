#!/usr/bin/env bash
# Auto-install Python static analysis tools
# This script attempts to install missing tools automatically

set -e

echo "=== Python Static Analysis Tools Auto-Installer ==="
echo ""

# Determine Python and pip commands
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
  PIP_CMD="pip3"
else
  PYTHON_CMD="python"
  PIP_CMD="pip"
fi

echo "Using: $PYTHON_CMD and $PIP_CMD"
echo ""

# Function to check if a Python package is installed
check_package() {
  $PIP_CMD list 2>/dev/null | grep -i "^$1 " >/dev/null
}

# Function to install a Python package
install_package() {
  local package=$1
  local name=$2
  echo "Installing $name..."
  $PIP_CMD install "$package" --quiet 2>&1 | tail -5 || echo "⚠️ Failed to install $name"
}

# Tool 1: Bandit (Python security scanner)
echo "1. Checking Bandit (security scanner)..."
if check_package "bandit"; then
  echo "   ✅ Bandit already installed"
else
  install_package "bandit[toml]" "Bandit"
fi
echo ""

# Tool 2: Pylint (code quality)
echo "2. Checking Pylint (code quality)..."
if check_package "pylint"; then
  echo "   ✅ Pylint already installed"
else
  install_package "pylint" "Pylint"
fi
echo ""

# Tool 3: mypy (type checking)
echo "3. Checking mypy (type checker)..."
if check_package "mypy"; then
  echo "   ✅ mypy already installed"
else
  install_package "mypy" "mypy"
fi
echo ""

# Tool 4: Safety (dependency CVE scanner)
echo "4. Checking Safety (dependency vulnerabilities)..."
if check_package "safety"; then
  echo "   ✅ Safety already installed"
else
  install_package "safety" "Safety"
fi
echo ""

# Tool 5: Radon (complexity metrics)
echo "5. Checking Radon (complexity metrics)..."
if check_package "radon"; then
  echo "   ✅ Radon already installed"
else
  install_package "radon" "Radon"
fi
echo ""

# Tool 6: Semgrep (pattern-based scanner - system-wide)
echo "6. Checking Semgrep (OWASP/CWE patterns)..."
if command -v semgrep >/dev/null 2>&1; then
  echo "   ✅ Semgrep already installed"
else
  echo "   ⚠️ Semgrep not installed. Install via:"
  echo "      pip install semgrep  OR"
  echo "      brew install semgrep (macOS)  OR"
  echo "      https://semgrep.dev/docs/getting-started/"
fi
echo ""

# Tool 7: Snyk (commercial SAST + SCA)
echo "7. Checking Snyk (SAST + dependency scanner)..."
if command -v snyk >/dev/null 2>&1; then
  echo "   ✅ Snyk already installed"
else
  echo "   ⚠️ Snyk not installed. Install via:"
  echo "      npm install -g snyk  OR"
  echo "      brew install snyk (macOS)  OR"
  echo "      https://docs.snyk.io/snyk-cli/install-the-snyk-cli"
  echo "   Note: Requires authentication (snyk auth)"
fi
echo ""

# Tool 8: Trivy (container/dependency scanner)
echo "8. Checking Trivy (container/dependency scanner)..."
if command -v trivy >/dev/null 2>&1; then
  echo "   ✅ Trivy already installed"
else
  echo "   ⚠️ Trivy not installed. Install via:"
  echo "      brew install aquasecurity/trivy/trivy (macOS)  OR"
  echo "      https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
fi
echo ""

echo "=== Installation Summary ==="
echo "Core tools (auto-installed):"
check_package "bandit" && echo "  ✅ Bandit" || echo "  ❌ Bandit"
check_package "pylint" && echo "  ✅ Pylint" || echo "  ❌ Pylint"
check_package "mypy" && echo "  ✅ mypy" || echo "  ❌ mypy"
check_package "safety" && echo "  ✅ Safety" || echo "  ❌ Safety"
check_package "radon" && echo "  ✅ Radon" || echo "  ❌ Radon"
echo ""
echo "Optional tools (manual install):"
command -v semgrep >/dev/null 2>&1 && echo "  ✅ Semgrep" || echo "  ⚠️ Semgrep (recommended)"
command -v snyk >/dev/null 2>&1 && echo "  ✅ Snyk" || echo "  ⚠️ Snyk (optional)"
command -v trivy >/dev/null 2>&1 && echo "  ✅ Trivy" || echo "  ⚠️ Trivy (optional)"
echo ""
echo "Installation complete!"
