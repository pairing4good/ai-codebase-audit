#!/bin/bash
# Checkstyle runner for Java - Code style and consistency
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/checkstyle-report.xml}"

echo "=== Checkstyle Code Style Analysis ==="
mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ -f "$PROJECT_DIR/pom.xml" ]; then
    cd "$PROJECT_DIR"
    mvn checkstyle:checkstyle -q || true
    [ -f "target/checkstyle-result.xml" ] && cp "target/checkstyle-result.xml" "$OUTPUT_FILE"
elif [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
    cd "$PROJECT_DIR"
    ./gradlew checkstyleMain --no-daemon -q || true
    [ -f "build/reports/checkstyle/main.xml" ] && cp "build/reports/checkstyle/main.xml" "$OUTPUT_FILE"
else
    echo "⚠️  Checkstyle not configured"
    echo '<?xml version="1.0" encoding="UTF-8"?><checkstyle></checkstyle>' > "$OUTPUT_FILE"
    exit 0
fi

[ -f "$OUTPUT_FILE" ] && echo "✅ Checkstyle complete: $OUTPUT_FILE" || echo '<?xml version="1.0" encoding="UTF-8"?><checkstyle></checkstyle>' > "$OUTPUT_FILE"
