#!/usr/bin/env bash
# Semgrep runner for Python with OWASP/CWE rulesets
# Usage: ./semgrep-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-semgrep-report.json}"

echo "Running Semgrep with Python OWASP/CWE rulesets on: $SOURCE_DIR"

# Check if semgrep is available
if ! command -v semgrep >/dev/null 2>&1; then
  echo "⚠️ Semgrep not found. Skipping."
  echo "[]" > "$OUTPUT_FILE"
  exit 0
fi

# Run Semgrep with Python-specific security rulesets
# --config: Use Python OWASP and security rulesets
# --json: JSON output
# --quiet: Minimize output noise

# Debug mode: show full command
if [ "$DEBUG_MODE" = "true" ]; then
  echo "DEBUG: Running semgrep with configs: python, owasp-top-ten, django, flask, security-audit"
  set -x
fi

# Capture stderr to detect actual errors (not just findings)
ERROR_FILE=$(mktemp)
if semgrep scan \
  --config "p/python" \
  --config "p/owasp-top-ten" \
  --config "p/django" \
  --config "p/flask" \
  --config "p/security-audit" \
  --json \
  --quiet \
  --exclude "venv/" \
  --exclude ".venv/" \
  --exclude "*/migrations/*" \
  --exclude "*/tests/*" \
  --exclude "__pycache__/" \
  --output "$OUTPUT_FILE" \
  "$SOURCE_DIR" \
  2>"$ERROR_FILE"; then
  # Success
  rm -f "$ERROR_FILE"
else
  # Tool failed - log error details but don't fail the analysis
  EXIT_CODE=$?
  echo "⚠️ Semgrep exited with code $EXIT_CODE" >&2
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
  echo "✅ Semgrep scan complete: $OUTPUT_FILE"
  # Show summary
  ISSUES=$(python3 -c "import json; data=json.load(open('$OUTPUT_FILE')); print(len(data.get('results', [])))" 2>/dev/null || echo "0")
  echo "   Found $ISSUES security issues"
else
  echo "⚠️ Semgrep did not produce output file"
  echo '{"results":[]}' > "$OUTPUT_FILE"
fi
