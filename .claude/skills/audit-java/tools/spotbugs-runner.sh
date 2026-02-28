#!/bin/bash
# SpotBugs + Find Security Bugs runner for Java - OWASP Top 10, CWE/SANS 25
set -e

PROJECT_DIR="${1:-.}"
OUTPUT_FILE="${2:-.analysis/stage3-static-analysis/raw-outputs/spotbugs-report.xml}"

echo "=== SpotBugs + Find Security Bugs Analysis ==="

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Detect build tool
if [ -f "$PROJECT_DIR/pom.xml" ]; then
    BUILD_TOOL="maven"
    echo "Maven project detected"
elif [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
    BUILD_TOOL="gradle"
    echo "Gradle project detected"
else
    echo "ERROR: No pom.xml or build.gradle found"
    exit 1
fi

# Run SpotBugs via build tool
if [ "$BUILD_TOOL" = "maven" ]; then
    # Check if SpotBugs plugin is in pom.xml
    if grep -q "spotbugs-maven-plugin" "$PROJECT_DIR/pom.xml"; then
        echo "Running SpotBugs via Maven..."
        cd "$PROJECT_DIR"
        mvn spotbugs:spotbugs -DxmlOutput=true -DoutputDirectory="$(dirname "$OUTPUT_FILE")" -q || true

        # Maven outputs to target/spotbugsXml.xml by default
        if [ -f "target/spotbugsXml.xml" ]; then
            mv "target/spotbugsXml.xml" "$OUTPUT_FILE"
        fi
    else
        echo "⚠️  SpotBugs plugin not configured in pom.xml"
        echo "Add to pom.xml:"
        echo "<build><plugins><plugin>"
        echo "  <groupId>com.github.spotbugs</groupId>"
        echo "  <artifactId>spotbugs-maven-plugin</artifactId>"
        echo "  <version>4.7.3.6</version>"
        echo "  <dependencies>"
        echo "    <dependency>"
        echo "      <groupId>com.h3xstream.findsecbugs</groupId>"
        echo "      <artifactId>findsecbugs-plugin</artifactId>"
        echo "      <version>1.12.0</version>"
        echo "    </dependency>"
        echo "  </dependencies>"
        echo "</plugin></plugins></build>"
        echo '<?xml version="1.0" encoding="UTF-8"?><BugCollection></BugCollection>' > "$OUTPUT_FILE"
        exit 0
    fi

elif [ "$BUILD_TOOL" = "gradle" ]; then
    # Check if SpotBugs plugin is in build.gradle
    if grep -q "spotbugs" "$PROJECT_DIR/build.gradle" "$PROJECT_DIR/build.gradle.kts" 2>/dev/null; then
        echo "Running SpotBugs via Gradle..."
        cd "$PROJECT_DIR"
        ./gradlew spotbugsMain --no-daemon -q || true

        # Gradle outputs to build/reports/spotbugs/main.xml by default
        if [ -f "build/reports/spotbugs/main.xml" ]; then
            cp "build/reports/spotbugs/main.xml" "$OUTPUT_FILE"
        fi
    else
        echo "⚠️  SpotBugs plugin not configured in build.gradle"
        echo "Add to build.gradle:"
        echo "plugins {"
        echo "    id 'com.github.spotbugs' version '5.0.14'"
        echo "}"
        echo "spotbugs {"
        echo "    toolVersion = '4.7.3'"
        echo "}"
        echo "dependencies {"
        echo "    spotbugsPlugins 'com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0'"
        echo "}"
        echo '<?xml version="1.0" encoding="UTF-8"?><BugCollection></BugCollection>' > "$OUTPUT_FILE"
        exit 0
    fi
fi

# Check if output was created
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "WARNING: SpotBugs did not produce output"
    echo '<?xml version="1.0" encoding="UTF-8"?><BugCollection></BugCollection>' > "$OUTPUT_FILE"
    exit 0
fi

# Count findings
TOTAL_BUGS=$(xmllint --xpath "count(//BugInstance)" "$OUTPUT_FILE" 2>/dev/null || echo "0")
CRITICAL=$(xmllint --xpath "count(//BugInstance[@priority='1'])" "$OUTPUT_FILE" 2>/dev/null || echo "0")
HIGH=$(xmllint --xpath "count(//BugInstance[@priority='2'])" "$OUTPUT_FILE" 2>/dev/null || echo "0")
MEDIUM=$(xmllint --xpath "count(//BugInstance[@priority='3'])" "$OUTPUT_FILE" 2>/dev/null || echo "0")

echo "✅ SpotBugs analysis complete"
echo "   Total bugs: $TOTAL_BUGS"
echo "   Priority 1 (Critical): $CRITICAL"
echo "   Priority 2 (High): $HIGH"
echo "   Priority 3 (Medium): $MEDIUM"
echo "   Output: $OUTPUT_FILE"
