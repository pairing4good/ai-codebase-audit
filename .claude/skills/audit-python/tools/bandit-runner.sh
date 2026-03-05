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

# Debug mode: show full command
if [ "$DEBUG_MODE" = "true" ]; then
  echo "DEBUG: Running bandit on $SOURCE_DIR"
  set -x
fi

# Capture stderr to detect actual errors (not just findings)
ERROR_FILE=$(mktemp)
if $PYTHON_CMD -m bandit \
  -r "$SOURCE_DIR" \
  -f json \
  -o "$OUTPUT_FILE" \
  -ll \
  --exclude "*/venv/*,*/.venv/*,*/env/*,*/virtualenv/*,*/__pycache__/*,*/migrations/*,*/tests/*" \
  2>"$ERROR_FILE"; then
  # Success
  rm -f "$ERROR_FILE"
else
  # Tool failed - log error details but don't fail the analysis
  EXIT_CODE=$?
  echo "⚠️ Bandit exited with code $EXIT_CODE" >&2
  if [ -s "$ERROR_FILE" ]; then
    echo "Error output:" >&2
    cat "$ERROR_FILE" >&2
  fi
  rm -f "$ERROR_FILE"
  # Create empty result if no output file
  if [ ! -f "$OUTPUT_FILE" ]; then
    echo '{"results":[]}' > "$OUTPUT_FILE"
  fi
fi

if [ "$DEBUG_MODE" = "true" ]; then
  set +x
fi

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ Bandit scan complete: $OUTPUT_FILE"
  # Show summary
  ISSUES=$($PYTHON_CMD -c "import json; data=json.load(open('$OUTPUT_FILE')); print(len(data.get('results', [])))" 2>/dev/null || echo "0")
  echo "   Found $ISSUES security issues"
else
  echo "⚠️ Bandit did not produce output file"
  echo '{"results":[]}' > "$OUTPUT_FILE"
fi
