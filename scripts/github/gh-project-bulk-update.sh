#!/bin/bash

# gh-project-bulk-update.sh - Bulk update tasks from checklist file

set -euo pipefail

REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
CHECKLIST_FILE="${1:-}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $0 <checklist-file>

Bulk update task checkboxes from a checklist file.

Checklist file format:
  #<issue-number> <task-pattern> <true|false>

Example checklist.txt:
  #42 "Create Element entity types" true
  #42 "Implement position and style schemas" true
  #43 "Create query builder for report scope" false

EOF
    exit 1
}

# Process checklist file
process_checklist() {
    local file="$1"
    local success_count=0
    local error_count=0
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Parse line
        if [[ "$line" =~ ^#([0-9]+)[[:space:]]+"([^"]+)"[[:space:]]+(true|false) ]]; then
            local issue_num="${BASH_REMATCH[1]}"
            local task_pattern="${BASH_REMATCH[2]}"
            local checked="${BASH_REMATCH[3]}"
            
            echo -e "${BLUE}Updating issue #$issue_num: \"$task_pattern\" -> $checked${NC}"
            
            if ./gh-project-manager.sh update-task "$issue_num" "$task_pattern" "$checked"; then
                ((success_count++))
            else
                ((error_count++))
                echo -e "${RED}Failed to update task${NC}"
            fi
        else
            echo -e "${RED}Invalid line format: $line${NC}"
            ((error_count++))
        fi
    done < "$file"
    
    echo
    echo -e "${GREEN}✓ Successfully updated: $success_count tasks${NC}"
    [[ $error_count -gt 0 ]] && echo -e "${RED}✗ Failed: $error_count tasks${NC}"
}

# Main
main() {
    if [[ -z "$CHECKLIST_FILE" || ! -f "$CHECKLIST_FILE" ]]; then
        usage
    fi
    
    echo -e "${BLUE}Bulk updating tasks from: $CHECKLIST_FILE${NC}"
    echo
    
    process_checklist "$CHECKLIST_FILE"
}

main "$@"
