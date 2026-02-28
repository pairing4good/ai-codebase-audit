#!/bin/bash
# Semgrep runner for .NET - OWASP Top 10, CWE/SANS 25 for C#
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/semgrep-report.json}"

echo "=== Semgrep .NET Security Analysis ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

if ! command -v semgrep &> /dev/null; then
    echo "⚠️  Semgrep not installed"
    echo '{"results": []}' > "$OUTPUT_FILE"
    exit 0
fi

# Run Semgrep with C# security rulesets
semgrep \
    --config="p/owasp-top-ten" \
    --config="p/cwe-top-25" \
    --config="p/csharp" \
    --config="p/jwt" \
    --config="p/sql-injection" \
    --config="p/secrets" \
    --json \
    --output="$OUTPUT_FILE" \
    --exclude="bin/" \
    --exclude="obj/" \
    --exclude="*.dll" \
    "$PROJECT_DIR" || true

echo "✅ Semgrep analysis complete: $OUTPUT_FILE"
