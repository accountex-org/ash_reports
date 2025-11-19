#!/bin/bash

# gh-project-sync.sh - Sync implementation plan changes with GitHub

set -euo pipefail

PLAN_FILE="${PLAN_FILE:-planning/detailed_implementation_plan.md}"
CACHE_DIR=".gh-project-cache"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[SYNC]${NC} $1"
}

# Compare current plan with cached version
check_plan_changes() {
    local cached_plan="$CACHE_DIR/last_plan.md"
    
    if [[ ! -f "$cached_plan" ]]; then
        log "No cached plan found. Full sync required."
        return 1
    fi
    
    if ! diff -q "$PLAN_FILE" "$cached_plan" > /dev/null; then
        log "Plan has changed. Analyzing differences..."
        return 1
    fi
    
    return 0
}

# Sync changes
sync_changes() {
    log "Syncing plan changes to GitHub..."
    
    # Create backup of current cache
    if [[ -d "$CACHE_DIR" ]]; then
        cp -r "$CACHE_DIR" "$CACHE_DIR.backup"
    fi
    
    # Run create command
    ./gh-project-manager.sh create
    
    # Cache current plan
    cp "$PLAN_FILE" "$CACHE_DIR/last_plan.md"
    
    # Clean backup
    rm -rf "$CACHE_DIR.backup"
}

# Main
main() {
    if check_plan_changes; then
        echo -e "${GREEN}✓${NC} Plan is already in sync with GitHub"
    else
        sync_changes
        echo -e "${GREEN}✓${NC} Sync completed successfully"
    fi
}

main "$@"
