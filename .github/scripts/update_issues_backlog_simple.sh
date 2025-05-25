#!/bin/bash

# Simplified script to set all GitHub issues to 'backlog' status except Phase 1 issues
# This uses GitHub Projects v2 with a simpler approach

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

# Main execution
main() {
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
    echo "" >&2
    
    # Confirm before proceeding
    echo -e "${YELLOW}This will update issue status in the project board${NC}" >&2
    echo -e "${YELLOW}Phase 1 issues will be skipped${NC}" >&2
    read -p "Continue? (y/n): " confirm
    
    if [ "$confirm" != "y" ]; then
        echo -e "${RED}Cancelled${NC}" >&2
        exit 0
    fi
    
    echo "" >&2
    echo -e "${BLUE}Fetching all open issues...${NC}" >&2
    
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
    failed=0
    
    for i in $(seq 0 $((total_issues - 1))); do
        issue_number=$(echo "$issues" | jq -r ".[$i].number")
        issue_title=$(echo "$issues" | jq -r ".[$i].title")
        issue_labels=$(echo "$issues" | jq -r ".[$i].labels[].name" | paste -sd "," -)
        
        # Check if this is a Phase 1 issue
        if echo "$issue_labels" | grep -q "phase-1"; then
            echo -e "[$((i+1))/$total_issues] ${YELLOW}Skipping Phase 1 issue #$issue_number${NC}" >&2
            ((phase1_skipped++))
            continue
        fi
        
        echo -e "[$((i+1))/$total_issues] Processing issue #$issue_number..." >&2
        
        # Try to add the issue to the project (it's idempotent, so safe to run even if already added)
        add_result=$(gh project item-add $project_number --owner $OWNER --url "https://github.com/$REPO/issues/$issue_number" 2>&1)
        
        if [ $? -eq 0 ] || echo "$add_result" | grep -q "already exists"; then
            # Now update the status field
            # First, get available fields and options
            if [ -z "$status_options_fetched" ]; then
                echo -e "  ${BLUE}Fetching project field options...${NC}" >&2
                fields=$(gh project field-list $project_number --owner $OWNER --format json 2>/dev/null)
                
                # Check if we have a Status field
                status_field=$(echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .name' | head -1)
                
                if [ -z "$status_field" ]; then
                    echo -e "${RED}Error: No 'Status' field found in project${NC}" >&2
                    echo -e "${YELLOW}Available fields:${NC}" >&2
                    echo "$fields" | jq -r '.fields[].name' >&2
                    exit 1
                fi
                
                # Get backlog option
                backlog_option=$(echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name | test("backlog|Backlog|Todo|TODO"; "i")) | .name' | head -1)
                
                if [ -z "$backlog_option" ]; then
                    echo -e "${YELLOW}Warning: Could not find 'Backlog' option in Status field${NC}" >&2
                    echo -e "${YELLOW}Available status options:${NC}" >&2
                    echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[].name' >&2
                    
                    # Use the first available option as fallback
                    backlog_option=$(echo "$fields" | jq -r '.fields[] | select(.name == "Status") | .options[0].name' | head -1)
                    echo -e "${YELLOW}Using '$backlog_option' as the status${NC}" >&2
                fi
                
                status_options_fetched=1
            fi
            
            # Update the item status
            update_result=$(gh project item-edit --project-id $project_number --owner $OWNER --id "https://github.com/$REPO/issues/$issue_number" --field-id "Status" --single-select-option-id "$backlog_option" 2>&1)
            
            if [ $? -eq 0 ]; then
                echo -e "  ${GREEN}✓ Updated to $backlog_option${NC}" >&2
                ((updated++))
            else
                # Try alternative approach using the item URL
                echo -e "  ${YELLOW}Trying alternative update method...${NC}" >&2
                
                # Get the item ID from the project
                item_info=$(gh project item-list $project_number --owner $OWNER --format json | jq -r --arg url "https://github.com/$REPO/issues/$issue_number" '.items[] | select(.content.url == $url) | {id: .id, title: .title}' | head -1)
                
                if [ ! -z "$item_info" ] && [ "$item_info" != "null" ]; then
                    item_id=$(echo "$item_info" | jq -r '.id')
                    
                    if [ ! -z "$item_id" ] && [ "$item_id" != "null" ]; then
                        # Try to update using the item ID
                        update_result2=$(gh api graphql -f query='
                        mutation($project: ID!, $item: ID!, $fieldId: ID!, $value: String!) {
                          updateProjectV2ItemFieldValue(
                            input: {
                              projectId: $project
                              itemId: $item
                              fieldId: $fieldId
                              value: { 
                                singleSelectOptionId: $value
                              }
                            }
                          ) {
                            projectV2Item {
                              id
                            }
                          }
                        }' \
                        -f project="$project_number" \
                        -f item="$item_id" \
                        -f fieldId="Status" \
                        -f value="$backlog_option" 2>&1)
                        
                        if [ $? -eq 0 ]; then
                            echo -e "  ${GREEN}✓ Updated to $backlog_option (alt method)${NC}" >&2
                            ((updated++))
                        else
                            echo -e "  ${RED}✗ Failed to update${NC}" >&2
                            echo -e "  ${RED}Error: $update_result2${NC}" >&2
                            ((failed++))
                        fi
                    else
                        echo -e "  ${RED}✗ Could not find item in project${NC}" >&2
                        ((failed++))
                    fi
                else
                    echo -e "  ${RED}✗ Issue not found in project${NC}" >&2
                    ((failed++))
                fi
            fi
        else
            echo -e "  ${RED}✗ Failed to add to project: $add_result${NC}" >&2
            ((failed++))
        fi
        
        # Rate limit protection
        if [ $(((updated + failed) % 20)) -eq 0 ] && [ $((updated + failed)) -gt 0 ]; then
            echo -e "${YELLOW}Processed $((updated + failed)) issues, pausing to avoid rate limits...${NC}" >&2
            sleep 2
        fi
    done
    
    echo "" >&2
    echo -e "${GREEN}Summary:${NC}" >&2
    echo -e "  Updated to backlog: $updated issues" >&2
    echo -e "  Phase 1 (skipped): $phase1_skipped issues" >&2
    echo -e "  Failed: $failed issues" >&2
    echo "" >&2
    echo "View your project at: https://github.com/orgs/$OWNER/projects/$project_number" >&2
}

# Run main function
main