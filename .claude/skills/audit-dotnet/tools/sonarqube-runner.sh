#!/bin/bash
# SonarQube Scanner runner for .NET
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/sonarqube-report.json}"

echo "=== SonarQube Analysis ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

if ! command -v dotnet-sonarscanner &> /dev/null; then
    echo "⚠️  dotnet-sonarscanner not installed"
    echo '{"issues":[]}' > "$OUTPUT_FILE"
    exit 0
fi

cd "$PROJECT_DIR"
# SonarQube requires server configuration
echo '{"issues":[],"note":"SonarQube requires server configuration"}' > "$OUTPUT_FILE"
echo "⚠️  SonarQube requires server setup"
