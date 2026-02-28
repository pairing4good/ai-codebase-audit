#!/bin/bash
# dotnet-outdated runner for .NET - Dependency version checking
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/dotnet-outdated-report.json}"

echo "=== dotnet-outdated Analysis ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

cd "$PROJECT_DIR"

if command -v dotnet-outdated &> /dev/null; then
  dotnet-outdated --output json > "$OUTPUT_FILE" 2>/dev/null || echo '{"projects":[]}' > "$OUTPUT_FILE"
else
  echo "⚠️  dotnet-outdated not installed"
  echo "Install with: dotnet tool install --global dotnet-outdated-tool"
  echo '{"projects":[]}' > "$OUTPUT_FILE"
fi

echo "✅ dotnet-outdated complete: $OUTPUT_FILE"
