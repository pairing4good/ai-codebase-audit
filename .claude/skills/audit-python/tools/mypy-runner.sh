#!/usr/bin/env bash
# mypy runner for Python type checking
# Usage: ./mypy-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-mypy-report.json}"

echo "Running mypy type checker on: $SOURCE_DIR"

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

# Create temporary file for JSON output
TEMP_FILE=$(mktemp)

# Run mypy
# --ignore-missing-imports: Don't fail on missing type stubs
# --show-error-codes: Include error codes
# --no-error-summary: Cleaner output
$PYTHON_CMD -m mypy \
  --ignore-missing-imports \
  --show-error-codes \
  --no-error-summary \
  --no-color-output \
  $PYTHON_FILES \
  > "$TEMP_FILE" 2>&1 || true

# Convert mypy output to JSON format
$PYTHON_CMD -c "
import json
import re
import sys

results = []
with open('$TEMP_FILE', 'r') as f:
    for line in f:
        # Parse mypy output format: file.py:line: error: message [error-code]
        match = re.match(r'^(.+?):(\d+):\s*(error|warning|note):\s*(.+?)(?:\s+\[(.+?)\])?$', line.strip())
        if match:
            file_path, line_num, severity, message, error_code = match.groups()
            results.append({
                'file': file_path,
                'line': int(line_num),
                'severity': severity,
                'message': message.strip(),
                'error_code': error_code or 'unknown'
            })

with open('$OUTPUT_FILE', 'w') as f:
    json.dump(results, f, indent=2)

print(f'Converted {len(results)} mypy findings to JSON')
" 2>/dev/null || echo "[]" > "$OUTPUT_FILE"

rm -f "$TEMP_FILE"

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ mypy scan complete: $OUTPUT_FILE"
  ISSUES=$($PYTHON_CMD -c "import json; data=json.load(open('$OUTPUT_FILE')); print(len(data))" 2>/dev/null || echo "0")
  echo "   Found $ISSUES type issues"
else
  echo "⚠️ mypy did not produce output file"
  echo "[]" > "$OUTPUT_FILE"
fi
