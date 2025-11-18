#!/bin/bash

# gh-project-watch.sh - Watch for plan changes and auto-sync

set -euo pipefail

PLAN_FILE="${PLAN_FILE:-planning/detailed_implementation_plan.md}"
INTERVAL="${INTERVAL:-300}" # Check every 5 minutes by default

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}[WATCH]${NC} $1"
}

# Get file hash
get_file_hash() {
    if command -v md5sum &> /dev/null; then
        md5sum "$1" | cut -d' ' -f1
    else
        md5 -q "$1"
    fi
}

# Watch for changes
watch_loop() {
    local last_hash=""
    
    log "Watching $PLAN_FILE for changes (checking every ${INTERVAL}s)"
    log "Press Ctrl+C to stop"
    
    while true; do
        if [[ -f "$PLAN_FILE" ]]; then
            local current_hash=$(get_file_hash "$PLAN_FILE")
            
            if [[ -z "$last_hash" ]]; then
                last_hash="$current_hash"
                log "Initial hash: $last_hash"
            elif [[ "$current_hash" != "$last_hash" ]]; then
                log "${YELLOW}Change detected!${NC}"
                log "Running sync..."
                
                if ./gh-project-sync.sh; then
                    log "${GREEN}✓ Sync completed successfully${NC}"
                else
                    log "${YELLOW}⚠ Sync failed${NC}"
                fi
                
                last_hash="$current_hash"
            fi
        else
            log "${YELLOW}Warning: $PLAN_FILE not found${NC}"
        fi
        
        sleep "$INTERVAL"
    done
}

# Main
main() {
    trap "log 'Stopping watch...'; exit 0" INT TERM
    watch_loop
}

main "$@"
