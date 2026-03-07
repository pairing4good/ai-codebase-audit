#!/bin/bash
# Test a single project+skill combination
#
# This script allows you to test one specific project and skill combination
# without running the full orchestrator. Useful for debugging and development.
#
# Usage:
#   ./scripts/test-single-skill.sh [PROJECT] [SKILL]
#
# Arguments:
#   PROJECT   Project directory name (default: first project in config.yml)
#   SKILL     Skill to run (default: /audit-java)
#
# Examples:
#   ./scripts/test-single-skill.sh project-one /audit-java
#   ./scripts/test-single-skill.sh my-app /audit-javascript
#   ./scripts/test-single-skill.sh  # Uses defaults
#
# Environment Variables:
#   AUDIT_BASE_DIR        Required - Path to workspace directory
#   ANTHROPIC_API_KEY     Required - Anthropic API key
#   DEBUG_MODE            Optional - Enable verbose logging (default: false)
#   MODEL                 Optional - Model to use (default: from config.yml)
#   MAX_TURNS             Optional - Max turns (default: from config.yml)
#   TIMEOUT               Optional - Timeout in seconds (default: from config.yml)
#
# Exit codes:
#   0 - Success
#   1 - Error (missing dependencies, invalid arguments, etc.)
#   2 - Skill execution failed

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PROJECT=""
DEFAULT_SKILL="/audit-java"

