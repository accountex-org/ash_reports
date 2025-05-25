#!/bin/bash

# Interactive Project Management Script
# Provides a menu-driven interface for all GitHub project management tasks

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display header
show_header() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    🚀 AshReports Project Manager               ║${NC}"
    echo -e "${PURPLE}║                   GitHub Project Board Management             ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to get current project status
get_project_status() {
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    local open_issues=$(gh issue list --state open --json number --jq length 2>/dev/null)
    local closed_issues=$(gh issue list --state closed --json number --jq length 2>/dev/null)
    
    echo -e "${CYAN}Current Status:${NC}"
    echo -e "  Repository: ${GREEN}$repo${NC}"
    echo -e "  Open Issues: ${YELLOW}$open_issues${NC}"
    echo -e "  Closed Issues: ${GREEN}$closed_issues${NC}"
    echo ""
}

# Function to show main menu
show_main_menu() {
    echo -e "${BLUE}📋 Main Menu:${NC}"
    echo ""
    echo -e "  ${GREEN}Setup & Initialization${NC}"
    echo -e "    1) Create milestones for all phases"
    echo -e "    2) Create issues from implementation plan"
    echo -e "    3) Initialize project board (full setup)"
    echo ""
    echo -e "  ${YELLOW}Status Updates${NC}"
    echo -e "    4) Update project board for completed phases"
    echo -e "    5) Move issues to backlog"
    echo -e "    6) Bulk status update (custom)"
    echo ""
    echo -e "  ${PURPLE}Utilities${NC}"
    echo -e "    7) Show project statistics"
    echo -e "    8) Backup project state"
    echo -e "    9) View script execution log"
    echo ""
    echo -e "  ${RED}Advanced${NC}"
    echo -e "    a) Run custom script"
    echo -e "    b) GitHub Actions integration"
    echo ""
    echo -e "    ${CYAN}q) Quit${NC}"
    echo ""
}

# Function to log script execution
log_execution() {
    local script_name="$1"
    local context="$2"
    local outcome="$3"
    local notes="$4"
    local date=$(date '+%Y-%m-%d %H:%M')
    
    local log_file="$SCRIPT_DIR/execution_log.md"
    
    # Create log file if it doesn't exist
    if [ ! -f "$log_file" ]; then
        cat > "$log_file" << 'EOF'
# Script Execution Log

Track all GitHub project management script executions here.

| Date | Script | Context | Outcome | Notes |
|------|--------|---------|---------|-------|
EOF
    fi
    
    # Append new entry
    echo "| $date | \`$script_name\` | $context | $outcome | $notes |" >> "$log_file"
    
    echo -e "${GREEN}✓ Logged execution to $log_file${NC}"
}

# Function to run script with logging
run_script_with_log() {
    local script_name="$1"
    local context="$2"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}Error: Script $script_name not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Running: $script_name${NC}"
    echo -e "${YELLOW}Context: $context${NC}"
    echo ""
    
    # Make sure script is executable
    chmod +x "$script_path"
    
    # Run the script
    if "$script_path"; then
        log_execution "$script_name" "$context" "✅ Success" "Executed via project_manager.sh"
        echo ""
        echo -e "${GREEN}✓ Script completed successfully${NC}"
    else
        log_execution "$script_name" "$context" "❌ Failed" "Error during execution"
        echo ""
        echo -e "${RED}✗ Script failed${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to show project statistics
show_statistics() {
    echo -e "${BLUE}📊 Project Statistics${NC}"
    echo ""
    
    # Issues by phase
    echo -e "${CYAN}Issues by Phase:${NC}"
    for i in {1..12}; do
        count=$(gh issue list --label "phase-$i" --json number --jq length 2>/dev/null)
        if [ "$count" -gt 0 ]; then
            echo -e "  Phase $i: ${GREEN}$count${NC} issues"
        fi
    done
    echo ""
    
    # Issues by status
    echo -e "${CYAN}Issues by Status:${NC}"
    open_count=$(gh issue list --state open --json number --jq length 2>/dev/null)
    closed_count=$(gh issue list --state closed --json number --jq length 2>/dev/null)
    echo -e "  Open: ${YELLOW}$open_count${NC}"
    echo -e "  Closed: ${GREEN}$closed_count${NC}"
    echo ""
    
    # Recent activity
    echo -e "${CYAN}Recent Activity (last 7 days):${NC}"
    gh issue list --state all --limit 10 --json number,title,updatedAt,state --jq '.[] | select(.updatedAt | fromdateiso8601 > (now - 7*24*3600)) | "  #\(.number): \(.title[:50])... (\(.state))"' 2>/dev/null
    echo ""
    
    read -p "Press Enter to continue..."
}

