#!/bin/bash

# Script to update GitHub project board status based on implementation plan progress
# This script marks Phase 1 issues as "Done" based on the completed tasks in implementation_plan.md

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${GREEN}Updating project status for: $REPO${NC}" >&2
echo -e "${BLUE}Based on implementation_plan.md changes${NC}" >&2
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

# Function to update specific Phase 1 issues to Done
update_phase1_to_done() {
    local project_number=$1
    local field_info=$2
    local status_field_id=$(echo $field_info | cut -d':' -f1)
    local done_option_id=$(echo $field_info | cut -d':' -f2)
    
    echo -e "${BLUE}Marking completed Phase 1 tasks as Done...${NC}" >&2
    
    # Define completed Phase 1 tasks based on implementation_plan.md
    # Section 1.1: Basic DSL Structures
    # Section 1.2: Section Definitions  
    # Section 1.3: Extension Modules
    
    declare -a completed_tasks=(
        "Create.*lib/ash_reports/dsl.ex.*core structs"
        "Report struct definition"
        "Band struct definition"
        "Column struct definition"
        "Implement basic Spark DSL entities"
        "@column entity definition"
        "@band entity definition"
        "@report entity definition"
        "Create @reports_section for domain extension"
        "Create @reportable_section for resource extension"
        "Configure section schemas"
        "Implement.*AshReports.Dsl.Domain.*extension"
        "Implement.*AshReports.Dsl.Resource.*extension"
        "Set up basic transformer registration"
    )
    
    # Get all Phase 1 issues
    phase1_issues=$(gh issue list --state open --label "phase-1" --limit 100 --json number,title,labels 2>/dev/null)
    
    if [ -z "$phase1_issues" ] || [ "$(echo "$phase1_issues" | jq length)" -eq 0 ]; then
        echo -e "${YELLOW}No Phase 1 issues found${NC}" >&2
        return
    fi
    
    total_issues=$(echo "$phase1_issues" | jq length)
    echo -e "${GREEN}Found $total_issues Phase 1 issues${NC}" >&2
    echo "" >&2
    
    # Process each Phase 1 issue
    updated=0
    skipped=0
    
    for i in $(seq 0 $((total_issues - 1))); do
        issue_number=$(echo "$phase1_issues" | jq -r ".[$i].number")
        issue_title=$(echo "$phase1_issues" | jq -r ".[$i].title")
        
        # Check if this issue matches any completed task
        task_completed=false
        for pattern in "${completed_tasks[@]}"; do
            if echo "$issue_title" | grep -qi "$pattern"; then
                task_completed=true
                break
            fi
        done
        
        if [ "$task_completed" = true ]; then
            echo -e "[$((i+1))/$total_issues] ${GREEN}Marking as Done: ${issue_title:0:60}...${NC}" >&2
            
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
                    
                    # Also close the issue
                    gh issue close $issue_number --comment "✅ Completed as part of Phase 1 implementation. Core DSL foundation is now working." 2>/dev/null
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
    echo -e "${GREEN}Phase 1 Update Summary:${NC}" >&2
    echo -e "  Marked as Done: $updated issues" >&2
    echo -e "  Skipped: $skipped issues" >&2
}

# Function to add Phase 1 completion comment to milestone
update_milestone_description() {
    local phase=1
    
    echo -e "${BLUE}Updating Phase 1 milestone description...${NC}" >&2
    
    # Get Phase 1 milestone
    milestone=$(gh api repos/$REPO/milestones --jq ".[] | select(.title | startswith(\"Phase $phase:\"))" 2>/dev/null | head -1)
    
    if [ ! -z "$milestone" ]; then
        milestone_number=$(echo "$milestone" | jq -r .number)
        current_description=$(echo "$milestone" | jq -r .description)
        
        # Add completion status to description
        new_description="✅ **COMPLETED** - Core DSL foundation is working

**Current Status:**
- Recursive bands (recursive_as and nested band entities) are temporarily disabled due to Spark version compatibility
- Full hierarchical band support is planned for Phase 6 with custom implementation  
- Current flat band structure allows progression to Phase 2

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
        echo -e "  ${YELLOW}Warning: Phase 1 milestone not found${NC}" >&2
    fi
}

# Main execution
main() {
    echo -e "${YELLOW}This script will:${NC}" >&2
    echo -e "  1. Mark completed Phase 1 tasks as 'Done' in the project board" >&2
    echo -e "  2. Close completed Phase 1 issues" >&2
    echo -e "  3. Update Phase 1 milestone description" >&2
    echo "" >&2
    
    read -p "Continue? (y/n): " confirm
    
    if [ "$confirm" != "y" ]; then
        echo -e "${RED}Cancelled${NC}" >&2
        exit 0
    fi
    
    echo "" >&2
    
    # Find project
    project_number=$(find_project)
    
    # Get field IDs
    field_info=$(get_field_ids $project_number)
    
    # Update Phase 1 issues
    update_phase1_to_done $project_number $field_info
    
    # Update milestone
    update_milestone_description
    
    echo "" >&2
    echo -e "${GREEN}Project board update complete!${NC}" >&2
    echo "" >&2
    echo "View your project at: https://github.com/orgs/$OWNER/projects/$project_number" >&2
    echo "View Phase 1 milestone at: https://github.com/$REPO/milestone/1" >&2
}

# Run main function
main