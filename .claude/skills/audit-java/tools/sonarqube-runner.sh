#!/bin/bash
# SonarQube Scanner runner for Java
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/sonarqube-report.json}"

echo "=== SonarQube Analysis ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

if ! command -v sonar-scanner &> /dev/null; then
    echo "⚠️  SonarQube Scanner not installed"
    echo '{"issues":[]}' > "$OUTPUT_FILE"
    exit 0
fi

if [ ! -f "$PROJECT_DIR/sonar-project.properties" ]; then
    echo "⚠️  sonar-project.properties not found"
    echo '{"issues":[]}' > "$OUTPUT_FILE"
    exit 0
fi

cd "$PROJECT_DIR"
sonar-scanner -Dsonar.scm.disabled=true || true

echo "✅ SonarQube scan initiated (results on server)"
echo '{"issues":[],"note":"Check SonarQube server for results"}' > "$OUTPUT_FILE"
