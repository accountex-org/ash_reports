#!/bin/bash

# Script to create GitHub issues from implementation plan tasks
# Requires: gh (GitHub CLI) to be installed and authenticated
#
# Usage: ./create_github_issues.sh [OPTIONS] [plan_file]
#   
# Options:
#   -h, --help              Show this help message
#   -d, --dry-run          Show what would be created without actually creating
#   
# Arguments:
#   plan_file               Optional path to implementation plan (default: auto-detect)
#
# Note: This script has been superseded by create_github_issues_batch.sh
#       which provides more features and better parsing.

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to show help
show_help() {
    echo "Create GitHub issues from implementation plan tasks"
    echo ""
    echo -e "${YELLOW}Note: This script has been superseded by create_github_issues_batch.sh${NC}"
    echo -e "${YELLOW}      which provides more features and better parsing.${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] [plan_file]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -d, --dry-run    Show what would be created without actually creating"
    echo ""
    echo "Arguments:"
    echo "  plan_file        Optional path to implementation plan (default: auto-detect)"
    echo ""
    echo "Recommended: Use create_github_issues_batch.sh instead"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            # Pass all arguments to the batch script
            break
            ;;
    esac
done

echo -e "${YELLOW}This script has been superseded by create_github_issues_batch.sh${NC}"
echo -e "${BLUE}Redirecting to the improved batch script...${NC}"
echo ""

# Get script directory and redirect to batch script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/create_github_issues_batch.sh" "$@"
