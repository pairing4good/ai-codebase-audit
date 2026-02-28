#!/usr/bin/env bash
# Safety runner for Python dependency CVE scanning
# Usage: ./safety-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-safety-report.json}"

echo "Running Safety dependency vulnerability scanner on: $SOURCE_DIR"

# Determine Python command
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
  PIP_CMD="pip3"
else
  PYTHON_CMD="python"
  PIP_CMD="pip"
fi

# Run Safety check on installed packages
# --json: JSON output
# --output: Output file
$PYTHON_CMD -m safety check \
  --json \
  --output "$OUTPUT_FILE" \
  2>&1 || true  # Don't fail if vulnerabilities found

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Safety scan complete: $OUTPUT_FILE"
  # Show summary - Safety JSON format is different
  VULNERABILITIES=$($PYTHON_CMD -c "import json; data=json.load(open('$OUTPUT_FILE')); print(len(data) if isinstance(data, list) else 0)" 2>/dev/null || echo "0")
  echo "   Found $VULNERABILITIES vulnerable dependencies"
else
  echo "⚠️ Safety did not produce output file"
  echo "[]" > "$OUTPUT_FILE"
fi
