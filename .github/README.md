# AshReports GitHub Project Setup

This guide will help you set up GitHub project management for the AshReports implementation from scratch.

## Quick Start

```bash
# 1. Test authentication and setup
./.github/scripts/test_auth.sh

# 2. Create milestones for all phases
./.github/scripts/create_github_milestones.sh

# 3. Create issues from implementation plan
./.github/scripts/create_github_issues_batch.sh

# 4. Set initial project status
./.github/scripts/update_issues_backlog.sh
```

## Prerequisites

### 1. Install Required Tools

**GitHub CLI**:
```bash
# macOS
brew install gh

# Linux (Ubuntu/Debian)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

**jq (JSON processor)**:
```bash
# macOS
brew install jq

# Linux
sudo apt install jq
```

### 2. Authenticate with GitHub

```bash
gh auth login
```

Follow the prompts to authenticate. Make sure you have:
- Repository access permissions
- Project management permissions
- Issue creation permissions

## Detailed Setup Steps

### Step 1: Verify Authentication and Setup

```bash
./.github/scripts/test_auth.sh
```

This script checks:
- ✅ GitHub CLI installation
- ✅ Authentication status
- ✅ Repository access
- ✅ Required permissions
- ✅ Existing project boards

**If authentication fails**: Run `gh auth login` and ensure you have the necessary permissions.

### Step 2: Create Milestones

```bash
# Preview milestones (recommended first)
./.github/scripts/create_github_milestones.sh --dry-run

# Create milestones
./.github/scripts/create_github_milestones.sh
```

**What this does**:
- Automatically detects your implementation plan (`planning/detailed_implementation_plan.md`)
- Creates 14 phase-based milestones
- Extracts phase titles and descriptions from the plan

**Options**:
- `--dry-run`: Preview without creating
- `--help`: Show usage information
- Specify plan file: `./create_github_milestones.sh planning/implementation_plan.md`

### Step 3: Create GitHub Issues

```bash
# Preview issues (recommended first)
./.github/scripts/create_github_issues_batch.sh --dry-run

# Create all issues
./.github/scripts/create_github_issues_batch.sh
```

**What this does**:
- Parses tasks from implementation plan checkboxes
- Creates GitHub issues for each task
- Assigns appropriate labels (phase, complexity, priority)
- Links issues to correct milestones
- Creates "AshReports Implementation" project board

**Options**:
- `--dry-run`: Preview without creating
- `--phase N`: Create issues for specific phase only
- `--help`: Show usage information

### Step 4: Set Initial Project Status

```bash
./.github/scripts/update_issues_backlog.sh
```

**What this does**:
- Moves non-Phase 1 issues to "Backlog" status
- Keeps Phase 1 issues in "Ready" status
- Sets up proper project board workflow

## Alternative: Phase-by-Phase Setup

If you prefer to start with just Phase 1:

```bash
# Create milestones (all phases)
./.github/scripts/create_github_milestones.sh

# Create only Phase 1 issues
./.github/scripts/create_github_issues_batch.sh --phase 1

# No need for backlog script if only creating Phase 1
```

## During Development

### Tracking Progress

As you complete tasks:

1. **Mark tasks complete** in your implementation plan:
   ```markdown
   - [x] Completed task
   - [ ] Pending task
   ```

2. **Update project board**:
   ```bash
   # Preview updates
   ./.github/scripts/update_project_status.sh --dry-run
   
   # Update based on completed checkboxes
   ./.github/scripts/update_project_status.sh
   
   # Update specific phase only
   ./.github/scripts/update_project_status.sh --phase 1
   ```

### Phase Transitions

When completing a phase:

```bash
# Mark tasks as complete in implementation plan
# Then update project board
./.github/scripts/update_project_status.sh --phase 1

# Move to next phase
./.github/scripts/update_issues_backlog.sh
```

## Project Structure After Setup

You'll have:

- **14 Milestones**: One for each implementation phase
- **GitHub Issues**: All tasks from implementation plan
- **Project Board**: "AshReports Implementation" with proper columns
- **Labels**: 
  - Phase labels: `phase-1`, `phase-2`, etc.
  - Complexity: `complexity-low`, `complexity-medium`, `complexity-high`
  - Priority: `priority-low`, `priority-medium`, `priority-high`

## Accessing Your Project

After setup, access your project management at:

- **Project Board**: Your repository → Projects tab
- **Milestones**: Your repository → Issues tab → Milestones
- **Issues**: Your repository → Issues tab

The scripts will output direct URLs after successful execution.

## Troubleshooting

### Common Issues

1. **"Not authenticated with GitHub"**
   ```bash
   gh auth login
   ```

2. **"No implementation plan found"**
   - Ensure you have `planning/detailed_implementation_plan.md` or `planning/implementation_plan.md`
   - Run from project root directory

3. **Permission errors**
   - Ensure your GitHub token has repository and project permissions
   - Check that you're a collaborator on the repository

4. **Rate limiting**
   - Scripts include delays to avoid rate limits
   - If hit, wait a few minutes and retry

### Recovery

If something goes wrong:

```bash
# Reset project board status
./.github/scripts/update_issues_backlog.sh

# Reapply current progress
./.github/scripts/update_project_status.sh
```

## Script Reference

| Script | Purpose | Key Options |
|--------|---------|-------------|
| `test_auth.sh` | Verify authentication and permissions | None |
| `create_github_milestones.sh` | Create phase milestones | `--dry-run`, `--help` |
| `create_github_issues_batch.sh` | Create issues from implementation plan | `--dry-run`, `--phase N`, `--help` |
| `update_issues_backlog.sh` | Manage backlog status | None |
| `update_project_status.sh` | Update based on completed tasks | `--dry-run`, `--phase N`, `--help` |

For detailed script documentation, see [scripts/README.md](scripts/README.md).

## Best Practices

1. **Always use `--dry-run` first** to preview changes
2. **Commit implementation plan changes** before running status updates
3. **Run scripts from project root** directory
4. **Keep authentication tokens secure** and with minimal required permissions
5. **Use phase filtering** for focused updates during development

## Getting Help

- Run any script with `--help` for usage information
- Check [scripts/README.md](scripts/README.md) for detailed documentation
- Ensure you're authenticated: `./.github/scripts/test_auth.sh`