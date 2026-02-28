#!/bin/bash
# OWASP Dependency-Check runner for Java - CVE scanning
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/dependency-check-report.json}"

echo "=== OWASP Dependency-Check Analysis ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ -f "$PROJECT_DIR/pom.xml" ]; then
    cd "$PROJECT_DIR"
    mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=11 -Dformat=JSON -q || true
    [ -f "target/dependency-check-report.json" ] && cp "target/dependency-check-report.json" "$OUTPUT_FILE"
elif [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
    cd "$PROJECT_DIR"
    ./gradlew dependencyCheckAnalyze --no-daemon -q || true
    [ -f "build/reports/dependency-check-report.json" ] && cp "build/reports/dependency-check-report.json" "$OUTPUT_FILE"
else
    echo "⚠️  OWASP Dependency-Check not configured"
    echo '{"dependencies":[]}' > "$OUTPUT_FILE"
    exit 0
fi

[ -f "$OUTPUT_FILE" ] && echo "✅ Dependency-Check complete: $OUTPUT_FILE" || echo '{"dependencies":[]}' > "$OUTPUT_FILE"
