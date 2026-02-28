#!/usr/bin/env bash
# Snyk runner for Python SAST and dependency analysis
# Usage: ./snyk-runner.sh <source_dir> <output_dir>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_DIR="${2:-.}"

echo "Running Snyk analysis on: $SOURCE_DIR"

# Check if snyk is available
if ! command -v snyk >/dev/null 2>&1; then
  echo "⚠️ Snyk not found. Skipping."
  mkdir -p "$OUTPUT_DIR"
  echo "[]" > "$OUTPUT_DIR/snyk-code-report.json"
  echo "[]" > "$OUTPUT_DIR/snyk-oss-report.json"
  exit 0
fi

# Check if authenticated
if ! snyk auth status >/dev/null 2>&1; then
  echo "⚠️ Snyk not authenticated. Run 'snyk auth' first. Skipping."
  mkdir -p "$OUTPUT_DIR"
  echo "[]" > "$OUTPUT_DIR/snyk-code-report.json"
  echo "[]" > "$OUTPUT_DIR/snyk-oss-report.json"
  exit 0
fi

mkdir -p "$OUTPUT_DIR"

# Run Snyk Code (SAST)
echo "Running Snyk Code (SAST)..."
snyk code test \
  --json \
  --severity-threshold=low \
  "$SOURCE_DIR" \
  > "$OUTPUT_DIR/snyk-code-report.json" 2>&1 || true

if [ -f "$OUTPUT_DIR/snyk-code-report.json" ]; then
  echo "   ✅ Snyk Code scan complete"
fi

# Run Snyk Open Source (SCA - dependency vulnerabilities)
echo "Running Snyk Open Source (dependency scan)..."
snyk test \
  --json \
  --severity-threshold=low \
  "$SOURCE_DIR" \
  > "$OUTPUT_DIR/snyk-oss-report.json" 2>&1 || true

if [ -f "$OUTPUT_DIR/snyk-oss-report.json" ]; then
  echo "   ✅ Snyk Open Source scan complete"
fi

echo "✅ Snyk analysis complete: $OUTPUT_DIR"
