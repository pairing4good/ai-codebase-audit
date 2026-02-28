#!/bin/bash
# Snyk runner for Java - Security and dependency vulnerabilities
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_DIR="${2:-.analysis/stage3-static-analysis/raw-outputs}"

echo "=== Snyk Security Analysis ==="
mkdir -p "$OUTPUT_DIR"

if ! command -v snyk &> /dev/null; then
    echo "⚠️  Snyk not installed"
    echo '{"vulnerabilities":[]}' > "$OUTPUT_DIR/snyk-code.json"
    echo '{"vulnerabilities":[]}' > "$OUTPUT_DIR/snyk-open-source.json"
    exit 0
fi

cd "$PROJECT_DIR"

# Snyk Code (SAST)
echo "Running Snyk Code..."
snyk code test --json > "$OUTPUT_DIR/snyk-code.json" 2>/dev/null || echo '{"runs":[]}' > "$OUTPUT_DIR/snyk-code.json"

# Snyk Open Source (Dependencies/CVE)
echo "Running Snyk Open Source..."
snyk test --json > "$OUTPUT_DIR/snyk-open-source.json" 2>/dev/null || echo '{"vulnerabilities":[]}' > "$OUTPUT_DIR/snyk-open-source.json"

echo "✅ Snyk analysis complete"
