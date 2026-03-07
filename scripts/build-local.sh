#!/bin/bash
# =============================================================================
# build-local.sh — Build DevContainer Image Locally
# =============================================================================
# Builds the devcontainer image from .devcontainer/Dockerfile for local testing.
#
# Usage:
#   ./scripts/build-local.sh [options]
#
# Options:
#   --no-cache    Build without using Docker layer cache (slower but clean)
#   --tag TAG     Specify custom image tag (default: audit-runner:local)
#   --verify      Run verification script after successful build
#
# Exit codes:
#   0 - Build successful (and verification passed if --verify used)
#   1 - Build failed or verification failed
# =============================================================================

set -euo pipefail

# Default values
USE_CACHE=true
IMAGE_TAG="audit-runner:local"
RUN_VERIFY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            USE_CACHE=false
            shift
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --verify)
            RUN_VERIFY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --no-cache    Build without using Docker layer cache"
            echo "  --tag TAG     Specify custom image tag (default: audit-runner:local)"
            echo "  --verify      Run verification script after build"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Change to repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "============================================================"
echo "Building DevContainer Image"
echo "============================================================"
echo "Repository:  $REPO_ROOT"
echo "Dockerfile:  .devcontainer/Dockerfile"
echo "Image tag:   $IMAGE_TAG"
echo "Use cache:   $USE_CACHE"
echo "Verify:      $RUN_VERIFY"
echo "============================================================"
echo ""

# Check if Dockerfile exists
if [ ! -f ".devcontainer/Dockerfile" ]; then
    echo "ERROR: .devcontainer/Dockerfile not found"
    echo ""
    echo "Expected path: $REPO_ROOT/.devcontainer/Dockerfile"
    exit 1
fi

# Build Docker image
echo "Starting build..."
echo ""

BUILD_ARGS=(
    "build"
    "-f" ".devcontainer/Dockerfile"
    "-t" "$IMAGE_TAG"
    "--progress=plain"
)

if [ "$USE_CACHE" = false ]; then
    BUILD_ARGS+=("--no-cache")
    echo "Note: Building without cache (this will take 10-15 minutes)"
    echo ""
fi

BUILD_ARGS+=(".")

# Run docker build
if docker "${BUILD_ARGS[@]}"; then
    echo ""
    echo "============================================================"
    echo "✓ Build SUCCESSFUL"
    echo "============================================================"
    echo ""
    echo "Image: $IMAGE_TAG"
    echo ""

    # Show image size
    IMAGE_SIZE=$(docker image inspect "$IMAGE_TAG" --format='{{.Size}}' | awk '{printf "%.2f GB", $1/1024/1024/1024}')
    echo "Size:  $IMAGE_SIZE"
    echo ""

    # Run verification if requested
    if [ "$RUN_VERIFY" = true ]; then
        echo "Running verification..."
        echo ""

        if [ -f "$SCRIPT_DIR/verify-build.sh" ]; then
            if "$SCRIPT_DIR/verify-build.sh" "$IMAGE_TAG"; then
                echo ""
                echo "✓ Verification PASSED"
                echo ""
            else
                echo ""
                echo "✗ Verification FAILED"
                echo ""
                exit 1
            fi
        else
            echo "Warning: verify-build.sh not found at $SCRIPT_DIR/verify-build.sh"
            echo "Skipping verification"
            echo ""
        fi
    else
        echo "To verify the build:"
        echo "  ./scripts/verify-build.sh $IMAGE_TAG"
        echo ""
    fi

    echo "To use this image with the orchestrator:"
    echo "  1. Update config.yml: runner.image_tag: $IMAGE_TAG"
    echo "  2. Run: python orchestrator_devcontainer.py"
    echo ""

else
    echo ""
    echo "============================================================"
    echo "✗ Build FAILED"
    echo "============================================================"
    echo ""
    echo "Check the error messages above for details."
    echo ""
    echo "Common issues:"
    echo "  - Network connectivity (downloading packages)"
    echo "  - Disk space (need ~10GB free)"
    echo "  - Docker daemon not running"
    echo ""
    echo "Try building without cache:"
    echo "  ./scripts/build-local.sh --no-cache"
    echo ""
    exit 1
fi
