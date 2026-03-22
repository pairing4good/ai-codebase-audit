#!/bin/bash
# Watch all container logs in real-time
#
# This script monitors log files from running skill containers, allowing you
# to see analysis progress in real-time. Useful for monitoring long-running
# audits or debugging issues.
#
# Usage:
#   ./scripts/watch-logs.sh [OPTIONS]
#
# Options:
#   --all, -a           Show all logs (task + summary + docker)
#   --task, -t          Show only task logs (default)
#   --summary, -s       Show only summary logs
#   --docker, -d        Show only docker logs
#   --latest, -l        Show only latest log file
#   --pattern PATTERN   Filter logs by pattern (grep)
#   -h, --help          Show this help message
#
# Examples:
#   ./scripts/watch-logs.sh                    # Watch all task logs
#   ./scripts/watch-logs.sh --latest           # Watch latest task log only
#   ./scripts/watch-logs.sh --all              # Watch all log types
#   ./scripts/watch-logs.sh --pattern "ERROR"  # Show only ERROR lines
#   ./scripts/watch-logs.sh --pattern "project-one"  # Filter by project
#
# Environment Variables:
#   AUDIT_BASE_DIR    Required - Path to workspace directory
#
# Exit codes:
#   0 - Success (interrupted by user)
#   1 - Error (missing dependencies, invalid arguments, etc.)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SHOW_TASK=true
SHOW_SUMMARY=false
SHOW_DOCKER=false
LATEST_ONLY=false
FILTER_PATTERN=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            SHOW_TASK=true
            SHOW_SUMMARY=true
            SHOW_DOCKER=true
            shift
            ;;
        --task|-t)
            SHOW_TASK=true
            SHOW_SUMMARY=false
            SHOW_DOCKER=false
            shift
            ;;
        --summary|-s)
            SHOW_TASK=false
            SHOW_SUMMARY=true
            SHOW_DOCKER=false
            shift
            ;;
        --docker|-d)
            SHOW_TASK=false
            SHOW_SUMMARY=false
            SHOW_DOCKER=true
            shift
            ;;
        --latest|-l)
            LATEST_ONLY=true
            shift
            ;;
        --pattern)
            FILTER_PATTERN="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Watch container logs in real-time"
            echo ""
            echo "Options:"
            echo "  --all, -a           Show all logs (task + summary + docker)"
            echo "  --task, -t          Show only task logs (default)"
            echo "  --summary, -s       Show only summary logs"
            echo "  --docker, -d        Show only docker logs"
            echo "  --latest, -l        Show only latest log file"
            echo "  --pattern PATTERN   Filter logs by pattern (grep)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                         # Watch all task logs"
            echo "  $0 --latest                # Watch latest task log"
            echo "  $0 --all                   # Watch all log types"
            echo "  $0 --pattern ERROR         # Show only ERROR lines"
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
echo "  DevContainer Log Viewer"
echo "=================================================="
echo ""

# Check required environment variables
if [ -z "$AUDIT_BASE_DIR" ]; then
    echo -e "${RED}Error: AUDIT_BASE_DIR environment variable not set${NC}"
    echo "Set it to your workspace directory:"
    echo "  export AUDIT_BASE_DIR=~/code-audits"
    exit 1
fi

# Check if AUDIT_BASE_DIR exists
if [ ! -d "$AUDIT_BASE_DIR" ]; then
    echo -e "${RED}Error: AUDIT_BASE_DIR directory does not exist: $AUDIT_BASE_DIR${NC}"
    exit 1
fi

# Check if logs directory exists
LOGS_DIR="$AUDIT_BASE_DIR/logs"
if [ ! -d "$LOGS_DIR" ]; then
    echo -e "${RED}Error: Logs directory does not exist: $LOGS_DIR${NC}"
    echo "Run the orchestrator first to generate logs"
    exit 1
fi

# Build list of log files to watch
LOG_FILES=()

if [ "$LATEST_ONLY" = true ]; then
    # Find the latest log file
    if [ "$SHOW_TASK" = true ]; then
        LATEST=$(ls -t "$LOGS_DIR"/task_*.log 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            LOG_FILES+=("$LATEST")
        fi
    fi
    if [ "$SHOW_SUMMARY" = true ]; then
        LATEST=$(ls -t "$LOGS_DIR"/summary_*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            LOG_FILES+=("$LATEST")
        fi
    fi
    if [ "$SHOW_DOCKER" = true ]; then
        LATEST=$(ls -t "$LOGS_DIR"/docker_*.log 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            LOG_FILES+=("$LATEST")
        fi
    fi
else
    # Find all matching log files
    if [ "$SHOW_TASK" = true ]; then
        while IFS= read -r -d '' file; do
            LOG_FILES+=("$file")
        done < <(find "$LOGS_DIR" -name "task_*.log" -print0 2>/dev/null)
    fi
    if [ "$SHOW_SUMMARY" = true ]; then
        while IFS= read -r -d '' file; do
            LOG_FILES+=("$file")
        done < <(find "$LOGS_DIR" -name "summary_*.txt" -print0 2>/dev/null)
    fi
    if [ "$SHOW_DOCKER" = true ]; then
        while IFS= read -r -d '' file; do
            LOG_FILES+=("$file")
        done < <(find "$LOGS_DIR" -name "docker_*.log" -print0 2>/dev/null)
    fi
fi

# Check if we found any log files
if [ ${#LOG_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}No log files found matching criteria${NC}"
    echo ""
    echo "Available logs:"
    ls -lht "$LOGS_DIR"/*.log "$LOGS_DIR"/*.txt 2>/dev/null | head -10 || echo "  (none)"
    exit 1
fi

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  Logs directory: $LOGS_DIR"
echo "  Watching ${#LOG_FILES[@]} file(s)"
if [ -n "$FILTER_PATTERN" ]; then
    echo "  Filter pattern: $FILTER_PATTERN"
fi
echo ""

echo -e "${BLUE}Files:${NC}"
for file in "${LOG_FILES[@]}"; do
    echo "  - $(basename "$file")"
done
echo ""

echo "=================================================="
echo -e "${GREEN}Watching logs... (Press Ctrl+C to stop)${NC}"
echo "=================================================="
echo ""

# Watch the logs
if [ -n "$FILTER_PATTERN" ]; then
    # Watch with grep filter
    if command -v multitail &> /dev/null; then
        # Use multitail if available (better multi-file viewing)
        multitail -s 2 -l "grep --line-buffered '$FILTER_PATTERN'" "${LOG_FILES[@]}"
    else
        # Fallback to tail with grep
        tail -f "${LOG_FILES[@]}" 2>/dev/null | grep --line-buffered "$FILTER_PATTERN"
    fi
else
    # Watch without filter
    if command -v multitail &> /dev/null; then
        # Use multitail if available (better multi-file viewing)
        multitail -s 2 "${LOG_FILES[@]}"
    else
        # Fallback to tail
        tail -f "${LOG_FILES[@]}" 2>/dev/null
    fi
fi

# Note: tail -f will run until interrupted (Ctrl+C)
# Exit code will be 0 on normal interrupt
