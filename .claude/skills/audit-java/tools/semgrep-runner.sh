#!/bin/bash
# Semgrep runner for Java - OWASP Top 10, CWE/SANS 25, JWT/OAuth security
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/semgrep-report.json}"

echo "=== Semgrep Java Security Analysis ==="

# Check if semgrep is installed
if ! command -v semgrep &> /dev/null; then
    echo "ERROR: Semgrep is not installed"
    echo "Install with: pip3 install semgrep"
    exit 1
fi

# Detect Java source files
JAVA_FILES=$(find "$PROJECT_DIR" -name "*.java" -type f | grep -v "/target/" | grep -v "/build/" | wc -l | tr -d ' ')
echo "Found $JAVA_FILES Java files to analyze"

if [ "$JAVA_FILES" -eq 0 ]; then
    echo "No Java files found. Skipping Semgrep."
    echo '{"results": [], "errors": [], "paths": {"scanned": []}}' > "$OUTPUT_FILE"
    exit 0
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Run Semgrep with multiple Java security rulesets
echo "Running Semgrep with Java OWASP/CWE/JWT/API rulesets..."

semgrep \
    --config="p/owasp-top-ten" \
    --config="p/cwe-top-25" \
    --config="p/java" \
    --config="p/jwt" \
    --config="p/spring" \
    --config="p/sql-injection" \
    --config="p/secrets" \
    --json \
    --output="$OUTPUT_FILE" \
    --exclude="target/" \
    --exclude="build/" \
    --exclude="*.class" \
    --exclude="*.jar" \
    "$PROJECT_DIR" || true

# Check if output was created
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "ERROR: Semgrep did not produce output"
    exit 1
fi

# Count findings
TOTAL_FINDINGS=$(jq '.results | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
CRITICAL=$(jq '[.results[] | select(.extra.severity == "ERROR")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
HIGH=$(jq '[.results[] | select(.extra.severity == "WARNING")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
MEDIUM=$(jq '[.results[] | select(.extra.severity == "INFO")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")

echo "✅ Semgrep analysis complete"
echo "   Total findings: $TOTAL_FINDINGS"
echo "   Critical/High: $CRITICAL"
echo "   Medium/High: $HIGH"
echo "   Info: $MEDIUM"
echo "   Output: $OUTPUT_FILE"
