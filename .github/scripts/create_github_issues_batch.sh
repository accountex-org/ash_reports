#!/bin/bash

# Batch script to create GitHub issues from implementation tasks
# This version creates issues more efficiently using GitHub's batch API

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install it with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo -e "${RED}Error: Could not determine repository${NC}"
    exit 1
fi

OWNER=$(echo $REPO | cut -d'/' -f1)
REPO_NAME=$(echo $REPO | cut -d'/' -f2)

echo -e "${GREEN}Batch creating issues for: $REPO${NC}"
echo ""

# Create project board for tracking
create_project_board() {
    echo -e "${BLUE}Creating project board for AshReports...${NC}"
    
    # Check if project exists
    existing_project=$(gh project list --owner $OWNER --format json | jq -r '.projects[] | select(.title == "AshReports Implementation") | .number')
    
    if [ -z "$existing_project" ]; then
        # Create new project
        project_num=$(gh project create --owner $OWNER --title "AshReports Implementation" --format json | jq -r '.number')
        echo -e "${GREEN}Created project board #$project_num${NC}"
        
        # Add custom fields
        gh project field-create $project_num --owner $OWNER --name "Phase" --data-type "SINGLE_SELECT" --single-select-options "Phase 1,Phase 2,Phase 3,Phase 4,Phase 5,Phase 6,Phase 7,Phase 8,Phase 9,Phase 10,Phase 11,Phase 12"
        gh project field-create $project_num --owner $OWNER --name "Complexity" --data-type "SINGLE_SELECT" --single-select-options "Low,Medium,High"
        gh project field-create $project_num --owner $OWNER --name "Priority" --data-type "SINGLE_SELECT" --single-select-options "P1,P2,P3,P4"
    else
        echo -e "${YELLOW}Project board already exists (#$existing_project)${NC}"
        project_num=$existing_project
    fi
    
    echo $project_num
}

