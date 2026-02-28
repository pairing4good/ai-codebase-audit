#!/bin/bash

# Trivy Runner for IaC, Containers, and Dependencies
# Scans Dockerfiles, Kubernetes manifests, Terraform, and dependencies

set -e

OUTPUT_DIR="${1:-.analysis/stage3-static-analysis/raw-outputs}"
PROJECT_DIR="${2:-.}"

echo "🔍 Running Trivy security scanner..."
echo "   Output: $OUTPUT_DIR/trivy.json"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if trivy is installed
if ! command -v trivy &> /dev/null; then
    echo "ℹ️  Trivy not found (optional tool)"
    echo "   Install with: brew install aquasecurity/trivy/trivy"
    echo "   Skipping Trivy scan..."
    echo "[]" > "$OUTPUT_DIR/trivy.json"
    exit 0
fi

cd "$PROJECT_DIR"

# Detect what to scan
SCAN_TARGETS=()
SCAN_PERFORMED=false

# Check for Dockerfile
if [ -f "Dockerfile" ] || [ -f "dockerfile" ]; then
    echo "   📦 Found Dockerfile"
    SCAN_TARGETS+=("dockerfile")
fi

# Check for Kubernetes manifests
if [ -d "k8s" ] || [ -d "kubernetes" ] || [ -f "deployment.yaml" ]; then
    echo "   ☸️  Found Kubernetes manifests"
    SCAN_TARGETS+=("k8s")
fi

# Check for Terraform
if [ -d "terraform" ] || ls *.tf &>/dev/null; then
    echo "   🏗️  Found Terraform files"
    SCAN_TARGETS+=("terraform")
fi

# Check for dependencies (package.json, requirements.txt, etc.)
if [ -f "package.json" ] || [ -f "package-lock.json" ]; then
    echo "   📚 Found JavaScript dependencies"
    SCAN_TARGETS+=("dependencies")
fi

if [ ${#SCAN_TARGETS[@]} -eq 0 ]; then
    echo "   ℹ️  No IaC or container files found, skipping Trivy"
    echo "[]" > "$OUTPUT_DIR/trivy.json"
    exit 0
fi

# Initialize output JSON
echo "{\"results\": []}" > "$OUTPUT_DIR/trivy.json"

# Scan filesystem for IaC misconfigurations
if [[ " ${SCAN_TARGETS[*]} " =~ " dockerfile " ]] || \
   [[ " ${SCAN_TARGETS[*]} " =~ " k8s " ]] || \
   [[ " ${SCAN_TARGETS[*]} " =~ " terraform " ]]; then

    echo ""
    echo "   Running filesystem scan for IaC misconfigurations..."

    trivy fs \
        --format json \
        --output "$OUTPUT_DIR/trivy-fs.json" \
        --quiet \
        --severity CRITICAL,HIGH,MEDIUM \
        --scanners misconfig,secret \
        . \
        2>&1 | tee "$OUTPUT_DIR/trivy-fs.log" || {
            echo "   ⚠️  Trivy filesystem scan completed with warnings"
        }

    SCAN_PERFORMED=true
fi

# Scan dependencies
if [[ " ${SCAN_TARGETS[*]} " =~ " dependencies " ]]; then
    echo ""
    echo "   Running dependency vulnerability scan..."

    trivy fs \
        --format json \
        --output "$OUTPUT_DIR/trivy-deps.json" \
        --quiet \
        --severity CRITICAL,HIGH,MEDIUM \
        --scanners vuln \
        . \
        2>&1 | tee "$OUTPUT_DIR/trivy-deps.log" || {
            echo "   ⚠️  Trivy dependency scan completed with warnings"
        }

    SCAN_PERFORMED=true
fi

# Merge results if scans were performed
if [ "$SCAN_PERFORMED" = true ]; then
    # Combine all Trivy outputs
    jq -s '{results: [.[] | .Results[]? | select(. != null)]}' \
        "$OUTPUT_DIR/trivy-fs.json" \
        "$OUTPUT_DIR/trivy-deps.json" \
        2>/dev/null > "$OUTPUT_DIR/trivy.json" || {
            echo "   ⚠️  Error merging Trivy results, using individual outputs"
        }

    # Count findings
    FINDING_COUNT=$(jq '[.results[] | .Vulnerabilities[]?, .Misconfigurations[]?] | length' "$OUTPUT_DIR/trivy.json" 2>/dev/null || echo "0")
    echo ""
    echo "✅ Trivy complete: $FINDING_COUNT findings"

    # Show breakdown by type
    VULN_COUNT=$(jq '[.results[] | .Vulnerabilities[]?] | length' "$OUTPUT_DIR/trivy.json" 2>/dev/null || echo "0")
    MISCONFIG_COUNT=$(jq '[.results[] | .Misconfigurations[]?] | length' "$OUTPUT_DIR/trivy.json" 2>/dev/null || echo "0")

    if [ "$VULN_COUNT" -gt 0 ]; then
        echo "   - Vulnerabilities: $VULN_COUNT"
    fi
    if [ "$MISCONFIG_COUNT" -gt 0 ]; then
        echo "   - Misconfigurations: $MISCONFIG_COUNT"
    fi
fi

cd - > /dev/null

echo ""
