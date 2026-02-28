#!/usr/bin/env bash
# Bandit runner for Python security analysis
# Usage: ./bandit-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-bandit-report.json}"

echo "Running Bandit security scanner on: $SOURCE_DIR"

# Determine Python command
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
else
  PYTHON_CMD="python"
fi

# Run Bandit
# -r: recursive
# -f json: JSON output format
# -ll: report only medium severity and higher
# -x: exclude virtual environments and common non-project dirs
$PYTHON_CMD -m bandit \
  -r "$SOURCE_DIR" \
  -f json \
  -o "$OUTPUT_FILE" \
  -ll \
  --exclude "*/venv/*,*/.venv/*,*/env/*,*/virtualenv/*,*/__pycache__/*,*/migrations/*,*/tests/*" \
  2>&1 || true  # Don't fail if issues found

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Bandit scan complete: $OUTPUT_FILE"
  # Show summary
  ISSUES=$($PYTHON_CMD -c "import json; data=json.load(open('$OUTPUT_FILE')); print(len(data.get('results', [])))")
  echo "   Found $ISSUES security issues"
else
  echo "⚠️ Bandit did not produce output file"
fi
