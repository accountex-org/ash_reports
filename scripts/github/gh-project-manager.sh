#!/bin/bash

# GitHub Project Management Scripts for Implementation Plans
# Main script: gh-project-manager.sh

set -euo pipefail

# Configuration
PLAN_FILE="${PLAN_FILE:-planning/detailed_implementation_plan.md}"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
PROJECT_NUMBER="${PROJECT_NUMBER:-}"
CACHE_DIR=".gh-project-cache"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Ensure required tools are installed
check_dependencies() {
    local deps=("gh" "jq" "sed" "awk" "grep")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "$dep is required but not installed"
            exit 1
        fi
    done
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        error "gh CLI is not authenticated. Run 'gh auth login' first"
        exit 1
    fi
}

# Create cache directory
init_cache() {
    mkdir -p "$CACHE_DIR"
    mkdir -p "$CACHE_DIR/milestones"
    mkdir -p "$CACHE_DIR/issues"
    mkdir -p "$CACHE_DIR/parsed"
}

# Get or create project
get_project_number() {
    if [[ -n "$PROJECT_NUMBER" ]]; then
        echo "$PROJECT_NUMBER"
        return
    fi
    
    local project_name="Implementation Plan"
    local project_num=$(gh project list --owner "${REPO%/*}" --format json | \
        jq -r ".projects[] | select(.title == \"$project_name\") | .number")
    
    if [[ -z "$project_num" ]]; then
        log "Creating new project: $project_name"
        project_num=$(gh project create --owner "${REPO%/*}" --title "$project_name" \
            --format json | jq -r .number)
    fi
    
    echo "$project_num"
}

# Parse markdown file structure
parse_plan() {
    local plan_file="$1"
    local output_dir="$2"
    
    if [[ ! -f "$plan_file" ]]; then
        error "Plan file not found: $plan_file"
        exit 1
    fi
    
    # Create a parser script
    cat > "$output_dir/parser.awk" << 'EOF'
BEGIN {
    phase_num = 0
    section_num = 0
    in_task_list = 0
    current_section = ""
}

# Match Phase headers (## Phase N: Title)
/^## Phase [0-9]+:/ {
    phase_num++
    section_num = 0
    in_task_list = 0
    
    # Extract phase title
    phase_title = $0
    gsub(/^## Phase [0-9]+: /, "", phase_title)
    
    # Extract duration if present
    duration = ""
    if (match($0, /\*\*Duration: ([^*]+)\*\*/, arr)) {
        duration = arr[1]
    }
    
    print "PHASE|" phase_num "|" phase_title "|" duration > phases_file
}

# Match Section headers (### N.N Section Title)
/^### [0-9]+\.[0-9]+ / {
    section_num++
    in_task_list = 0
    current_section = $0
    gsub(/^### [0-9]+\.[0-9]+ /, "", current_section)
    
    print "SECTION|" phase_num "|" section_num "|" current_section > sections_file
}

# Match task lists under "Implementation Tasks:"
/^#### Implementation Tasks:/ {
    in_task_list = 1
    next
}

# End task list on next header
/^####/ {
    in_task_list = 0
}

# Capture tasks (lines starting with -)
in_task_list && /^- / {
    task = $0
    gsub(/^- /, "", task)
    print "TASK|" phase_num "|" section_num "|" task > tasks_file
}
EOF

    # Run the parser
    awk -v phases_file="$output_dir/phases.txt" \
        -v sections_file="$output_dir/sections.txt" \
        -v tasks_file="$output_dir/tasks.txt" \
        -f "$output_dir/parser.awk" "$plan_file"
    
    debug "Parsing complete. Found:"
    debug "  Phases: $(wc -l < "$output_dir/phases.txt" 2>/dev/null || echo 0)"
    debug "  Sections: $(wc -l < "$output_dir/sections.txt" 2>/dev/null || echo 0)"
    debug "  Tasks: $(wc -l < "$output_dir/tasks.txt" 2>/dev/null || echo 0)"
}

