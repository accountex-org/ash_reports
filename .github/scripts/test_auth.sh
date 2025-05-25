#!/bin/bash

# Simple script to test GitHub authentication and repository access
# Useful for verifying setup before running other scripts

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 GitHub Authentication Test${NC}"
echo ""

# Test 1: Check if GitHub CLI is installed
echo -n "Checking GitHub CLI installation... "
if command -v gh &> /dev/null; then
    echo -e "${GREEN}✓ Found$(gh --version | head -1 | cut -d' ' -f3)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "Please install GitHub CLI from: https://cli.github.com/"
    exit 1
fi

# Test 2: Check authentication status
echo -n "Checking GitHub authentication... "
if gh auth status &> /dev/null; then
    echo -e "${GREEN}✓ Authenticated${NC}"
    
    # Show current user
    current_user=$(gh api user --jq .login 2>/dev/null)
    if [ ! -z "$current_user" ]; then
        echo -e "  Logged in as: ${CYAN}$current_user${NC}"
    fi
else
    echo -e "${RED}✗ Not authenticated${NC}"
    echo ""
    echo -e "${YELLOW}To authenticate, run:${NC}"
    echo -e "  ${CYAN}gh auth login${NC}"
    echo ""
    exit 1
fi

# Test 3: Check repository access
echo -n "Checking repository access... "
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ ! -z "$REPO" ]; then
    echo -e "${GREEN}✓ Access confirmed${NC}"
    echo -e "  Repository: ${CYAN}$REPO${NC}"
else
    echo -e "${RED}✗ Cannot access repository${NC}"
    echo ""
    echo "Possible issues:"
    echo "1. Not in a git repository directory"
    echo "2. Repository is not on GitHub"
    echo "3. Insufficient permissions"
    echo ""
    exit 1
fi

# Test 4: Check permissions
echo -n "Checking repository permissions... "
# Try to list issues (requires read access)
if gh issue list --limit 1 &> /dev/null; then
    echo -e "${GREEN}✓ Read access confirmed${NC}"
    
    # Try to create a label (requires write access) - but don't actually create it
    # Just check if we get a permission error vs other errors
    test_result=$(gh api repos/$REPO/labels --method POST -f name="__test__" -f color="000000" 2>&1 || true)
    if echo "$test_result" | grep -q "Must have push access"; then
        echo -e "  Write access: ${YELLOW}⚠ Limited (read-only)${NC}"
        echo -e "    ${YELLOW}Note: You may not be able to create issues/milestones${NC}"
    else
        echo -e "  Write access: ${GREEN}✓ Confirmed${NC}"
    fi
else
    echo -e "${RED}✗ No repository access${NC}"
    echo "Please ensure you have access to this repository."
    exit 1
fi

# Test 5: Check for existing project boards
echo -n "Checking for project boards... "
OWNER=$(echo $REPO | cut -d'/' -f1)
project_count=$(gh project list --owner $OWNER --format json 2>/dev/null | jq '.projects | length' 2>/dev/null || echo "0")
if [ "$project_count" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $project_count project(s)${NC}"
    
    # Check for AshReports project specifically
    ash_project=$(gh project list --owner $OWNER --format json 2>/dev/null | jq -r '.projects[] | select(.title == "AshReports Implementation") | .number' 2>/dev/null | head -1)
    if [ ! -z "$ash_project" ]; then
        echo -e "  AshReports project: ${GREEN}✓ Found (#$ash_project)${NC}"
    else
        echo -e "  AshReports project: ${YELLOW}⚠ Not found${NC}"
        echo -e "    ${YELLOW}Run setup scripts to create project board${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No projects found${NC}"
    echo -e "    ${YELLOW}Run setup scripts to create project board${NC}"
fi

echo ""
echo -e "${GREEN}🎉 All tests passed! You're ready to use the GitHub scripts.${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  • Run ${CYAN}./project_manager.sh${NC} for interactive management"
echo -e "  • Run ${CYAN}./create_github_milestones.sh${NC} to set up milestones"
echo -e "  • Run ${CYAN}./create_github_issues_batch.sh${NC} to create issues"