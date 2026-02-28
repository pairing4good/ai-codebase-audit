#!/bin/bash

# Semgrep Runner for JavaScript/TypeScript
# Runs Semgrep with OWASP Top 10, CWE Top 25, JWT, and API Security rulesets

set -e

OUTPUT_DIR="${1:-.analysis/stage3-static-analysis/raw-outputs}"
PROJECT_DIR="${2:-.}"

echo "🔍 Running Semgrep security analysis..."
echo "   Output: $OUTPUT_DIR/semgrep.json"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if semgrep is installed
if ! command -v semgrep &> /dev/null; then
    echo "❌ Semgrep not found. Install with: pip3 install semgrep"
    echo "   Or: brew install semgrep"
    exit 1
fi

# Detect language
LANG_FLAG="--lang=javascript"
if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
    LANG_FLAG="--lang=typescript"
    echo "   Detected: TypeScript project"
else
    echo "   Detected: JavaScript project"
fi

# Run Semgrep with multiple rulesets
# Using --config= multiple times to load all rulesets
echo "   Loading rulesets:"
echo "     - OWASP Top 10"
echo "     - CWE Top 25"
echo "     - JWT Security"
echo "     - OWASP API Security"
echo "     - Security Audit (general)"

semgrep \
    --config=p/owasp-top-ten \
    --config=p/cwe-top-25 \
    --config=p/jwt \
    --config=p/owasp-api-security \
    --config=p/security-audit \
    --json \
    --output="$OUTPUT_DIR/semgrep.json" \
    --quiet \
    --max-memory=4000 \
    --timeout=300 \
    --skip-unknown-extensions \
    "$PROJECT_DIR" \
    2>&1 | tee "$OUTPUT_DIR/semgrep.log" || {
        echo "⚠️  Semgrep completed with warnings (check semgrep.log)"
        # Don't exit on Semgrep warnings - findings still generated
    }

# Check if output was generated
if [ -f "$OUTPUT_DIR/semgrep.json" ]; then
    FINDING_COUNT=$(jq '.results | length' "$OUTPUT_DIR/semgrep.json" 2>/dev/null || echo "0")
    echo "✅ Semgrep complete: $FINDING_COUNT findings"

    # Show severity breakdown
    if [ "$FINDING_COUNT" -gt 0 ]; then
        echo "   Severity breakdown:"
        jq -r '.results | group_by(.extra.severity) | map({severity: .[0].extra.severity, count: length}) | .[] | "     - \(.severity): \(.count)"' "$OUTPUT_DIR/semgrep.json" 2>/dev/null || true
    fi
else
    echo "❌ Semgrep output not generated"
    exit 1
fi

echo ""