# Create or get milestone
create_or_get_milestone() {
    local title="$1"
    local description="$2"
    local cache_file="$CACHE_DIR/milestones/$(echo "$title" | sed 's/[^a-zA-Z0-9]/_/g')"
    
    # Check cache first
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return
    fi
    
    # Check if milestone exists
    local milestone_num=$(gh api \
        "/repos/$REPO/milestones" \
        --jq ".[] | select(.title == \"$title\") | .number")
    
    if [[ -z "$milestone_num" ]]; then
        log "Creating milestone: $title"
        milestone_num=$(gh api \
            --method POST \
            "/repos/$REPO/milestones" \
            --field title="$title" \
            --field description="$description" \
            --jq '.number')
    fi
    
    echo "$milestone_num" > "$cache_file"
    echo "$milestone_num"
}

# Create or get issue
create_or_get_issue() {
    local title="$1"
    local body="$2"
    local milestone="$3"
    local labels="$4"
    local cache_file="$CACHE_DIR/issues/$(echo "$title" | sed 's/[^a-zA-Z0-9]/_/g')"
    
    # Check cache first
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return
    fi
    
    # Check if issue exists
    local issue_num=$(gh issue list \
        --repo "$REPO" \
        --search "\"$title\" in:title" \
        --json number,title \
        --jq ".[] | select(.title == \"$title\") | .number" | head -1)
    
    if [[ -z "$issue_num" ]]; then
        log "Creating issue: $title"
        local cmd="gh issue create --repo \"$REPO\" --title \"$title\" --body \"$body\""
        
        if [[ -n "$milestone" ]]; then
            cmd="$cmd --milestone \"$milestone\""
        fi
        
        if [[ -n "$labels" ]]; then
            cmd="$cmd --label \"$labels\""
        fi
        
        issue_num=$(eval "$cmd" | grep -oE '[0-9]+$')
    fi
    
    echo "$issue_num" > "$cache_file"
    echo "$issue_num"
}

# Format task list for issue body
format_task_list() {
    local phase_num="$1"
    local section_num="$2"
    local tasks_file="$3"
    
    echo "## Implementation Tasks"
    echo ""
    
    if [[ -f "$tasks_file" ]]; then
        grep "^TASK|$phase_num|$section_num|" "$tasks_file" | while IFS='|' read -r _ _ _ task; do
            echo "- [ ] $task"
        done
    fi
    
    echo ""
    echo "## Testing"
    echo ""
    echo "- [ ] Unit tests completed"
    echo "- [ ] Integration tests completed"
    echo "- [ ] Documentation updated"
    echo ""
    echo "---"
    echo "_This issue was automatically generated from the implementation plan._"
}

# Create milestones and issues from parsed plan
create_from_plan() {
    local parsed_dir="$CACHE_DIR/parsed"
    
    log "Parsing implementation plan..."
    parse_plan "$PLAN_FILE" "$parsed_dir"
    
    # Get project number
    local project_num=$(get_project_number)
    log "Using project #$project_num"
    
    # Process phases (milestones)
    if [[ -f "$parsed_dir/phases.txt" ]]; then
        while IFS='|' read -r _ phase_num phase_title duration; do
            local milestone_title="Phase $phase_num: $phase_title"
            local milestone_desc="Implementation phase $phase_num"
            
            if [[ -n "$duration" ]]; then
                milestone_desc="$milestone_desc\n\nEstimated duration: $duration"
            fi
            
            local milestone_num=$(create_or_get_milestone "$milestone_title" "$milestone_desc")
            debug "Milestone #$milestone_num created/found for Phase $phase_num"
            
            # Process sections (issues) for this phase
            if [[ -f "$parsed_dir/sections.txt" ]]; then
                grep "^SECTION|$phase_num|" "$parsed_dir/sections.txt" | \
                while IFS='|' read -r _ _ section_num section_title; do
                    local issue_title="[$phase_num.$section_num] $section_title"
                    local issue_body=$(format_task_list "$phase_num" "$section_num" "$parsed_dir/tasks.txt")
                    local issue_labels="implementation,phase-$phase_num"
                    
                    local issue_num=$(create_or_get_issue "$issue_title" "$issue_body" \
                        "$milestone_num" "$issue_labels")
                    
                    debug "Issue #$issue_num created/found for Section $phase_num.$section_num"
                    
                    # Add issue to project
                    add_to_project "$project_num" "$issue_num"
                done
            fi
        done < "$parsed_dir/phases.txt"
    fi
    
    success "Project setup complete!"
}

