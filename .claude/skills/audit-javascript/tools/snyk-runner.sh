#!/bin/bash

# Snyk Runner for JavaScript/TypeScript
# Runs both Snyk Code (SAST) and Snyk Open Source (dependency scanning)

set -e

OUTPUT_DIR="${1:-.analysis/stage3-static-analysis/raw-outputs}"
PROJECT_DIR="${2:-.}"

echo "🔍 Running Snyk analysis..."
echo "   Output: $OUTPUT_DIR/snyk-code.json, $OUTPUT_DIR/snyk-open-source.json"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if snyk is installed
if ! command -v snyk &> /dev/null; then
    echo "❌ Snyk not found. Install with: npm install -g snyk"
    echo "   Then authenticate with: snyk auth"
    exit 1
fi

# Check if authenticated
if ! snyk auth status &> /dev/null; then
    echo "⚠️  Not authenticated with Snyk. Running: snyk auth"
    snyk auth
fi

cd "$PROJECT_DIR"

# 1. Snyk Open Source (Dependency Scanning)
echo ""
echo "📦 Running Snyk Open Source (dependency vulnerabilities)..."

if [ -f "package.json" ]; then
    # Install dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
        echo "   Installing dependencies first (required for Snyk)..."
        npm install --package-lock-only --quiet 2>&1 | head -5 || true
    fi

    snyk test \
        --json \
        --all-projects \
        > "$OUTPUT_DIR/snyk-open-source.json" 2>&1 || {
            # Snyk exits with code 1 if vulnerabilities found - this is expected
            if [ -f "$OUTPUT_DIR/snyk-open-source.json" ]; then
                VULN_COUNT=$(jq '.vulnerabilities | length' "$OUTPUT_DIR/snyk-open-source.json" 2>/dev/null || echo "0")
                echo "   ✅ Snyk Open Source complete: $VULN_COUNT vulnerabilities found"
            else
                echo "   ⚠️  Snyk Open Source completed with errors (check output)"
            fi
        }

    # Show severity breakdown
    if [ -f "$OUTPUT_DIR/snyk-open-source.json" ]; then
        VULN_COUNT=$(jq '.vulnerabilities | length' "$OUTPUT_DIR/snyk-open-source.json" 2>/dev/null || echo "0")
        if [ "$VULN_COUNT" -gt 0 ]; then
            echo "   Severity breakdown:"
            jq -r '.vulnerabilities | group_by(.severity) | map({severity: .[0].severity, count: length}) | .[] | "     - \(.severity): \(.count)"' "$OUTPUT_DIR/snyk-open-source.json" 2>/dev/null || true
        fi
    fi
else
    echo "   ⚠️  No package.json found, skipping Snyk Open Source"
    echo "[]" > "$OUTPUT_DIR/snyk-open-source.json"
fi

# 2. Snyk Code (SAST)
echo ""
echo "🔒 Running Snyk Code (SAST via dataflow analysis)..."

snyk code test \
    --json \
    > "$OUTPUT_DIR/snyk-code.json" 2>&1 || {
        # Snyk Code also exits with 1 if issues found
        if [ -f "$OUTPUT_DIR/snyk-code.json" ]; then
            FINDING_COUNT=$(jq '.runs[0].results | length' "$OUTPUT_DIR/snyk-code.json" 2>/dev/null || echo "0")
            echo "   ✅ Snyk Code complete: $FINDING_COUNT findings"
        else
            echo "   ⚠️  Snyk Code completed with errors (check output)"
        fi
    }

# Show severity breakdown for Snyk Code
if [ -f "$OUTPUT_DIR/snyk-code.json" ]; then
    FINDING_COUNT=$(jq '.runs[0].results | length' "$OUTPUT_DIR/snyk-code.json" 2>/dev/null || echo "0")
    if [ "$FINDING_COUNT" -gt 0 ]; then
        echo "   Severity breakdown:"
        jq -r '.runs[0].results | group_by(.level) | map({severity: .[0].level, count: length}) | .[] | "     - \(.severity): \(.count)"' "$OUTPUT_DIR/snyk-code.json" 2>/dev/null || true
    fi
fi

cd - > /dev/null

echo ""
echo "✅ Snyk analysis complete"
echo ""