# Parse command-line arguments
show_help() {
    echo "Usage: $0 [PROJECT] [SKILL]"
    echo ""
    echo "Test a single project+skill combination"
    echo ""
    echo "Arguments:"
    echo "  PROJECT   Project directory name (default: first in config.yml)"
    echo "  SKILL     Skill to run (default: /audit-java)"
    echo ""
    echo "Available skills:"
    echo "  /audit-java"
    echo "  /audit-javascript"
    echo "  /audit-python"
    echo "  /audit-dotnet"
    echo ""
    echo "Examples:"
    echo "  $0 project-one /audit-java"
    echo "  $0 my-app /audit-javascript"
    echo ""
    echo "Environment variables:"
    echo "  AUDIT_BASE_DIR        Required - Workspace directory path"
    echo "  ANTHROPIC_API_KEY     Required - API key"
    echo "  DEBUG_MODE            Optional - Enable verbose logging"
    echo "  MODEL                 Optional - Override model from config.yml"
    exit 0
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

PROJECT=${1:-$DEFAULT_PROJECT}
SKILL=${2:-$DEFAULT_SKILL}

echo "=================================================="
echo "  DevContainer Single Skill Test"
echo "=================================================="
echo ""

# Check required environment variables
if [ -z "$AUDIT_BASE_DIR" ]; then
    echo -e "${RED}Error: AUDIT_BASE_DIR environment variable not set${NC}"
    echo "Set it to your workspace directory:"
    echo "  export AUDIT_BASE_DIR=~/code-audits"
    exit 1
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${RED}Error: ANTHROPIC_API_KEY environment variable not set${NC}"
    echo "Set it to your Anthropic API key:"
    echo "  export ANTHROPIC_API_KEY=sk-ant-..."
    exit 1
fi

# Check if AUDIT_BASE_DIR exists
if [ ! -d "$AUDIT_BASE_DIR" ]; then
    echo -e "${RED}Error: AUDIT_BASE_DIR directory does not exist: $AUDIT_BASE_DIR${NC}"
    exit 1
fi

# If no project specified, try to get first project from config.yml
if [ -z "$PROJECT" ]; then
    if [ ! -f "$AUDIT_BASE_DIR/config.yml" ]; then
        echo -e "${RED}Error: config.yml not found in $AUDIT_BASE_DIR${NC}"
        exit 1
    fi

    # Extract first project directory from config.yml
    PROJECT=$(grep -A 1 "^targets:" "$AUDIT_BASE_DIR/config.yml" | grep "dir:" | head -1 | sed 's/.*dir: *//; s/ *#.*//')

    if [ -z "$PROJECT" ]; then
        echo -e "${RED}Error: No project specified and could not find project in config.yml${NC}"
        echo "Usage: $0 PROJECT SKILL"
        exit 1
    fi

    echo -e "${YELLOW}No project specified, using first from config.yml: $PROJECT${NC}"
    echo ""
fi

# Check if project directory exists
if [ ! -d "$AUDIT_BASE_DIR/$PROJECT" ]; then
    echo -e "${RED}Error: Project directory does not exist: $AUDIT_BASE_DIR/$PROJECT${NC}"
    exit 1
fi

# Check if skill file exists
SKILL_FILE="$AUDIT_BASE_DIR/.claude/skills${SKILL}/SKILL.md"
if [ ! -f "$SKILL_FILE" ]; then
    echo -e "${RED}Error: Skill file does not exist: $SKILL_FILE${NC}"
    echo ""
    echo "Available skills:"
    ls -1 "$AUDIT_BASE_DIR/.claude/skills/" 2>/dev/null | grep "^audit-" | sed 's/^audit-/  \/audit-/'
    exit 1
fi

echo -e "${BLUE}Configuration:${NC}"
echo "  Workspace:  $AUDIT_BASE_DIR"
echo "  Project:    $PROJECT"
echo "  Skill:      $SKILL"
echo "  Debug mode: ${DEBUG_MODE:-false}"
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 not found${NC}"
    echo "Install Python 3.11+ and try again"
    exit 1
fi

# Check if required Python packages are installed
echo -e "${YELLOW}Checking Python dependencies...${NC}"
python3 -c "import aiodocker" 2>/dev/null || {
    echo -e "${RED}Error: aiodocker not installed${NC}"
    echo "Install with: pip install aiodocker"
    exit 1
}
python3 -c "import yaml" 2>/dev/null || {
    echo -e "${RED}Error: pyyaml not installed${NC}"
    echo "Install with: pip install pyyaml"
    exit 1
}
echo -e "${GREEN}✓ Python dependencies OK${NC}"
echo ""

# Check if Docker is running
echo -e "${YELLOW}Checking Docker...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Start Docker and try again"
    exit 1
fi
echo -e "${GREEN}✓ Docker OK${NC}"
echo ""

# Get script directory (repository root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

# Create temporary config.yml with only this project+skill
TEMP_CONFIG=$(mktemp)
trap "rm -f $TEMP_CONFIG" EXIT

echo -e "${YELLOW}Creating temporary config for single test...${NC}"

# Read config.yml and extract settings, but replace targets with our single target
cat > "$TEMP_CONFIG" <<EOF
# Temporary config for testing single project+skill
# Generated by test-single-skill.sh

runner:
  model: ${MODEL:-claude-sonnet-4-6}
  concurrency: 1
  max_turns: ${MAX_TURNS:-20}
  timeout: ${TIMEOUT:-300}
  max_budget_usd: ${MAX_BUDGET_USD:-10.0}
  image_tag: audit-runner:local
  rebuild: ${FORCE_REBUILD:-false}

targets:
  - dir: $PROJECT
    skills:
      - $SKILL

debug:
  enabled: ${DEBUG_MODE:-false}
EOF

echo -e "${GREEN}✓ Temporary config created${NC}"
echo ""

# Run the orchestrator with the temporary config
echo "=================================================="
echo "  Running orchestrator..."
echo "=================================================="
echo ""

cd "$SCRIPT_DIR"

# Copy temp config to AUDIT_BASE_DIR for orchestrator to read
cp "$TEMP_CONFIG" "$AUDIT_BASE_DIR/.test-config.yml"
trap "rm -f $TEMP_CONFIG $AUDIT_BASE_DIR/.test-config.yml" EXIT

# Run orchestrator with custom config path
export AUDIT_CONFIG="$AUDIT_BASE_DIR/.test-config.yml"

if python3 orchestrator_devcontainer.py; then
    echo ""
    echo "=================================================="
    echo -e "${GREEN}✓ Test completed successfully${NC}"
    echo "=================================================="
    echo ""
    echo "Results:"
    echo "  Logs:     $AUDIT_BASE_DIR/logs/"
    echo "  Analysis: $AUDIT_BASE_DIR/$PROJECT/.analysis/"
    echo ""
    echo "View latest summary:"
    echo "  cat $AUDIT_BASE_DIR/logs/summary_*.txt | tail -20"
    exit 0
else
    EXIT_CODE=$?
    echo ""
    echo "=================================================="
    echo -e "${RED}✗ Test failed (exit code: $EXIT_CODE)${NC}"
    echo "=================================================="
    echo ""
    echo "Check logs for details:"
    echo "  ls -lt $AUDIT_BASE_DIR/logs/task_*.log | head -1"
    echo ""
    echo "Enable debug mode for more details:"
    echo "  DEBUG_MODE=true $0 $PROJECT $SKILL"
    exit 2
fi