# Function to backup project state
backup_project_state() {
    local backup_dir="$SCRIPT_DIR/../backups"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$backup_dir/project_state_$timestamp.json"
    
    mkdir -p "$backup_dir"
    
    echo -e "${BLUE}Creating project backup...${NC}"
    
    # Export all issues
    gh issue list --state all --limit 1000 --json number,title,body,state,labels,milestone,assignees,createdAt,updatedAt > "$backup_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup created: $backup_file${NC}"
        
        # Also create a readable summary
        local summary_file="$backup_dir/project_summary_$timestamp.md"
        echo "# Project Backup Summary - $timestamp" > "$summary_file"
        echo "" >> "$summary_file"
        echo "## Statistics" >> "$summary_file"
        echo "- Total Issues: $(jq length "$backup_file")" >> "$summary_file"
        echo "- Open Issues: $(jq '[.[] | select(.state == "open")] | length' "$backup_file")" >> "$summary_file"
        echo "- Closed Issues: $(jq '[.[] | select(.state == "closed")] | length' "$backup_file")" >> "$summary_file"
        echo "" >> "$summary_file"
        
        log_execution "backup_project_state" "Manual backup" "✅ Success" "Backup saved to $backup_file"
    else
        echo -e "${RED}✗ Backup failed${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to show execution log
show_execution_log() {
    local log_file="$SCRIPT_DIR/execution_log.md"
    
    if [ -f "$log_file" ]; then
        echo -e "${BLUE}📋 Recent Script Executions:${NC}"
        echo ""
        # Show last 10 entries
        tail -n 10 "$log_file" | grep -v "^|.*|.*|.*|.*|$" | head -10
        echo ""
        echo -e "${CYAN}Full log: $log_file${NC}"
    else
        echo -e "${YELLOW}No execution log found${NC}"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

# Function to handle custom script execution
run_custom_script() {
    echo -e "${BLUE}Available Scripts:${NC}"
    echo ""
    ls -1 "$SCRIPT_DIR"/*.sh | grep -v project_manager.sh | while read script; do
        script_name=$(basename "$script")
        echo -e "  ${GREEN}$script_name${NC}"
    done
    echo ""
    
    read -p "Enter script name (without .sh): " script_name
    read -p "Enter context/description: " context
    
    if [ ! -z "$script_name" ]; then
        run_script_with_log "$script_name.sh" "$context"
    fi
}

# Main execution loop
main() {
    while true; do
        show_header
        get_project_status
        show_main_menu
        
        read -p "Select an option: " choice
        echo ""
        
        case $choice in
            1)
                run_script_with_log "create_github_milestones.sh" "Initial milestone setup"
                ;;
            2)
                run_script_with_log "create_github_issues_batch.sh" "Create issues from implementation plan"
                ;;
            3)
                echo -e "${YELLOW}Running full project setup...${NC}"
                run_script_with_log "create_github_milestones.sh" "Full setup - milestones"
                run_script_with_log "create_github_issues_batch.sh" "Full setup - issues"
                run_script_with_log "update_issues_backlog.sh" "Full setup - initial backlog"
                ;;
            4)
                run_script_with_log "update_project_status.sh" "Phase completion update"
                ;;
            5)
                run_script_with_log "update_issues_backlog.sh" "Manual backlog update"
                ;;
            6)
                run_custom_script
                ;;
            7)
                show_statistics
                ;;
            8)
                backup_project_state
                ;;
            9)
                show_execution_log
                ;;
            a)
                run_custom_script
                ;;
            b)
                echo -e "${BLUE}GitHub Actions Integration${NC}"
                echo "See scripts/README.md for automation setup"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            q)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Check dependencies
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install it with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Run main function
main