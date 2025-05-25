#!/bin/bash

# Script to create GitHub issues from implementation tasks
# Requires: gh (GitHub CLI) to be installed and authenticated

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

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub${NC}"
    echo -e "${YELLOW}Please run: ${GREEN}gh auth login${NC}"
    echo ""
    echo "This will open a browser to authenticate with GitHub."
    echo "Make sure you have the necessary permissions for this repository."
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Get repository name
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo -e "${RED}Error: Could not determine repository. Make sure you're in a GitHub repo.${NC}"
    exit 1
fi

echo -e "${GREEN}Creating issues for repository: $REPO${NC}"
echo ""

# Function to get milestone number by phase
get_milestone_number() {
    local phase=$1
    local milestone_title="Phase $phase:"
    
    # Get milestone number
    milestone_num=$(gh api repos/$REPO/milestones --jq ".[] | select(.title | startswith(\"$milestone_title\")) | .number" 2>/dev/null | head -1)
    
    if [ -z "$milestone_num" ]; then
        echo "0"
    else
        echo "$milestone_num"
    fi
}

# Function to create an issue
create_issue() {
    local phase=$1
    local subsection=$2
    local task=$3
    local milestone_num=$4
    
    # Create label for the phase
    local label="phase-$phase"
    
    # Create title (truncate if too long)
    local title="[Phase $phase.$subsection] $task"
    if [ ${#title} -gt 100 ]; then
        title="${title:0:97}..."
    fi
    
    # Create body with more details
    local body="## Task
$task

## Phase
Phase $phase, Section $subsection

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Tests added (if applicable)
- [ ] Documentation updated (if applicable)

## Notes
_Add implementation notes here_"
    
    echo -e "${YELLOW}Creating issue: $title${NC}"
    
    # Check if issue already exists (by title)
    existing=$(gh issue list --search "\"$title\" in:title" --json number --jq '.[0].number' 2>/dev/null)
    
    if [ ! -z "$existing" ]; then
        echo -e "  Issue already exists (#$existing), skipping..."
        return
    fi
    
    # Create the issue
    if [ "$milestone_num" != "0" ]; then
        result=$(gh issue create \
            --title "$title" \
            --body "$body" \
            --label "$label" \
            --milestone "$milestone_num" \
            2>&1)
    else
        result=$(gh issue create \
            --title "$title" \
            --body "$body" \
            --label "$label" \
            2>&1)
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Created: $result${NC}"
    else
        echo -e "  ${RED}✗ Failed to create: $result${NC}"
    fi
}

# Function to ensure phase labels exist
create_phase_labels() {
    echo -e "${BLUE}Ensuring phase labels exist...${NC}"
    
    for i in {1..12}; do
        label="phase-$i"
        
        # Check if label exists
        existing=$(gh label list --search "$label" --json name --jq '.[0].name' 2>/dev/null)
        
        if [ -z "$existing" ]; then
            echo -e "Creating label: $label"
            gh label create "$label" --description "Phase $i tasks" --color "$(printf '%06X' $((RANDOM % 16777215)))"
        fi
    done
    echo ""
}

# Main execution
echo "Do you want to create ALL 186 issues at once? This might take a while."
echo "Alternatively, you can create issues for specific phases."
echo ""
echo "Options:"
echo "  1) Create all issues"
echo "  2) Create issues for specific phase(s)"
echo "  3) Show phase summary and exit"
echo ""
read -p "Choose an option (1-3): " choice

# First, ensure labels exist
create_phase_labels

case $choice in
    1)
        echo -e "${YELLOW}Creating all 186 issues...${NC}"
        echo ""
        
        # Read the tasks file and create issues
        phase=""
        subsection=""
        milestone_num="0"
        
        while IFS= read -line; do
            if [[ $line =~ ^\[Phase\ ([0-9]+)\.([0-9]+)\]\ (.+)$ ]]; then
                new_phase="${BASH_REMATCH[1]}"
                subsection="${BASH_REMATCH[2]}"
                task="${BASH_REMATCH[3]}"
                
                # Get milestone number if phase changed
                if [ "$new_phase" != "$phase" ]; then
                    phase="$new_phase"
                    milestone_num=$(get_milestone_number "$phase")
                    
                    if [ "$milestone_num" == "0" ]; then
                        echo -e "${RED}Warning: No milestone found for Phase $phase${NC}"
                    else
                        echo -e "${GREEN}Using milestone #$milestone_num for Phase $phase${NC}"
                    fi
                fi
                
                create_issue "$phase" "$subsection" "$task" "$milestone_num"
                
                # Add a small delay to avoid rate limiting
                sleep 0.5
            fi
        done < <(grep -E '^\[Phase [0-9]+\.[0-9]+\]' /home/pcharbon/code/extensions/ash_reports/planning/implementation_tasks.md | sed 's/^[0-9]\+\. //')
        ;;
        
    2)
        read -p "Enter phase number(s) to create issues for (e.g., '1' or '1 2 3'): " phases
        
        for phase in $phases; do
            echo -e "${YELLOW}Creating issues for Phase $phase...${NC}"
            
            milestone_num=$(get_milestone_number "$phase")
            if [ "$milestone_num" == "0" ]; then
                echo -e "${RED}Warning: No milestone found for Phase $phase${NC}"
            else
                echo -e "${GREEN}Using milestone #$milestone_num for Phase $phase${NC}"
            fi
            
            # Extract tasks for this phase
            while IFS= read -r line; do
                if [[ $line =~ ^\[Phase\ $phase\.([0-9]+)\]\ (.+)$ ]]; then
                    subsection="${BASH_REMATCH[1]}"
                    task="${BASH_REMATCH[2]}"
                    
                    create_issue "$phase" "$subsection" "$task" "$milestone_num"
                    sleep 0.5
                fi
            done < <(grep -E "^\[Phase $phase\.[0-9]+\]" /home/pcharbon/code/extensions/ash_reports/planning/implementation_tasks.md | sed 's/^[0-9]\+\. //')
        done
        ;;
        
    3)
        echo -e "${BLUE}Phase Summary:${NC}"
        echo ""
        for i in {1..12}; do
            count=$(grep -c "^\[Phase $i\." /home/pcharbon/code/extensions/ash_reports/planning/implementation_tasks.md | sed 's/^[0-9]\+\. //')
            echo "Phase $i: $count tasks"
        done
        echo ""
        echo "Total: 186 tasks"
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Issue creation complete!${NC}"
echo ""
echo "View your issues at: https://github.com/$REPO/issues"
echo "View by milestone at: https://github.com/$REPO/milestones"