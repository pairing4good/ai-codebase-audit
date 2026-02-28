#!/usr/bin/env bash
# Radon runner for Python complexity metrics
# Usage: ./radon-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-radon-report.json}"

echo "Running Radon complexity analysis on: $SOURCE_DIR"

# Determine Python command
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
else
  PYTHON_CMD="python"
fi

# Run Radon cyclomatic complexity
# -j: JSON output
# -a: Calculate average complexity
# -s: Show complexity score
$PYTHON_CMD -m radon cc \
  --json \
  --average \
  --exclude "venv/*,.venv/*,env/*,__pycache__/*,migrations/*,tests/*" \
  "$SOURCE_DIR" \
  > "$OUTPUT_FILE" 2>&1 || true

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Radon scan complete: $OUTPUT_FILE"
  # Count high-complexity functions (complexity > 10)
  HIGH_COMPLEXITY=$($PYTHON_CMD -c "
import json
data = json.load(open('$OUTPUT_FILE'))
count = 0
for file_data in data.values():
    if isinstance(file_data, list):
        count += sum(1 for item in file_data if item.get('complexity', 0) > 10)
print(count)
" 2>/dev/null || echo "0")
  echo "   Found $HIGH_COMPLEXITY high-complexity functions (>10)"
else
  echo "⚠️ Radon did not produce output file"
  echo "{}" > "$OUTPUT_FILE"
fi
