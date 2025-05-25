#!/bin/bash

# Batch script to create GitHub issues from implementation plan tasks
# This version creates issues more efficiently by parsing implementation plans directly
#
# Usage: ./create_github_issues_batch.sh [OPTIONS] [plan_file]
#   
# Options:
#   -h, --help              Show this help message
#   -d, --dry-run          Show what would be created without actually creating
#   -p, --phase PHASE      Only create issues for specific phase (e.g., -p 1)
#   
# Arguments:
#   plan_file               Optional path to implementation plan (default: auto-detect)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global options
DRY_RUN=false
PHASE_FILTER=""

# Function to show help
show_help() {
    echo "Create GitHub issues from implementation plan tasks"
    echo ""
    echo "Usage: $0 [OPTIONS] [plan_file]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --dry-run       Show what would be created without actually creating"
    echo "  -p, --phase PHASE   Only create issues for specific phase (e.g., -p 1)"
    echo ""
    echo "Arguments:"
    echo "  plan_file           Optional path to implementation plan (default: auto-detect)"
    echo ""
    echo "Supported plans:"
    echo "  - planning/implementation_plan.md (11 phases)"
    echo "  - planning/detailed_implementation_plan.md (14 phases)"
    echo ""
    echo "Examples:"
    echo "  $0                                            # Auto-detect plan, create all issues"
    echo "  $0 --phase 1                                  # Only create Phase 1 issues"
    echo "  $0 --dry-run                                  # Preview issues without creating"
    echo "  $0 planning/detailed_implementation_plan.md   # Use specific plan"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -p|--phase)
            PHASE_FILTER="$2"
            if ! [[ "$PHASE_FILTER" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: Phase must be a number${NC}"
                exit 1
            fi
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            # This should be the plan file
            if [ -z "$PLAN_FILE_ARG" ]; then
                PLAN_FILE_ARG="$1"
            else
                echo -e "${RED}Error: Too many arguments${NC}"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub${NC}"
    echo -e "${YELLOW}Please run: ${GREEN}gh auth login${NC}"
    echo ""
    echo "This will open a browser to authenticate with GitHub."
    echo "Make sure you have the necessary permissions for this repository."
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

# Determine which implementation plan to use
PLAN_FILE="$PLAN_FILE_ARG"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Auto-detect plan file if not provided
if [ -z "$PLAN_FILE" ]; then
    if [ -f "$PROJECT_ROOT/planning/detailed_implementation_plan.md" ]; then
        PLAN_FILE="$PROJECT_ROOT/planning/detailed_implementation_plan.md"
        echo -e "${BLUE}Auto-detected: detailed_implementation_plan.md (14 phases)${NC}"
    elif [ -f "$PROJECT_ROOT/planning/implementation_plan.md" ]; then
        PLAN_FILE="$PROJECT_ROOT/planning/implementation_plan.md"
        echo -e "${BLUE}Auto-detected: implementation_plan.md (11 phases)${NC}"
    else
        echo -e "${RED}Error: No implementation plan found${NC}"
        echo "Please create one of:"
        echo "  - planning/detailed_implementation_plan.md"
        echo "  - planning/implementation_plan.md"
        exit 1
    fi
else
    # Handle relative paths
    if [[ "$PLAN_FILE" != /* ]]; then
        PLAN_FILE="$PROJECT_ROOT/$PLAN_FILE"
    fi
    
    if [ ! -f "$PLAN_FILE" ]; then
        echo -e "${RED}Error: Plan file not found: $PLAN_FILE${NC}"
        exit 1
    fi
    echo -e "${BLUE}Using specified plan: $(basename "$PLAN_FILE")${NC}"
fi

echo -e "${GREEN}Batch creating issues for: $REPO${NC}"
echo -e "${CYAN}Reading tasks from: $(basename "$PLAN_FILE")${NC}"
if [ ! -z "$PHASE_FILTER" ]; then
    echo -e "${YELLOW}Filtering to Phase $PHASE_FILTER only${NC}"
fi
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

# Generate JSON file with all issues from implementation plan
generate_issues_json() {
    local output_file="/tmp/ash_reports_issues.json"
    
    echo -e "${BLUE}Parsing implementation plan for tasks...${NC}" >&2
    
    # Start JSON array
    echo "[" > $output_file
    
    local first=true
    local task_num=0
    local current_phase=""
    local current_phase_title=""
    local current_section=""
    local current_section_title=""
    local in_deliverables=false
    
    # Parse the implementation plan file
    while IFS= read -r line; do
        # Detect phase headers
        if [[ $line =~ ^##[[:space:]]*Phase[[:space:]]+([0-9]+):[[:space:]]*(.*)$ ]]; then
            current_phase="${BASH_REMATCH[1]}"
            current_phase_title="${BASH_REMATCH[2]}"
            current_section=""
            current_section_title=""
            in_deliverables=false
            
            # Skip if filtering by phase
            if [ ! -z "$PHASE_FILTER" ] && [ "$current_phase" != "$PHASE_FILTER" ]; then
                continue
            fi
            
        # Detect section headers (deliverables)
        elif [[ $line =~ ^###[[:space:]]*[0-9]+\.[0-9]+[[:space:]]*(.*) ]]; then
            current_section_title="${BASH_REMATCH[1]}"
            in_deliverables=true
            
        # Detect other section headers (end deliverables)
        elif [[ $line =~ ^###[[:space:]]* ]] && [[ ! $line =~ ^###[[:space:]]*[0-9]+\.[0-9]+ ]]; then
            in_deliverables=false
            
        # Collect task items from deliverables sections
        elif $in_deliverables && [[ $line =~ ^-[[:space:]]*\[[[:space:]]*\][[:space:]]*(.*) ]]; then
            # Skip if filtering by phase and not in current phase
            if [ ! -z "$PHASE_FILTER" ] && [ "$current_phase" != "$PHASE_FILTER" ]; then
                continue
            fi
            
            task="${BASH_REMATCH[1]}"
            ((task_num++))
            
            # Escape special characters in task description
            task_escaped=$(echo "$task" | sed 's/"/\\"/g' | sed "s/'/\\'/g")
            
            # Determine complexity based on task content
            complexity="Medium"
            if [[ $task =~ ^(Update|Configure|Set up|Create.*struct|Add.*schema|Basic) ]]; then
                complexity="Low"
            elif [[ $task =~ (system|engine|integration|optimization|complete|comprehensive|advanced) ]]; then
                complexity="High"
            fi
            
            # Determine priority (earlier phases = higher priority)
            priority="P2"
            if [ $current_phase -le 3 ]; then
                priority="P1"
            elif [ $current_phase -ge 10 ]; then
                priority="P3"
            fi
            
            # Create title
            title="[Phase $current_phase] $task"
            if [ ${#title} -gt 100 ]; then
                title="${title:0:97}..."
            fi
            
            # Create body
            body="## Task
$task

## Phase Information
- **Phase**: $current_phase - $current_phase_title
- **Section**: $current_section_title
- **Complexity**: $complexity
- **Priority**: $priority

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Unit tests added and passing
- [ ] Integration tests added and passing (if applicable)
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
    "labels": ["phase-$current_phase", "complexity:$complexity", "priority:$priority"],
    "phase": $current_phase,
    "section": "$current_section_title",
    "task_number": $task_num
  }
EOF
        fi
        
    done < "$PLAN_FILE"
    
    # Close JSON array
    echo "" >> $output_file
    echo "]" >> $output_file
    
    local total_issues=$(jq length $output_file 2>/dev/null || echo "0")
    echo -e "${GREEN}Generated JSON with $total_issues issues${NC}" >&2
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
    
    # Process issues
    local total=$(jq length $json_file)
    local created=0
    local skipped=0
    local would_create=0
    
    echo -e "${YELLOW}Processing $total issues...${NC}"
    
    if ! $DRY_RUN; then
        # Get all milestones for actual creation
        echo -e "${BLUE}Fetching milestones...${NC}"
        gh api repos/$REPO/milestones --paginate > /tmp/milestones.json
        
        # Check if milestones exist
        milestone_count=$(jq length /tmp/milestones.json)
        if [ "$milestone_count" -eq 0 ]; then
            echo -e "${YELLOW}Warning: No milestones found!${NC}"
            echo -e "${YELLOW}Run './scripts/create_github_milestones.sh' first to create milestones${NC}"
            echo ""
        fi
    fi
    
    for i in $(seq 0 $((total - 1))); do
        phase=$(jq -r ".[$i].phase" $json_file)
        
        # Skip if filtering by phase
        if [ ! -z "$phase_filter" ] && [ "$phase" != "$phase_filter" ]; then
            continue
        fi
        
        title=$(jq -r ".[$i].title" $json_file)
        body=$(jq -r ".[$i].body" $json_file)
        labels=$(jq -r ".[$i].labels | join(\",\")" $json_file)
        
        if $DRY_RUN; then
            echo -e "[$((i+1))/$total] ${BLUE}[DRY RUN]${NC} Would create: $title"
            echo -e "  Labels: ${CYAN}$labels${NC}"
            # Show first line of body as preview
            preview=$(echo "$body" | head -1)
            echo -e "  Preview: $preview"
            ((would_create++))
            continue
        fi
        
        # Check if issue exists
        existing=$(gh issue list --search "\"$title\" in:title" --json number --jq '.[0].number' 2>/dev/null)
        
        if [ ! -z "$existing" ]; then
            echo -e "[$((i+1))/$total] ${YELLOW}Issue exists (#$existing):${NC} $title"
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
            echo -e "  ${RED}✗ Failed: $result${NC}"
        fi
        
        # Rate limit protection
        if [ $((created % 10)) -eq 0 ] && [ $created -gt 0 ]; then
            echo -e "${YELLOW}Created $created issues, pausing to avoid rate limits...${NC}"
            sleep 2
        fi
    done
    
    echo ""
    if $DRY_RUN; then
        echo -e "${GREEN}Dry Run Summary:${NC}"
        echo -e "  Would create: $would_create issues"
        echo -e "${BLUE}To actually create these issues, run without --dry-run${NC}"
    else
        echo -e "${GREEN}Summary:${NC}"
        echo -e "  Created: $created issues"
        echo -e "  Skipped: $skipped issues (already exist)"
        
        # Cleanup
        rm -f /tmp/milestones.json
    fi
}

# Show phase summary
show_phase_summary() {
    echo -e "${BLUE}Phase Summary from $(basename "$PLAN_FILE"):${NC}"
    echo ""
    
    # Count tasks per phase
    local phase_counts=()
    local total_tasks=0
    
    for phase in {1..20}; do  # Support up to 20 phases
        local count=$(grep -c "^-[[:space:]]*\[[[:space:]]*\]" "$PLAN_FILE" | grep -E "Phase[[:space:]]+$phase:" | wc -l)
        if [ $count -gt 0 ]; then
            phase_counts[$phase]=$count
            ((total_tasks += count))
        fi
    done
    
    # Display summary
    for phase in "${!phase_counts[@]}"; do
        printf "Phase %2d: %3d tasks\n" $phase ${phase_counts[$phase]}
    done
    echo ""
    echo "Total: $total_tasks tasks from implementation plan"
}

# Main execution logic
main() {
    echo -e "${BLUE}Creating GitHub issues from implementation plan${NC}"
    echo ""
    
    # Create labels first
    if ! $DRY_RUN; then
        create_all_labels
    fi
    
    # Generate issues JSON
    json_file=$(generate_issues_json)
    
    if [ ! -f "$json_file" ]; then
        echo -e "${RED}Error: Failed to generate issues JSON${NC}"
        exit 1
    fi
    
    # Show summary first
    local total_issues=$(jq length $json_file 2>/dev/null || echo "0")
    echo ""
    echo -e "${GREEN}Found $total_issues tasks to create as issues${NC}"
    
    if [ ! -z "$PHASE_FILTER" ]; then
        echo -e "${YELLOW}Filtered to Phase $PHASE_FILTER only${NC}"
    fi
    
    if $DRY_RUN; then
        echo -e "${BLUE}Running in dry-run mode - no issues will be created${NC}"
    fi
    echo ""
    
    # Create issues
    create_issues_from_json "$json_file" "$PHASE_FILTER"
    
    # Cleanup
    rm -f "$json_file"
}

# Run main execution
main

echo ""
if $DRY_RUN; then
    echo -e "${GREEN}Dry run completed!${NC}"
    echo -e "${BLUE}To actually create issues, run without --dry-run${NC}"
else
    echo -e "${GREEN}Issue creation completed!${NC}"
    echo ""
    echo "Useful links:"
    echo "  Issues: https://github.com/$REPO/issues"
    echo "  Milestones: https://github.com/$REPO/milestones"
    echo "  Projects: https://github.com/$OWNER/projects"
fi