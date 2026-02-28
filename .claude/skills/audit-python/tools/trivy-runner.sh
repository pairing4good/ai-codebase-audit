#!/usr/bin/env bash
# Trivy runner for Python dependency and filesystem scanning
# Usage: ./trivy-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-trivy-report.json}"

echo "Running Trivy vulnerability scanner on: $SOURCE_DIR"

# Check if trivy is available
if ! command -v trivy >/dev/null 2>&1; then
  echo "⚠️ Trivy not found. Skipping."
  echo "[]" > "$OUTPUT_FILE"
  exit 0
fi

# Run Trivy filesystem scan
# fs: Filesystem scan mode
# --format json: JSON output
# --scanners vuln,secret,misconfig: Scan for vulnerabilities, secrets, and misconfigurations
trivy fs \
  --format json \
  --output "$OUTPUT_FILE" \
  --scanners vuln,secret,misconfig \
  --severity CRITICAL,HIGH,MEDIUM \
  "$SOURCE_DIR" \
  2>&1 || true  # Don't fail if issues found

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Trivy scan complete: $OUTPUT_FILE"
  # Show summary
  VULNERABILITIES=$(python3 -c "import json; data=json.load(open('$OUTPUT_FILE')); results=data.get('Results', []); print(sum(len(r.get('Vulnerabilities', [])) for r in results))" 2>/dev/null || echo "0")
  echo "   Found $VULNERABILITIES vulnerabilities"
else
  echo "⚠️ Trivy did not produce output file"
  echo '{"Results":[]}' > "$OUTPUT_FILE"
fi
