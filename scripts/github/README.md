# GitHub Project Management Scripts

A comprehensive set of bash scripts for managing GitHub projects based on markdown implementation plans. These scripts automatically create and maintain GitHub milestones, issues, and tasks from structured markdown documents.

## Features

- 📋 **Automatic Project Creation**: Parse markdown plans and create GitHub milestones and issues
- ✅ **Task Management**: Update task checkboxes directly from the command line
- 📊 **Progress Tracking**: Visual progress reports with completion bars
- 🔄 **Synchronization**: Keep GitHub in sync with plan changes
- 📦 **Bulk Operations**: Update multiple tasks at once
- 👁️ **File Watching**: Auto-sync when plan files change
- 💾 **Export/Import**: Export project state and import updates

## Prerequisites

- **gh CLI**: GitHub's official command line tool ([install](https://cli.github.com/))
- **jq**: Command-line JSON processor ([install](https://stedolan.github.io/jq/))
- Standard Unix tools: `sed`, `awk`, `grep`
- GitHub authentication: Run `gh auth login` before first use

## Installation

1. Clone or download the scripts to your project:

```bash
mkdir -p scripts/github
cd scripts/github
# Copy all script files here
chmod +x *.sh
```

2. Set up your implementation plan at `planning/detailed_implementation_plan.md`

## Scripts Overview

### 1. `gh-project-manager.sh` - Main Management Script

The core script that handles project creation and updates.

```bash
# Create project structure from plan
./gh-project-manager.sh create

# Update a specific task
./gh-project-manager.sh update-task 42 "Create Element entity types" true

# Show project status
./gh-project-manager.sh status

# Clean cache
./gh-project-manager.sh clean
```

### 2. `gh-project-sync.sh` - Synchronization

Sync changes from your implementation plan to GitHub.

```bash
# Sync any changes
./gh-project-sync.sh
```

### 3. `gh-project-progress.sh` - Progress Reports

Generate detailed progress reports with visual indicators.

```bash
# Show progress report
./gh-project-progress.sh
```

Output example:
```
=== Milestone Progress ===

Phase 1: Core Foundation                [██████████░░░░░░░░░░░░░░░░░░░░] 33% (2/6)
Phase 2: Data Integration               [████████████████████░░░░░░░░░░] 66% (4/6)

=== Task Progress by Issue ===

○ #1   [1.1] Spark DSL Foundation        [████████████████████░░░░░░░░░░] 66% (4/6)
✓ #2   [1.2] Band Hierarchy              [██████████████████████████████] 100% (5/5)
```

### 4. `gh-project-bulk-update.sh` - Bulk Updates

Update multiple tasks at once using a checklist file.

```bash
# Update from checklist
./gh-project-bulk-update.sh checklist.txt
```

### 5. `gh-project-export.sh` - Export Project State

Export current project state for backup or analysis.

```bash
# Export to default directory
./gh-project-export.sh

# Export to specific directory
./gh-project-export.sh ./exports/backup-2024
```

### 6. `gh-project-watch.sh` - File Watcher

Watch for plan changes and automatically sync.

```bash
# Watch with default interval (5 minutes)
./gh-project-watch.sh

# Watch with custom interval (60 seconds)
INTERVAL=60 ./gh-project-watch.sh
```

## Implementation Plan Format

The scripts expect a specific markdown structure:

```markdown
# Implementation Plan Title

## Phase 1: Phase Title
**Duration: 3-4 weeks**

### 1.1 Section Title

#### Implementation Tasks:
- First task description
- Second task description
- Third task description

#### Testing:
[Testing description]

### 1.2 Another Section

#### Implementation Tasks:
- Task one
- Task two

## Phase 2: Next Phase
**Duration: 2-3 weeks**

### 2.1 Section Title
...
```

### Structure Rules:

1. **Phases** become GitHub milestones
   - Format: `## Phase N: Title`
   - Optional duration: `**Duration: X-Y weeks**`

2. **Sections** become GitHub issues
   - Format: `### N.N Section Title`
   - Issues are labeled with `implementation` and `phase-N`

3. **Tasks** become checkboxes in issue bodies
   - Listed under `#### Implementation Tasks:`
   - Format: `- Task description`

## Environment Variables

Configure script behavior with environment variables:

```bash
# Path to implementation plan (default: planning/detailed_implementation_plan.md)
export PLAN_FILE="docs/implementation.md"

# GitHub repository (default: current repo)
export REPO="owner/repository"

# Project number (default: auto-detect or create)
export PROJECT_NUMBER="5"

# Enable verbose output
export VERBOSE=true

# File watch interval in seconds (default: 300)
export INTERVAL=60
```

## Example Workflow

### Initial Setup

```bash
# 1. Create your implementation plan
vim planning/detailed_implementation_plan.md

# 2. Create GitHub project structure
./gh-project-manager.sh create

# 3. View initial status
./gh-project-progress.sh
```

### Daily Development

```bash
# 1. Complete a task
./gh-project-manager.sh update-task 1 "Create Element entity types" true

# 2. Complete multiple tasks
cat > today-tasks.txt << EOF
#1 "Implement position and style schemas" true
#1 "Add element validation" true
#2 "Create query builder for report scope" true
EOF
./gh-project-bulk-update.sh today-tasks.txt

# 3. Check progress
./gh-project-progress.sh
```

### Plan Updates

```bash
# 1. Edit your plan
vim planning/detailed_implementation_plan.md

# 2. Sync changes
./gh-project-sync.sh

# Or use auto-sync
./gh-project-watch.sh &
```

### Reporting

```bash
# 1. Export current state
./gh-project-export.sh ./reports/week-1

# 2. Generate progress report
./gh-project-progress.sh > ./reports/week-1-progress.txt

# 3. Share exported files
ls ./reports/week-1/
# milestones.json
# issues.json
# project-report.md
# checklist.txt
```

## Example Files

### Example Checklist File (`checklist.txt`)

```
# Task Checklist for bulk updates
# Format: #<issue-number> "<task-pattern>" <true|false>

#1 "Create Ash.Report extension module" true
#1 "Define core DSL schema for reports" true
#1 "Implement basic section definitions" false
#1 "Create DSL entity modules for Band, Element, Variable" false

#2 "Create Band entity with type validation" true
#2 "Implement band ordering logic" false
#2 "Add band nesting support for groups" false
```

### Example Progress Output

```
GitHub Project Progress Report
Repository: myorg/ash-reports
Generated: 2024-01-15 10:30:45
================================================

=== Milestone Progress ===

Phase 1: Core Foundation                [██████████░░░░░░░░░░░░░░░░░░░░] 33% (2/6)
Phase 2: Data Integration               [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% (0/6)
Phase 3: Rendering Engine               [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% (0/5)

=== Task Progress by Issue ===

○ #1   [1.1] Spark DSL Foundation        [████████████░░░░░░░░░░░░░░░░░░] 40% (2/5)
○ #2   [1.2] Band Hierarchy              [██████░░░░░░░░░░░░░░░░░░░░░░░░] 20% (1/5)
○ #3   [1.3] Element System              [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% (0/4)

=== Overall Statistics ===

Milestones: 0/6 completed
Issues: 0/18 completed

Overall Progress: [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0%
```

## Tips and Best Practices

1. **Cache Management**: The scripts cache milestone and issue IDs to avoid duplicates. Clear cache with `./gh-project-manager.sh clean` if needed.

2. **Task Patterns**: When updating tasks, use exact text matches including punctuation. The pattern is case-sensitive.

3. **Permissions**: Ensure you have write access to the repository and projects.

4. **Large Plans**: For plans with many phases/sections, consider increasing GitHub API rate limits or adding delays.

5. **Backup**: Regularly export your project state using the export script.

## Troubleshooting

### "gh CLI is not authenticated"
Run `gh auth login` and follow the prompts.

### "Task not found" errors
Ensure the task pattern exactly matches the text in the issue, including punctuation and capitalization.

### "Rate limit exceeded"
Wait for the rate limit to reset or authenticate with a token that has higher limits.

### Cache issues
Clear the cache with `./gh-project-manager.sh clean` and try again.

## Contributing

Feel free to submit issues, fork, and create pull requests. Some areas for improvement:

- Support for custom fields in GitHub Projects
- Integration with GitHub Actions
- Support for sub-tasks (nested checkboxes)
- Cross-repository project management
- Gantt chart generation

## License

MIT License - Feel free to use and modify for your projects.
