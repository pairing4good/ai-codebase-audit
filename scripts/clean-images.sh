#!/bin/bash
# Remove locally built images to force rebuild
#
# This script removes the audit-runner:local image and prunes unused Docker images,
# forcing a complete rebuild on the next run of orchestrator_devcontainer.py.
#
# Usage:
#   ./scripts/clean-images.sh [--all]
#
# Options:
#   --all    Also remove dangling images and build cache
#
# Exit codes:
#   0 - Success
#   1 - Error

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command-line arguments
CLEAN_ALL=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEAN_ALL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--all]"
            echo ""
            echo "Remove locally built DevContainer images to force rebuild."
            echo ""
            echo "Options:"
            echo "  --all    Also remove dangling images and build cache"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo "=================================================="
echo "  DevContainer Image Cleanup"
echo "=================================================="
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Remove audit-runner:local image
echo -e "${YELLOW}Removing audit-runner:local image...${NC}"
if docker rmi audit-runner:local 2>/dev/null; then
    echo -e "${GREEN}✓ Removed audit-runner:local${NC}"
else
    echo -e "${YELLOW}⚠ Image audit-runner:local not found (already removed or never built)${NC}"
fi

echo ""

# Prune unused images
echo -e "${YELLOW}Pruning unused Docker images...${NC}"
if docker image prune -f >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Pruned unused images${NC}"
else
    echo -e "${YELLOW}⚠ No unused images to prune${NC}"
fi

echo ""

# Optional: Deep clean (build cache and dangling images)
if [ "$CLEAN_ALL" = true ]; then
    echo -e "${YELLOW}Removing dangling images...${NC}"
    if docker image prune -a -f >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Removed dangling images${NC}"
    else
        echo -e "${YELLOW}⚠ No dangling images to remove${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Pruning build cache...${NC}"
    if docker builder prune -f >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Pruned build cache${NC}"
    else
        echo -e "${YELLOW}⚠ No build cache to prune${NC}"
    fi
fi

echo ""
echo "=================================================="
echo -e "${GREEN}Cleanup complete!${NC}"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Run orchestrator to rebuild:"
echo "     python3 orchestrator_devcontainer.py"
echo ""
echo "  2. Or manually build and verify:"
echo "     ./scripts/build-local.sh --verify"
echo ""
echo "Note: Next run will rebuild from .devcontainer/Dockerfile"
echo "      (expected build time: 10-15 minutes)"