# Generate JSON file with all issues
generate_issues_json() {
    local output_file="/tmp/ash_reports_issues.json"
    
    echo -e "${BLUE}Generating issues JSON...${NC}" >&2
    
    # Start JSON array
    echo "[" > $output_file
    
    local first=true
    local task_num=0
    
    # Process each task
    while IFS= read -r line; do
        if [[ $line =~ ^([0-9]+)\.[[:space:]]+\[Phase[[:space:]]([0-9]+)\.([0-9]+)\][[:space:]](.+)$ ]]; then
            task_num="${BASH_REMATCH[1]}"
            phase="${BASH_REMATCH[2]}"
            subsection="${BASH_REMATCH[3]}"
            task="${BASH_REMATCH[4]}"
            
            # Escape special characters in task description
            task=$(echo "$task" | sed 's/"/\\"/g' | sed "s/'/\\'/g")
            
            # Determine complexity based on task
            complexity="Medium"
            if [[ $task =~ ^(Create|Add|Implement basic) ]]; then
                complexity="Low"
            elif [[ $task =~ (system|engine|integration|optimization) ]]; then
                complexity="High"
            fi
            
            # Determine priority (earlier phases = higher priority)
            priority="P2"
            if [ $phase -le 3 ]; then
                priority="P1"
            elif [ $phase -ge 10 ]; then
                priority="P3"
            fi
            
            # Create title
            title="[Phase $phase.$subsection] $task"
            if [ ${#title} -gt 100 ]; then
                title="${title:0:97}..."
            fi
            
            # Create body
            body="## Task #$task_num
$task

## Phase Information
- **Phase**: $phase
- **Section**: $phase.$subsection
- **Complexity**: $complexity
- **Priority**: $priority

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Unit tests added (if applicable)
- [ ] Integration tests added (if applicable)
- [ ] Documentation updated
- [ ] Code reviewed

## Implementation Notes
_Add implementation details here_

## Related Tasks
_Link to related issues_"
            
            # Escape newlines and other special characters in body for JSON
            body_json=$(echo "$body" | jq -Rs .)
            
            # Add comma if not first item
            if [ "$first" = false ]; then
                echo "," >> $output_file
            fi
            first=false
            
            # Add issue JSON
            cat >> $output_file << EOF
  {
    "title": "$title",
    "body": $body_json,
    "labels": ["phase-$phase", "complexity:$complexity", "priority:$priority"],
    "phase": $phase,
    "subsection": "$subsection",
    "task_number": $task_num
  }
EOF
        fi
    done < /home/pcharbon/code/extensions/ash_reports/planning/implementation_tasks.md
    
    # Close JSON array
    echo "" >> $output_file
    echo "]" >> $output_file
    
    echo -e "${GREEN}Generated JSON with $(jq length $output_file) issues${NC}" >&2
    echo $output_file
}

# Create labels
create_all_labels() {
    echo -e "${BLUE}Creating labels...${NC}"
    
    # Phase labels
    for i in {1..12}; do
        gh label create "phase-$i" --description "Phase $i tasks" --color "$(printf '%02X%02X%02X' $((i*20)) $((i*15)) $((255-i*20)))" 2>/dev/null || true
    done
    
    # Complexity labels
    gh label create "complexity:Low" --description "Low complexity task" --color "00FF00" 2>/dev/null || true
    gh label create "complexity:Medium" --description "Medium complexity task" --color "FFFF00" 2>/dev/null || true
    gh label create "complexity:High" --description "High complexity task" --color "FF0000" 2>/dev/null || true
    
    # Priority labels
    gh label create "priority:P1" --description "Highest priority" --color "FF0000" 2>/dev/null || true
    gh label create "priority:P2" --description "High priority" --color "FF8800" 2>/dev/null || true
    gh label create "priority:P3" --description "Medium priority" --color "FFFF00" 2>/dev/null || true
    gh label create "priority:P4" --description "Low priority" --color "00FF00" 2>/dev/null || true
    
    echo -e "${GREEN}Labels created${NC}"
}

# Create issues from JSON
create_issues_from_json() {
    local json_file=$1
    local phase_filter=$2
    
    # Get all milestones
    echo -e "${BLUE}Fetching milestones...${NC}"
    gh api repos/$REPO/milestones --paginate > /tmp/milestones.json
    
    # Check if milestones exist
    milestone_count=$(jq length /tmp/milestones.json)
    if [ "$milestone_count" -eq 0 ]; then
        echo -e "${YELLOW}Warning: No milestones found!${NC}"
        echo -e "${YELLOW}Run './scripts/create_github_milestones.sh' first to create milestones${NC}"
        echo ""
    fi
    
    # Process issues
    local total=$(jq length $json_file)
    local created=0
    local skipped=0
    
    echo -e "${YELLOW}Processing $total issues...${NC}"
    
    for i in $(seq 0 $((total - 1))); do
        phase=$(jq -r ".[$i].phase" $json_file)
        
        # Skip if filtering by phase
        if [ ! -z "$phase_filter" ] && [ "$phase" != "$phase_filter" ]; then
            continue
        fi
        
        title=$(jq -r ".[$i].title" $json_file)
        body=$(jq -r ".[$i].body" $json_file)
        labels=$(jq -r ".[$i].labels | join(\",\")" $json_file)
        
        # Check if issue exists
        existing=$(gh issue list --search "\"$title\" in:title" --json number --jq '.[0].number' 2>/dev/null)
        
        if [ ! -z "$existing" ]; then
            echo -e "[$((i+1))/$total] Issue exists (#$existing): $title"
            ((skipped++))
            continue
        fi
        
        # Get milestone for this phase
        milestone_title=$(jq -r ".[] | select(.title | startswith(\"Phase $phase:\")) | .title" /tmp/milestones.json | head -1)
        
        # Create issue
        echo -e "[$((i+1))/$total] Creating: $title"
        
        if [ ! -z "$milestone_title" ]; then
            result=$(gh issue create \
                --title "$title" \
                --body "$body" \
                --label "$labels" \
                --milestone "$milestone_title" 2>&1)
            exit_code=$?
        else
            result=$(gh issue create \
                --title "$title" \
                --body "$body" \
                --label "$labels" 2>&1)
            exit_code=$?
        fi
        
        if [ $exit_code -eq 0 ]; then
            ((created++))
            echo -e "  ${GREEN}✓ Created: $result${NC}"
        else
            echo -e "  ${RED}Failed: $result${NC}"
        fi
        
        # Rate limit protection
        if [ $((created % 10)) -eq 0 ] && [ $created -gt 0 ]; then
            echo -e "${YELLOW}Created $created issues, pausing to avoid rate limits...${NC}"
            sleep 2
        fi
    done
    
    echo ""
    echo -e "${GREEN}Summary:${NC}"
    echo -e "  Created: $created issues"
    echo -e "  Skipped: $skipped issues (already exist)"
    
    # Cleanup
    rm -f /tmp/milestones.json
}

# Main menu
show_menu() {
    echo "GitHub Issue Creation Options:"
    echo ""
    echo "  1) Create all 186 issues"
    echo "  2) Create issues for specific phase"
    echo "  3) Create project board only"
    echo "  4) Generate issues preview (JSON)"
    echo "  5) Show phase summary"
    echo ""
    read -p "Choose an option (1-5): " choice
    
    case $choice in
        1)
            create_all_labels
            json_file=$(generate_issues_json)
            create_issues_from_json $json_file
            
            read -p "Create project board and add issues? (y/n): " add_to_project
            if [ "$add_to_project" = "y" ]; then
                project_num=$(create_project_board)
                echo "You can now add issues to the project board using the GitHub UI"
            fi
            ;;
            
        2)
            read -p "Enter phase number (1-12): " phase
            if [ $phase -lt 1 ] || [ $phase -gt 12 ]; then
                echo -e "${RED}Invalid phase number${NC}"
                exit 1
            fi
            
            create_all_labels
            json_file=$(generate_issues_json)
            create_issues_from_json $json_file $phase
            ;;
            
        3)
            create_project_board
            ;;
            
        4)
            json_file=$(generate_issues_json)
            echo ""
            echo -e "${GREEN}Preview saved to: $json_file${NC}"
            echo "First 3 issues:"
            jq '.[0:3]' $json_file
            ;;
            
        5)
            echo -e "${BLUE}Phase Summary:${NC}"
            echo ""
            for i in {1..12}; do
                count=$(grep -c "\[Phase $i\." /home/pcharbon/code/extensions/ash_reports/planning/implementation_tasks.md)
                printf "Phase %2d: %3d tasks\n" $i $count
            done
            echo ""
            echo "Total: 186 tasks"
            ;;
            
        *)
            echo -e "${RED}Invalid option${NC}"
            exit 1
            ;;
    esac
}

# Run the menu
show_menu

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Useful links:"
echo "  Issues: https://github.com/$REPO/issues"
echo "  Milestones: https://github.com/$REPO/milestones"
echo "  Projects: https://github.com/$OWNER/projects"