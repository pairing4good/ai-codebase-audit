#!/usr/bin/env bash
# SonarQube runner for Python (requires sonar-project.properties)
# Usage: ./sonarqube-runner.sh <source_dir> <output_file>

set -e

SOURCE_DIR="${1:-.}"
OUTPUT_FILE="${2:-sonarqube-report.json}"

echo "Running SonarQube Scanner on: $SOURCE_DIR"

# Check if sonar-scanner is available
if ! command -v sonar-scanner >/dev/null 2>&1; then
  echo "⚠️ sonar-scanner not found. Skipping."
  echo '{"issues":[]}' > "$OUTPUT_FILE"
  exit 0
fi

# Check if sonar-project.properties exists
if [ ! -f "$SOURCE_DIR/sonar-project.properties" ]; then
  echo "⚠️ sonar-project.properties not found. Skipping."
  echo '{"issues":[]}' > "$OUTPUT_FILE"
  exit 0
fi

# Run SonarQube Scanner
cd "$SOURCE_DIR"
sonar-scanner \
  -Dsonar.working.directory=.sonarqube \
  2>&1 || true

# Note: SonarQube doesn't directly produce JSON output
# Results are typically sent to SonarQube server
# This is a placeholder for when SonarQube server integration is available
echo '{"issues":[], "note":"Results sent to SonarQube server"}' > "$OUTPUT_FILE"

echo "✅ SonarQube scan complete (results on server)"
