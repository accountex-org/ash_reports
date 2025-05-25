#!/bin/bash

# Script to update GitHub project board status based on implementation plan progress
# This script reads completed checkboxes from implementation plan files and updates corresponding GitHub issues
#
# Usage: ./update_project_status.sh [OPTIONS] [plan_file]
#   
# Options:
#   -h, --help              Show this help message
#   -d, --dry-run          Show what would be updated without actually updating
#   -p, --phase PHASE      Only update issues for specific phase (e.g., -p 1)
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
    echo "Update GitHub project board status based on implementation plan progress"
    echo ""
    echo "Usage: $0 [OPTIONS] [plan_file]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --dry-run       Show what would be updated without actually updating"
    echo "  -p, --phase PHASE   Only update issues for specific phase (e.g., -p 1)"
    echo ""
    echo "Arguments:"
    echo "  plan_file           Optional path to implementation plan (default: auto-detect)"
    echo ""
    echo "Supported plans:"
    echo "  - planning/implementation_plan.md (11 phases)"
    echo "  - planning/detailed_implementation_plan.md (14 phases)"
    echo ""
    echo "Examples:"
    echo "  $0                                            # Auto-detect plan, update all phases"
    echo "  $0 --phase 1                                  # Only update Phase 1 issues"
    echo "  $0 --dry-run                                  # Preview updates without making changes"
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
                echo -e "${RED}Error: Phase must be a number${NC}" >&2
                exit 1
            fi
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            # This should be the plan file
            if [ -z "$PLAN_FILE_ARG" ]; then
                PLAN_FILE_ARG="$1"
            else
                echo -e "${RED}Error: Too many arguments${NC}" >&2
                echo "Use --help for usage information" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}" >&2
    echo "Install it from: https://cli.github.com/" >&2
    exit 1
fi

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub${NC}" >&2
    echo -e "${YELLOW}Please run: ${GREEN}gh auth login${NC}" >&2
    echo "" >&2
    echo "This will open a browser to authenticate with GitHub." >&2
    echo "Make sure you have the necessary permissions for this repository." >&2
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}" >&2
    echo "Install it with: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo -e "${RED}Error: Could not determine repository${NC}" >&2
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
        echo -e "${BLUE}Auto-detected: detailed_implementation_plan.md (14 phases)${NC}" >&2
    elif [ -f "$PROJECT_ROOT/planning/implementation_plan.md" ]; then
        PLAN_FILE="$PROJECT_ROOT/planning/implementation_plan.md"
        echo -e "${BLUE}Auto-detected: implementation_plan.md (11 phases)${NC}" >&2
    else
        echo -e "${RED}Error: No implementation plan found${NC}" >&2
        echo "Please create one of:" >&2
        echo "  - planning/detailed_implementation_plan.md" >&2
        echo "  - planning/implementation_plan.md" >&2
        exit 1
    fi
