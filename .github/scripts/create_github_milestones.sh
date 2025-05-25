#!/bin/bash

# Script to create GitHub milestones from implementation phases
# Requires: gh (GitHub CLI) to be installed and authenticated

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

echo -e "${GREEN}Creating milestones for repository: $REPO${NC}"
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

# Create milestones
create_milestone() {
    local number=$1
    local title=$2
    local description=$3
    local due_date=$4
    
    echo -e "${YELLOW}Creating milestone: Phase $number - $title${NC}"
    
    # Check if milestone already exists
    existing=$(gh api repos/$REPO/milestones --jq ".[] | select(.title == \"Phase $number: $title\") | .number" 2>/dev/null)
    
    if [ ! -z "$existing" ]; then
        echo -e "  Milestone already exists (number: $existing), skipping..."
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

# Milestones data based on implementation_phases.md
echo "Creating milestones based on implementation phases..."
echo ""

# Phase 1
create_milestone 1 "Core DSL Foundation" \
"Basic DSL that can be used in domain/resource definitions without runtime functionality

Key tasks:
- Create core structs (Report, Band, Column)
- Implement Spark DSL entities
- Set up domain and resource extensions" \
"$(calculate_due_date 2)"

# Phase 2
create_milestone 2 "Query Generation System" \
"Query system that can fetch data for reports

Key tasks:
- Build query generator for reports
- Implement band-specific queries
- Add filtering, sorting, and pagination support" \
"$(calculate_due_date 3)"

# Phase 3
create_milestone 3 "Basic Transformers" \
"Reports are registered and accessible via generated actions

Key tasks:
- Create report registration transformers
- Generate report actions for resources
- Set up transformer infrastructure" \
"$(calculate_due_date 4)"

# Phase 4
create_milestone 4 "Report Module Generation" \
"Generated report modules with format dispatch

Key tasks:
- Implement module generation transformer
- Create format-specific module stubs
- Set up format registration system" \
"$(calculate_due_date 6)"

# Phase 5
create_milestone 5 "HTML Renderer" \
"Fully functional HTML report generation

Key tasks:
- Create HTML renderer
- Implement band rendering system
- Add column formatting and styling" \
"$(calculate_due_date 8)"

# Phase 6
create_milestone 6 "Band Processing Engine" \
"Complex hierarchical reports with grouping and aggregation

Key tasks:
- Build hierarchical band processor
- Add grouping and aggregation support
- Implement conditional rendering" \
"$(calculate_due_date 9)"

# Phase 7
create_milestone 7 "PDF and HEEX Renderers" \
"Multi-format report generation (HTML, PDF, HEEX)

Key tasks:
- Implement PDF renderer with ChromicPDF
- Create HEEX template generator
- Add Phoenix LiveView support" \
"$(calculate_due_date 11)"

# Phase 8
create_milestone 8 "Reports Server" \
"Standalone reports server with HTTP API and async generation

Key tasks:
- Build GenServer infrastructure
- Create REST API endpoints
- Implement async job processing
- Add real-time updates support" \
"$(calculate_due_date 12)"

# Phase 9
create_milestone 9 "MCP Server Integration" \
"Fully functional MCP server allowing AI assistants to interact with reports

Key tasks:
- Implement MCP protocol server
- Create report-specific tools
- Add resource providers and prompts
- Build management utilities" \
"$(calculate_due_date 13)"

# Phase 10
create_milestone 10 "Advanced Features" \
"Production-ready extension with advanced features

Key tasks:
- Implement caching system
- Add advanced query features
- Create export formats (CSV, Excel)" \
"$(calculate_due_date 15)"

# Phase 11
create_milestone 11 "Testing and Documentation" \
"Well-tested, documented extension ready for release

Key tasks:
- Complete test suite
- Write comprehensive documentation
- Create example implementations" \
"$(calculate_due_date 17)"

# Phase 12
create_milestone 12 "Polish and Release" \
"Published Hex package ready for community use

Key tasks:
- Performance optimization
- Final bug fixes
- Package preparation
- Release to Hex.pm" \
"$(calculate_due_date 18)"

echo -e "${GREEN}Milestone creation complete!${NC}"
echo ""
echo "View your milestones at: https://github.com/$REPO/milestones"