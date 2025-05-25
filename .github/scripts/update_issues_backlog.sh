#!/bin/bash

# Script to set all GitHub issues to 'backlog' status except Phase 1 issues
# This uses GitHub Projects v2 to manage issue status

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

echo -e "${GREEN}Updating issue status for: $REPO${NC}" >&2
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
    
    # Get the option ID for "Backlog" status
    backlog_option_id=$(echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "Backlog" or .name == "backlog" or .name == "📋 Backlog") | .id' | head -1)
    
    if [ -z "$backlog_option_id" ]; then
        echo -e "${YELLOW}Warning: Could not find 'Backlog' option in Status field${NC}" >&2
        echo -e "${YELLOW}Available status options:${NC}" >&2
        echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[] | .name' >&2
        exit 1
    fi
    
    echo "$status_field_id:$backlog_option_id"
}

# Function to update issues
update_issues_status() {
    local project_number=$1
    local field_info=$2
    local status_field_id=$(echo $field_info | cut -d':' -f1)
    local backlog_option_id=$(echo $field_info | cut -d':' -f2)
    
    echo -e "${BLUE}Fetching all issues...${NC}" >&2
    
    # Get all open issues
    issues=$(gh issue list --state open --limit 1000 --json number,title,labels 2>/dev/null)
    
    if [ -z "$issues" ] || [ "$(echo "$issues" | jq length)" -eq 0 ]; then
        echo -e "${YELLOW}No open issues found${NC}" >&2
        return
    fi
    
    total_issues=$(echo "$issues" | jq length)
    echo -e "${GREEN}Found $total_issues open issues${NC}" >&2
    echo "" >&2
    
    # Process each issue
    updated=0
    skipped=0
    phase1_skipped=0
    
    for i in $(seq 0 $((total_issues - 1))); do
        issue_number=$(echo "$issues" | jq -r ".[$i].number")
        issue_title=$(echo "$issues" | jq -r ".[$i].title")
        issue_labels=$(echo "$issues" | jq -r ".[$i].labels[].name" | paste -sd "," -)
        
        # Check if this is a Phase 1 issue
        if echo "$issue_labels" | grep -q "phase-1"; then
            echo -e "[$((i+1))/$total_issues] ${YELLOW}Skipping Phase 1 issue #$issue_number: ${issue_title:0:60}...${NC}" >&2
            ((phase1_skipped++))
            continue
        fi
        
        echo -e "[$((i+1))/$total_issues] Updating issue #$issue_number: ${issue_title:0:60}..." >&2
        
        # Get the project item ID for this issue
        # First, let's check if this is a user or org account (do this once)
        if [ -z "$account_type" ]; then
            account_type=$(gh api graphql -f query='query($login: String!) { repositoryOwner(login: $login) { __typename } }' -f login="$OWNER" --jq .data.repositoryOwner.__typename 2>/dev/null)
            echo -e "  ${BLUE}Account type: $account_type${NC}" >&2
        fi
        
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
        
        if [ -z "$item_id" ]; then
            # Issue not in project, add it first
            echo -e "  ${YELLOW}Adding issue to project...${NC}" >&2
            
            # Get the issue node ID
            issue_node_id=$(gh api repos/$REPO/issues/$issue_number --jq .node_id 2>/dev/null)
            
            if [ ! -z "$issue_node_id" ]; then
                # Get project ID based on account type
                if [ "$account_type" = "Organization" ]; then
                    project_id=$(gh api graphql -f query='query($owner: String!, $number: Int!) { organization(login: $owner) { projectV2(number: $number) { id } } }' -f owner="$OWNER" -F number="$project_number" --jq .data.organization.projectV2.id 2>/dev/null)
                else
                    project_id=$(gh api graphql -f query='query($owner: String!, $number: Int!) { user(login: $owner) { projectV2(number: $number) { id } } }' -f owner="$OWNER" -F number="$project_number" --jq .data.user.projectV2.id 2>/dev/null)
                fi
                
                # Add to project
                added=$(gh api graphql -f query='
                mutation($project: ID!, $contentId: ID!) {
                  addProjectV2ItemById(input: {projectId: $project, contentId: $contentId}) {
                    item {
                      id
                    }
                  }
                }' -f project="$project_id" -f contentId="$issue_node_id" 2>/dev/null)
                
                item_id=$(echo "$added" | jq -r '.data.addProjectV2ItemById.item.id')
            fi
        fi
        
        if [ ! -z "$item_id" ]; then
            # Get project ID based on account type (reuse from above if possible)
            if [ -z "$project_id" ]; then
                if [ "$account_type" = "Organization" ]; then
                    project_id=$(gh api graphql -f query='query($owner: String!, $number: Int!) { organization(login: $owner) { projectV2(number: $number) { id } } }' -f owner="$OWNER" -F number="$project_number" --jq .data.organization.projectV2.id 2>/dev/null)
                else
                    project_id=$(gh api graphql -f query='query($owner: String!, $number: Int!) { user(login: $owner) { projectV2(number: $number) { id } } }' -f owner="$OWNER" -F number="$project_number" --jq .data.user.projectV2.id 2>/dev/null)
                fi
            fi
            
            # Update status to backlog
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
            -f value="$backlog_option_id" 2>&1)
            
            if [ $? -eq 0 ]; then
                echo -e "  ${GREEN}✓ Updated to backlog${NC}" >&2
                ((updated++))
            else
                echo -e "  ${RED}✗ Failed to update status${NC}" >&2
                ((skipped++))
            fi
        else
            echo -e "  ${RED}✗ Could not add to project${NC}" >&2
            ((skipped++))
        fi
        
        # Rate limit protection
        if [ $(((updated + skipped) % 20)) -eq 0 ] && [ $((updated + skipped)) -gt 0 ]; then
            echo -e "${YELLOW}Processed $((updated + skipped)) issues, pausing to avoid rate limits...${NC}" >&2
            sleep 2
        fi
    done
    
    echo "" >&2
    echo -e "${GREEN}Summary:${NC}" >&2
    echo -e "  Updated to backlog: $updated issues" >&2
    echo -e "  Phase 1 (skipped): $phase1_skipped issues" >&2
    echo -e "  Failed/skipped: $skipped issues" >&2
}

# Main execution
main() {
    # Find project
    project_number=$(find_project)
    
    # Get field IDs
    field_info=$(get_field_ids $project_number)
    
    # Confirm before proceeding
    echo "" >&2
    echo -e "${YELLOW}This will set all non-Phase 1 issues to 'Backlog' status${NC}" >&2
    read -p "Continue? (y/n): " confirm
    
    if [ "$confirm" != "y" ]; then
        echo -e "${RED}Cancelled${NC}" >&2
        exit 0
    fi
    
    echo "" >&2
    
    # Update issues
    update_issues_status $project_number $field_info
    
    echo "" >&2
    echo -e "${GREEN}Done!${NC}" >&2
    echo "" >&2
    echo "View your project at: https://github.com/orgs/$OWNER/projects/$project_number" >&2
}

# Run main function
main