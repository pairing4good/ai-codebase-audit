#!/usr/bin/env bash
# Pylint runner for Python code quality analysis
# Usage: ./pylint-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-pylint-report.json}"

echo "Running Pylint code quality analysis on: $SOURCE_DIR"

# Determine Python command
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
else
  PYTHON_CMD="python"
fi

# Find all Python files
PYTHON_FILES=$(find "$SOURCE_DIR" -name "*.py" \
  -not -path "*/venv/*" \
  -not -path "*/.venv/*" \
  -not -path "*/env/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/migrations/*" \
  -not -path "*/build/*" \
  -not -path "*/dist/*" \
  2>/dev/null || true)

if [ -z "$PYTHON_FILES" ]; then
  echo "⚠️ No Python files found in $SOURCE_DIR"
  echo "[]" > "$OUTPUT_FILE"
  exit 0
fi

# Run Pylint
# --output-format=json: JSON output
# --disable=R,C: Disable refactoring and convention messages (focus on errors/warnings)
# --exit-zero: Don't fail on issues
$PYTHON_CMD -m pylint \
  --output-format=json \
  --exit-zero \
  --disable=C,R \
  --max-line-length=120 \
  $PYTHON_FILES \
  > "$OUTPUT_FILE" 2>&1 || true

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Pylint scan complete: $OUTPUT_FILE"
  # Show summary
  ISSUES=$($PYTHON_CMD -c "import json; data=json.load(open('$OUTPUT_FILE')) if open('$OUTPUT_FILE').read().strip() else []; print(len(data))" 2>/dev/null || echo "0")
  echo "   Found $ISSUES code quality issues"
else
  echo "⚠️ Pylint did not produce output file"
  echo "[]" > "$OUTPUT_FILE"
fi
