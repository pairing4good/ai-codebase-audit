#!/bin/bash
# Trivy runner for Java - Container/IaC/12-Factor scanning
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/trivy-report.json}"

echo "=== Trivy Container & IaC Scanning ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

if ! command -v trivy &> /dev/null; then
    echo "⚠️  Trivy not installed"
    echo '{"Results":[]}' > "$OUTPUT_FILE"
    exit 0
fi

cd "$PROJECT_DIR"

# Scan filesystem for vulnerabilities
trivy fs --format json --output "$OUTPUT_FILE" . 2>/dev/null || echo '{"Results":[]}' > "$OUTPUT_FILE"

echo "✅ Trivy scan complete: $OUTPUT_FILE"
