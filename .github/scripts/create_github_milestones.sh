#!/bin/bash

# Script to create GitHub milestones from implementation phases
# Requires: gh (GitHub CLI) to be installed and authenticated
# 
# Usage: ./create_github_milestones.sh [OPTIONS] [plan_file]
#   
# Options:
#   -h, --help              Show this help message
#   -d, --dry-run          Show what would be created without actually creating
#   
# Arguments:
#   plan_file               Optional path to implementation plan (default: auto-detect)
#   
# Supported plans:
#   - planning/implementation_plan.md (11 phases)
#   - planning/detailed_implementation_plan.md (14 phases)
#
# Examples:
#   ./create_github_milestones.sh                                    # Auto-detect plan
#   ./create_github_milestones.sh planning/detailed_implementation_plan.md
#   ./create_github_milestones.sh --dry-run                         # Preview only

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global options
DRY_RUN=false

# Function to show help
show_help() {
    echo "Create GitHub milestones from implementation plan phases"
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
    echo "Supported plans:"
    echo "  - planning/implementation_plan.md (11 phases)"
    echo "  - planning/detailed_implementation_plan.md (14 phases)"
    echo ""
    echo "Examples:"
    echo "  $0                                            # Auto-detect plan"
    echo "  $0 planning/detailed_implementation_plan.md   # Use specific plan"
    echo "  $0 --dry-run                                  # Preview only"
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

echo -e "${GREEN}Creating milestones for repository: $REPO${NC}"
echo -e "${CYAN}Reading phases from: $(basename "$PLAN_FILE")${NC}"
echo ""

# Function to calculate due date (weeks from now)
calculate_due_date() {
    local weeks=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        date -v +"${weeks}w" +"%Y-%m-%d"
    else
        # Linux
        date -d "+${weeks} weeks" +"%Y-%m-%d"
    fi
}

# Function to extract phase information from implementation plan
parse_implementation_plan() {
    local plan_file="$1"
    local current_phase=""
    local current_title=""
    local current_description=""
    local current_tasks=""
    local in_objectives=false
    local week_counter=2
    
    echo -e "${BLUE}Parsing implementation plan...${NC}"
    
    while IFS= read -r line; do
        # Detect phase headers
        if [[ $line =~ ^##[[:space:]]*Phase[[:space:]]+([0-9]+):[[:space:]]*(.*)$ ]]; then
            # Save previous phase if exists
            if [ ! -z "$current_phase" ]; then
                create_milestone_from_data "$current_phase" "$current_title" "$current_description" "$current_tasks" "$week_counter"
                ((week_counter += 2))
            fi
            
            # Start new phase
            current_phase="${BASH_REMATCH[1]}"
            current_title="${BASH_REMATCH[2]}"
            current_description=""
            current_tasks=""
            in_objectives=false
            
        # Detect objectives section
        elif [[ $line =~ ^###[[:space:]]*Objectives ]]; then
            in_objectives=true
            
        # End of objectives section
        elif [[ $line =~ ^###[[:space:]]* ]] && [[ ! $line =~ Objectives ]]; then
            in_objectives=false
            
        # Collect objectives as description
        elif $in_objectives && [[ $line =~ ^-[[:space:]]*(.*) ]]; then
            if [ -z "$current_description" ]; then
                current_description="${BASH_REMATCH[1]}"
            else
                current_description="$current_description"$'\n'"${BASH_REMATCH[1]}"
            fi
            
        # Collect top-level tasks (deliverable sections)
        elif [[ $line =~ ^####[[:space:]]*[0-9]+\.[0-9]+[[:space:]]*(.*) ]]; then
            if [ -z "$current_tasks" ]; then
                current_tasks="- ${BASH_REMATCH[1]}"
            else
                current_tasks="$current_tasks"$'\n'"- ${BASH_REMATCH[1]}"
            fi
        fi
        
    done < "$plan_file"
    
    # Handle last phase
    if [ ! -z "$current_phase" ]; then
        create_milestone_from_data "$current_phase" "$current_title" "$current_description" "$current_tasks" "$week_counter"
    fi
}

# Function to create milestone from parsed data
create_milestone_from_data() {
    local phase_num="$1"
    local title="$2" 
    local description="$3"
    local tasks="$4"
    local weeks="$5"
    
    # Build full description
    local full_description="$description"
    if [ ! -z "$tasks" ]; then
        if [ ! -z "$full_description" ]; then
            full_description="$full_description"$'\n\n'"Key deliverables:"$'\n'"$tasks"
        else
            full_description="Key deliverables:"$'\n'"$tasks"
        fi
    fi
    
    create_milestone "$phase_num" "$title" "$full_description" "$(calculate_due_date $weeks)"
}

# Create milestones
create_milestone() {
    local number=$1
    local title=$2
    local description=$3
    local due_date=$4
    
    echo -e "${YELLOW}Milestone: Phase $number - $title${NC}"
    echo -e "  Due date: ${CYAN}$due_date${NC}"
    
    if $DRY_RUN; then
        echo -e "  ${BLUE}[DRY RUN] Would create milestone${NC}"
        # Show description preview in dry run
        if [ ${#description} -gt 100 ]; then
            echo -e "  Description: ${description:0:100}..."
        else
            echo -e "  Description: $description"
        fi
        echo ""
        return
    fi
    
    # Check if milestone already exists
    existing=$(gh api repos/$REPO/milestones --jq ".[] | select(.title == \"Phase $number: $title\") | .number" 2>/dev/null)
    
    if [ ! -z "$existing" ]; then
        echo -e "  ${YELLOW}⚠ Milestone already exists (number: $existing), skipping...${NC}"
        echo ""
        return
    fi
    
    # Create the milestone
    result=$(gh api repos/$REPO/milestones \
        --method POST \
        -f title="Phase $number: $title" \
        -f description="$description" \
        -f due_on="${due_date}T23:59:59Z" \
        2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Created successfully${NC}"
    else
        echo -e "  ${RED}✗ Failed to create: $result${NC}"
    fi
    echo ""
}

# Parse and create milestones from implementation plan
echo "Creating milestones from implementation plan..."
echo ""

parse_implementation_plan "$PLAN_FILE"

if $DRY_RUN; then
    echo -e "${GREEN}Dry run complete!${NC}"
    echo -e "${BLUE}To actually create these milestones, run without --dry-run${NC}"
else
    echo -e "${GREEN}Milestone creation complete!${NC}"
    echo ""
    echo "View your milestones at: https://github.com/$REPO/milestones"
fi