else
    # Handle relative paths
    if [[ "$PLAN_FILE" != /* ]]; then
        PLAN_FILE="$PROJECT_ROOT/$PLAN_FILE"
    fi
    
    if [ ! -f "$PLAN_FILE" ]; then
        echo -e "${RED}Error: Plan file not found: $PLAN_FILE${NC}" >&2
        exit 1
    fi
    echo -e "${BLUE}Using specified plan: $(basename "$PLAN_FILE")${NC}" >&2
fi

echo -e "${GREEN}Updating project status for: $REPO${NC}" >&2
echo -e "${CYAN}Reading completed tasks from: $(basename "$PLAN_FILE")${NC}" >&2
if [ ! -z "$PHASE_FILTER" ]; then
    echo -e "${YELLOW}Filtering to Phase $PHASE_FILTER only${NC}" >&2
fi
if $DRY_RUN; then
    echo -e "${BLUE}Running in dry-run mode - no issues will be updated${NC}" >&2
fi
echo "" >&2

# Function to find the project
find_project() {
    echo -e "${BLUE}Looking for AshReports project board...${NC}" >&2
    
    # Get all projects for the owner
    projects=$(gh project list --owner $OWNER --format json --limit 100 2>/dev/null)
    
    # Find AshReports Implementation project
    project_number=$(echo "$projects" | jq -r '.projects[] | select(.title == "AshReports Implementation") | .number' | head -1)
    
    if [ -z "$project_number" ]; then
        echo -e "${RED}Error: Could not find 'AshReports Implementation' project board${NC}" >&2
        echo -e "${YELLOW}Please create the project board first using create_github_issues_batch.sh${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}Found project board #$project_number${NC}" >&2
    echo $project_number
}

# Function to get project field IDs
get_field_ids() {
    local project_number=$1
    
    echo -e "${BLUE}Getting project field information...${NC}" >&2
    
    # Get project fields
    fields=$(gh project field-list $project_number --owner $OWNER --format json 2>/dev/null)
    
    # Get Status field ID
    status_field_id=$(echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .id')
    
    if [ -z "$status_field_id" ]; then
        echo -e "${RED}Error: Could not find 'Status' field in project${NC}" >&2
        exit 1
    fi
    
    # Get the option IDs for different statuses
    done_option_id=$(echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "Done" or .name == "done" or .name == "✅ Done" or .name == "Completed") | .id' | head -1)
    in_progress_option_id=$(echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "In Progress" or .name == "in progress" or .name == "🚀 In Progress") | .id' | head -1)
    
    if [ -z "$done_option_id" ]; then
        echo -e "${YELLOW}Warning: Could not find 'Done' option in Status field${NC}" >&2
        echo -e "${YELLOW}Available status options:${NC}" >&2
        echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[] | .name' >&2
        exit 1
    fi
    
    echo "$status_field_id:$done_option_id:$in_progress_option_id"
}

# Function to parse completed tasks from implementation plan
parse_completed_tasks() {
    local plan_file="$1"
    local phase_filter="$2"
    
    declare -a completed_tasks=()
    local current_phase=""
    local in_target_phase=false
    
    while IFS= read -r line; do
        # Check for phase headers
        if [[ $line =~ ^##[[:space:]]*Phase[[:space:]]+([0-9]+):[[:space:]]*(.*)$ ]]; then
            current_phase="${BASH_REMATCH[1]}"
            if [ -z "$phase_filter" ] || [ "$current_phase" = "$phase_filter" ]; then
                in_target_phase=true
            else
                in_target_phase=false
            fi
        # Check for completed checkboxes (marked with [x])
        elif [ "$in_target_phase" = true ] && [[ $line =~ ^-[[:space:]]*\[x\][[:space:]]*(.*)$ ]]; then
            task_description="${BASH_REMATCH[1]}"
            # Clean up the task description for better matching
            task_description=$(echo "$task_description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            completed_tasks+=("$task_description")
        fi
    done < "$plan_file"
    
    printf '%s\n' "${completed_tasks[@]}"
}

# Function to update issues to Done based on completed tasks
update_completed_tasks() {
    local project_number=$1
    local field_info=$2
    local status_field_id=$(echo $field_info | cut -d':' -f1)
    local done_option_id=$(echo $field_info | cut -d':' -f2)
    
    echo -e "${BLUE}Parsing completed tasks from implementation plan...${NC}" >&2
    
    # Get completed tasks from the plan file
    mapfile -t completed_tasks < <(parse_completed_tasks "$PLAN_FILE" "$PHASE_FILTER")
    
    if [ ${#completed_tasks[@]} -eq 0 ]; then
        echo -e "${YELLOW}No completed tasks found in the implementation plan${NC}" >&2
        if [ ! -z "$PHASE_FILTER" ]; then
            echo -e "${YELLOW}(Phase $PHASE_FILTER filter applied)${NC}" >&2
        fi
        return
    fi
    
    echo -e "${GREEN}Found ${#completed_tasks[@]} completed tasks${NC}" >&2
    if [ ! -z "$PHASE_FILTER" ]; then
        echo -e "${BLUE}Filtering to Phase $PHASE_FILTER only${NC}" >&2
    fi
    echo "" >&2
    
    # Build label filter based on phase
    local label_filter=""
    if [ ! -z "$PHASE_FILTER" ]; then
        label_filter="--label phase-$PHASE_FILTER"
    fi
    
    # Get all open issues (filtered by phase if specified)
    issues=$(gh issue list --state open $label_filter --limit 200 --json number,title,labels 2>/dev/null)
    
    if [ -z "$issues" ] || [ "$(echo "$issues" | jq length)" -eq 0 ]; then
        echo -e "${YELLOW}No open issues found${NC}" >&2
        if [ ! -z "$PHASE_FILTER" ]; then
            echo -e "${YELLOW}(Phase $PHASE_FILTER filter applied)${NC}" >&2
        fi
        return
    fi
    
    total_issues=$(echo "$issues" | jq length)
    echo -e "${GREEN}Found $total_issues open issues${NC}" >&2
    if [ ! -z "$PHASE_FILTER" ]; then
        echo -e "${BLUE}(Phase $PHASE_FILTER filter applied)${NC}" >&2
    fi
    echo "" >&2
    
    # Process each issue
    updated=0
    skipped=0
    
    for i in $(seq 0 $((total_issues - 1))); do
        issue_number=$(echo "$issues" | jq -r ".[$i].number")
        issue_title=$(echo "$issues" | jq -r ".[$i].title")
        
        # Check if this issue matches any completed task
        task_completed=false
        matched_task=""
        
        for task in "${completed_tasks[@]}"; do
            # Try multiple matching strategies
            # 1. Exact match (case insensitive)
            if echo "$issue_title" | grep -qi "^$task$"; then
                task_completed=true
                matched_task="$task"
                break
            fi
            # 2. Partial match (case insensitive)
            if echo "$issue_title" | grep -qi "$task"; then
                task_completed=true
                matched_task="$task"
                break
            fi
            # 3. Keywords match (extract key words from both)
            task_keywords=$(echo "$task" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g' | tr -s ' ' | sed 's/^ *//;s/ *$//')
            issue_keywords=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g' | tr -s ' ' | sed 's/^ *//;s/ *$//')
            
            # Check if most words from task appear in issue title
            word_count=0
            matched_count=0
            for word in $task_keywords; do
                if [ ${#word} -gt 2 ]; then  # Only check words longer than 2 chars
                    ((word_count++))
                    if echo "$issue_keywords" | grep -q "\b$word\b"; then
                        ((matched_count++))
                    fi
                fi
            done
            
            # If 75% or more words match, consider it a match
            if [ $word_count -gt 0 ] && [ $((matched_count * 4)) -ge $((word_count * 3)) ]; then
                task_completed=true
                matched_task="$task"
                break
            fi
        done
        
        if [ "$task_completed" = true ]; then
            echo -e "[$((i+1))/$total_issues] ${GREEN}Marking as Done: ${issue_title:0:60}...${NC}" >&2
            echo -e "  ${CYAN}Matched task: ${matched_task:0:50}...${NC}" >&2
            
            if $DRY_RUN; then
                echo -e "  ${BLUE}[DRY RUN] Would mark as Done${NC}" >&2
                ((updated++))
                continue
            fi
            
            # Get account type (do this once)
            if [ -z "$account_type" ]; then
                account_type=$(gh api graphql -f query='query($login: String!) { repositoryOwner(login: $login) { __typename } }' -f login="$OWNER" --jq .data.repositoryOwner.__typename 2>/dev/null)
            fi
            
            # Get the project item ID for this issue
            if [ "$account_type" = "Organization" ]; then
                project_item=$(gh api graphql -f query='
                query($owner: String!, $number: Int!, $issue: Int!) {
                  organization(login: $owner) {
                    projectV2(number: $number) {
                      items(first: 100, query: $issue) {
                        nodes {
                          id
                          content {
                            ... on Issue {
                              number
                            }
                          }
                        }
                      }
                    }
                  }
                }' -f owner="$OWNER" -F number="$project_number" -f issue="$issue_number" 2>/dev/null)
                
                item_id=$(echo "$project_item" | jq -r '.data.organization.projectV2.items.nodes[]? | select(.content.number == '$issue_number') | .id' | head -1)
            else
                project_item=$(gh api graphql -f query='
                query($owner: String!, $number: Int!, $issue: Int!) {
                  user(login: $owner) {
                    projectV2(number: $number) {
                      items(first: 100, query: $issue) {
                        nodes {
                          id
                          content {
                            ... on Issue {
                              number
                            }
                          }
                        }
                      }
                    }
                  }
                }' -f owner="$OWNER" -F number="$project_number" -f issue="$issue_number" 2>/dev/null)
                
                item_id=$(echo "$project_item" | jq -r '.data.user.projectV2.items.nodes[]? | select(.content.number == '$issue_number') | .id' | head -1)
            fi
            
            if [ ! -z "$item_id" ]; then
                # Get project ID
                if [ -z "$project_id" ]; then
                    if [ "$account_type" = "Organization" ]; then
                        project_id=$(gh api graphql -f query='query($owner: String!, $number: Int!) { organization(login: $owner) { projectV2(number: $number) { id } } }' -f owner="$OWNER" -F number="$project_number" --jq .data.organization.projectV2.id 2>/dev/null)
                    else
                        project_id=$(gh api graphql -f query='query($owner: String!, $number: Int!) { user(login: $owner) { projectV2(number: $number) { id } } }' -f owner="$OWNER" -F number="$project_number" --jq .data.user.projectV2.id 2>/dev/null)
                    fi
                fi
                
                # Update status to Done
                result=$(gh api graphql -f query='
                mutation($project: ID!, $item: ID!, $field: ID!, $value: String!) {
                  updateProjectV2ItemFieldValue(input: {
                    projectId: $project,
                    itemId: $item,
                    fieldId: $field,
                    value: {singleSelectOptionId: $value}
                  }) {
                    projectV2Item {
                      id
                    }
                  }
                }' \
                -f project="$project_id" \
                -f item="$item_id" \
                -f field="$status_field_id" \
                -f value="$done_option_id" 2>&1)
                
                if [ $? -eq 0 ]; then
                    echo -e "  ${GREEN}✓ Updated to Done${NC}" >&2
                    ((updated++))
                    
                    # Also close the issue with reference to matched task
                    close_comment="✅ Completed task: $matched_task"
                    if [ ! -z "$PHASE_FILTER" ]; then
                        close_comment="$close_comment\n\nMarked as completed in Phase $PHASE_FILTER of the implementation plan."
                    fi
                    gh issue close $issue_number --comment "$close_comment" 2>/dev/null
                else
                    echo -e "  ${RED}✗ Failed to update status${NC}" >&2
                    ((skipped++))
                fi
            else
                echo -e "  ${RED}✗ Issue not found in project${NC}" >&2
                ((skipped++))
            fi
        else
            echo -e "[$((i+1))/$total_issues] ${YELLOW}Skipping: ${issue_title:0:60}...${NC}" >&2
            ((skipped++))
        fi
        
        # Rate limit protection
        if [ $(((updated + skipped) % 10)) -eq 0 ] && [ $((updated + skipped)) -gt 0 ]; then
            echo -e "${YELLOW}Processed $((updated + skipped)) issues, pausing to avoid rate limits...${NC}" >&2
            sleep 1
        fi
    done
    
    echo "" >&2
    echo -e "${GREEN}Update Summary:${NC}" >&2
    if $DRY_RUN; then
        echo -e "  Would mark as Done: $updated issues" >&2
        echo -e "  Would skip: $skipped issues" >&2
    else
        echo -e "  Marked as Done: $updated issues" >&2
        echo -e "  Skipped: $skipped issues" >&2
    fi
    if [ ! -z "$PHASE_FILTER" ]; then
        echo -e "  Phase filter: $PHASE_FILTER" >&2
    fi
    echo -e "  Total completed tasks in plan: ${#completed_tasks[@]}" >&2
}

# Function to update milestone description for completed phases
update_milestone_description() {
    local phase="$1"
    
    if [ -z "$phase" ]; then
        echo -e "${YELLOW}No specific phase provided for milestone update${NC}" >&2
        return
    fi
    
    echo -e "${BLUE}Updating Phase $phase milestone description...${NC}" >&2
    
    if $DRY_RUN; then
        echo -e "  ${BLUE}[DRY RUN] Would update milestone description${NC}" >&2
        return
    fi
    
    # Get milestone for the specified phase
    milestone=$(gh api repos/$REPO/milestones --jq ".[] | select(.title | startswith(\"Phase $phase:\"))" 2>/dev/null | head -1)
    
    if [ ! -z "$milestone" ]; then
        milestone_number=$(echo "$milestone" | jq -r .number)
        current_description=$(echo "$milestone" | jq -r .description)
        
        # Check if already marked as completed
        if echo "$current_description" | grep -q "✅ \*\*COMPLETED\*\*"; then
            echo -e "  ${YELLOW}Milestone already marked as completed${NC}" >&2
            return
        fi
        
        # Add completion status to description
        new_description="✅ **COMPLETED** - Tasks completed as tracked in implementation plan

**Completion Status:**
- Tasks have been marked as completed in the implementation plan
- Corresponding GitHub issues have been closed
- Ready to proceed to next phase

**Original Description:**
$current_description"
        
        # Update milestone
        gh api --method PATCH repos/$REPO/milestones/$milestone_number \
            -f description="$new_description" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ Updated milestone description${NC}" >&2
        else
            echo -e "  ${YELLOW}Warning: Could not update milestone description${NC}" >&2
        fi
    else
        echo -e "  ${YELLOW}Warning: Phase $phase milestone not found${NC}" >&2
    fi
}

# Main execution
main() {
    echo -e "${YELLOW}This script will:${NC}" >&2
    echo -e "  1. Parse completed tasks from the implementation plan" >&2
    echo -e "  2. Mark matching GitHub issues as 'Done' in the project board" >&2
    echo -e "  3. Close completed issues with reference to matched tasks" >&2
    if [ ! -z "$PHASE_FILTER" ]; then
        echo -e "  4. Update Phase $PHASE_FILTER milestone description" >&2
    fi
    echo "" >&2
    
    if ! $DRY_RUN; then
        read -p "Continue? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo -e "${RED}Cancelled${NC}" >&2
            exit 0
        fi
    fi
    
    echo "" >&2
    
    # Find project
    project_number=$(find_project)
    
    # Get field IDs
    field_info=$(get_field_ids $project_number)
    
    # Update issues based on completed tasks
    update_completed_tasks $project_number $field_info
    
    # Update milestone if phase filter is specified
    if [ ! -z "$PHASE_FILTER" ]; then
        update_milestone_description "$PHASE_FILTER"
    fi
    
    echo "" >&2
    if $DRY_RUN; then
        echo -e "${BLUE}Dry run complete - no changes were made${NC}" >&2
    else
        echo -e "${GREEN}Project board update complete!${NC}" >&2
    fi
    echo "" >&2
    echo "View your project at: https://github.com/orgs/$OWNER/projects/$project_number" >&2
    if [ ! -z "$PHASE_FILTER" ]; then
        echo "View Phase $PHASE_FILTER milestone at: https://github.com/$REPO/milestones" >&2
    fi
}

# Run main function
main