# Add issue to project
add_to_project() {
    local project_num="$1"
    local issue_num="$2"
    
    # Check if already in project
    local in_project=$(gh project item-list "$project_num" \
        --owner "${REPO%/*}" \
        --format json | \
        jq -r ".items[] | select(.content.number == $issue_num) | .id")
    
    if [[ -z "$in_project" ]]; then
        debug "Adding issue #$issue_num to project"
        gh project item-add "$project_num" \
            --owner "${REPO%/*}" \
            --url "https://github.com/$REPO/issues/$issue_num"
    fi
}

# Update task checkboxes in an issue
update_task_status() {
    local issue_num="$1"
    local task_pattern="$2"
    local checked="$3"
    
    log "Updating task status in issue #$issue_num"
    
    # Get current issue body
    local body=$(gh issue view "$issue_num" --repo "$REPO" --json body -q .body)
    
    # Update checkbox status
    local new_body
    if [[ "$checked" == "true" ]]; then
        new_body=$(echo "$body" | sed "s/- \[ \] $task_pattern/- [x] $task_pattern/g")
    else
        new_body=$(echo "$body" | sed "s/- \[x\] $task_pattern/- [ ] $task_pattern/g")
    fi
    
    # Update issue if changed
    if [[ "$body" != "$new_body" ]]; then
        gh issue edit "$issue_num" --repo "$REPO" --body "$new_body"
        success "Updated task: $task_pattern"
    else
        warn "No changes needed for task: $task_pattern"
    fi
}

# List project status
show_status() {
    local project_num=$(get_project_number)
    
    log "Project Status for #$project_num"
    echo ""
    
    # Get milestones
    gh api "/repos/$REPO/milestones" --jq '.[] | "\(.title): \(.open_issues) open, \(.closed_issues) closed"'
    echo ""
    
    # Get project items
    log "Project Board Items:"
    gh project item-list "$project_num" \
        --owner "${REPO%/*}" \
        --format json | \
        jq -r '.items[] | "\(.content.title) - \(.status // "No Status")"'
}

# Clean cache
clean_cache() {
    log "Cleaning cache..."
    rm -rf "$CACHE_DIR"
    success "Cache cleaned"
}

# Main command dispatcher
main() {
    check_dependencies
    init_cache
    
    case "${1:-help}" in
        create)
            create_from_plan
            ;;
        update-task)
            if [[ $# -lt 4 ]]; then
                error "Usage: $0 update-task <issue-number> <task-pattern> <true|false>"
                exit 1
            fi
            update_task_status "$2" "$3" "$4"
            ;;
        status)
            show_status
            ;;
        clean)
            clean_cache
            ;;
        help)
            cat << EOF
GitHub Project Manager for Implementation Plans

Usage: $0 <command> [options]

Commands:
  create              Parse plan and create milestones/issues
  update-task         Update task checkbox status
  status              Show project status
  clean               Clean local cache
  help                Show this help message

Environment Variables:
  PLAN_FILE           Path to implementation plan (default: planning/detailed_implementation_plan.md)
  REPO                GitHub repository (default: current repo)
  PROJECT_NUMBER      GitHub project number (default: auto-detect/create)
  VERBOSE             Enable verbose output (default: false)

Examples:
  # Create project structure from plan
  $0 create

  # Update a task as completed
  $0 update-task 42 "Create Element entity types" true

  # Show project status
  $0 status

  # Clean cache and start fresh
  $0 clean
EOF
            ;;
        *)
            error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
