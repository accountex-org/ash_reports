#!/bin/bash

# gh-project-export.sh - Export current project state

set -euo pipefail

REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
OUTPUT_DIR="${1:-./project-export-$(date +%Y%m%d-%H%M%S)}"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[EXPORT]${NC} $1"
}

# Export project data
export_project() {
    mkdir -p "$OUTPUT_DIR"
    
    log "Exporting milestones..."
    gh api "/repos/$REPO/milestones" > "$OUTPUT_DIR/milestones.json"
    
    log "Exporting issues..."
    gh issue list --repo "$REPO" --label "implementation" --limit 200 --json number,title,body,state,milestone,labels > "$OUTPUT_DIR/issues.json"
    
    log "Generating markdown report..."
    generate_markdown_report
    
    log "Generating task checklist..."
    generate_checklist
    
    echo -e "${GREEN}✓${NC} Export completed: $OUTPUT_DIR"
}

# Generate markdown report
generate_markdown_report() {
    cat > "$OUTPUT_DIR/project-report.md" << EOF
# Project Status Report

Generated: $(date)
Repository: $REPO

## Milestones

EOF
    
    jq -r '.[] | "### \(.title)\n\nOpen Issues: \(.open_issues) | Closed Issues: \(.closed_issues)\n"' \
        "$OUTPUT_DIR/milestones.json" >> "$OUTPUT_DIR/project-report.md"
    
    echo "## Issues by Milestone" >> "$OUTPUT_DIR/project-report.md"
    echo >> "$OUTPUT_DIR/project-report.md"
    
    # Group issues by milestone
    jq -r 'group_by(.milestone.title) | .[] | 
        "### \(.[0].milestone.title // "No Milestone")\n" + 
        (map("- [\(if .state == "CLOSED" then "x" else " " end)] #\(.number) - \(.title)") | join("\n")) + "\n"' \
        "$OUTPUT_DIR/issues.json" >> "$OUTPUT_DIR/project-report.md"
}

# Generate checklist for bulk updates
generate_checklist() {
    echo "# Task Checklist for bulk updates" > "$OUTPUT_DIR/checklist.txt"
    echo "# Format: #<issue-number> \"<task-pattern>\" <true|false>" >> "$OUTPUT_DIR/checklist.txt"
    echo >> "$OUTPUT_DIR/checklist.txt"
    
    jq -r '.[] | select(.body != null) | 
        "#\(.number) # \(.title)\n" + 
        (.body | split("\n") | map(select(test("^- \\[[ x]\\] "))) | 
        map(. as $line | 
            if test("^- \\[x\\] ") then 
                "#\(.number) \"" + ($line | sub("^- \\[x\\] "; "")) + "\" true"
            else 
                "#\(.number) \"" + ($line | sub("^- \\[ \\] "; "")) + "\" false"
            end
        ) | join("\n"))' \
        "$OUTPUT_DIR/issues.json" | \
        jq -Rs '.' | jq -r '.' >> "$OUTPUT_DIR/checklist.txt"
}

# Main
main() {
    log "Starting project export..."
    export_project
}

main "$@"
