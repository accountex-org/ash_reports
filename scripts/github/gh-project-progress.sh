#!/bin/bash

# gh-project-progress.sh - Show detailed progress report

set -euo pipefail

REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Progress bar function
progress_bar() {
    local completed=$1
    local total=$2
    local width=30
    
    if [[ $total -eq 0 ]]; then
        echo -n "[$(printf '%*s' $width | tr ' ' '-')] 0%"
        return
    fi
    
    local percent=$((completed * 100 / total))
    local filled=$((width * completed / total))
    local empty=$((width - filled))
    
    echo -n "["
    [[ $filled -gt 0 ]] && echo -n -e "${GREEN}$(printf '%*s' $filled | tr ' ' '█')${NC}"
    [[ $empty -gt 0 ]] && echo -n "$(printf '%*s' $empty | tr ' ' '░')"
    echo -n "] $percent%"
}

# Get milestone progress
show_milestone_progress() {
    echo -e "${BLUE}=== Milestone Progress ===${NC}"
    echo
    
    gh api "/repos/$REPO/milestones" --jq '.' | jq -r '.[] | @json' | while read -r milestone; do
        local title=$(echo "$milestone" | jq -r '.title')
        local open=$(echo "$milestone" | jq -r '.open_issues')
        local closed=$(echo "$milestone" | jq -r '.closed_issues')
        local total=$((open + closed))
        
        printf "%-40s " "$title"
        progress_bar "$closed" "$total"
        echo " ($closed/$total)"
    done
    echo
}

# Get issue task progress
show_task_progress() {
    echo -e "${BLUE}=== Task Progress by Issue ===${NC}"
    echo
    
    # Get all issues with implementation label
    gh issue list --repo "$REPO" --label "implementation" --limit 100 --json number,title,body,state | \
    jq -r '.[] | @json' | while read -r issue; do
        local number=$(echo "$issue" | jq -r '.number')
        local title=$(echo "$issue" | jq -r '.title')
        local body=$(echo "$issue" | jq -r '.body')
        local state=$(echo "$issue" | jq -r '.state')
        
        # Count tasks
        local total_tasks=$(echo "$body" | grep -c "^- \[[ x]\]" || true)
        local completed_tasks=$(echo "$body" | grep -c "^- \[x\]" || true)
        
        if [[ $total_tasks -gt 0 ]]; then
            local status_icon="○"
            local status_color="$YELLOW"
            if [[ "$state" == "CLOSED" ]]; then
                status_icon="✓"
                status_color="$GREEN"
            fi
            
            printf "${status_color}%s${NC} #%-4d %-35s " "$status_icon" "$number" "${title:0:35}"
            progress_bar "$completed_tasks" "$total_tasks"
            echo " ($completed_tasks/$total_tasks)"
        fi
    done
    echo
}

# Overall statistics
show_statistics() {
    echo -e "${BLUE}=== Overall Statistics ===${NC}"
    echo
    
    local total_milestones=$(gh api "/repos/$REPO/milestones" --jq '. | length')
    local closed_milestones=$(gh api "/repos/$REPO/milestones?state=closed" --jq '. | length')
    
    local total_issues=$(gh issue list --repo "$REPO" --label "implementation" --limit 200 --json number | jq '. | length')
    local closed_issues=$(gh issue list --repo "$REPO" --label "implementation" --state closed --limit 200 --json number | jq '. | length')
    
    echo "Milestones: $closed_milestones/$total_milestones completed"
    echo "Issues: $closed_issues/$total_issues completed"
    
    # Calculate overall progress
    local overall_percent=0
    if [[ $total_issues -gt 0 ]]; then
        overall_percent=$((closed_issues * 100 / total_issues))
    fi
    
 nvim scripts/github/project_management.sh
    echo
    echo -n "Overall Progress: "
    progress_bar "$closed_issues" "$total_issues"
    echo
}

# Main
main() {
    clear
    echo -e "${BLUE}GitHub Project Progress Report${NC}"
    echo -e "${BLUE}Repository: $REPO${NC}"
    echo "Generated: $(date)"
    echo "================================================"
    echo
    
    show_milestone_progress
    show_task_progress
    show_statistics
}

main "$@"
