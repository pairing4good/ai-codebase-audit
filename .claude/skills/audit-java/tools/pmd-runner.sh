#!/bin/bash
# PMD runner for Java - Code quality and complexity detection
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/pmd-report.xml}"

echo "=== PMD Code Quality Analysis ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Detect build tool
if [ -f "$PROJECT_DIR/pom.xml" ]; then
    echo "Running PMD via Maven..."
    cd "$PROJECT_DIR"
    mvn pmd:pmd -q || true
    [ -f "target/pmd.xml" ] && cp "target/pmd.xml" "$OUTPUT_FILE"
elif [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
    echo "Running PMD via Gradle..."
    cd "$PROJECT_DIR"
    ./gradlew pmdMain --no-daemon -q || true
    [ -f "build/reports/pmd/main.xml" ] && cp "build/reports/pmd/main.xml" "$OUTPUT_FILE"
else
    echo "⚠️  PMD not configured"
    echo '<?xml version="1.0" encoding="UTF-8"?><pmd></pmd>' > "$OUTPUT_FILE"
    exit 0
fi

[ -f "$OUTPUT_FILE" ] && echo "✅ PMD analysis complete: $OUTPUT_FILE" || echo '<?xml version="1.0" encoding="UTF-8"?><pmd></pmd>' > "$OUTPUT_FILE"
