# GitHub Project Management Scripts

This directory contains scripts for managing GitHub issues, milestones, and project boards throughout the AshReports development lifecycle.

## Script Categories

### 📋 Project Setup Scripts
- `create_github_milestones.sh` - Creates phase-based milestones from implementation plans (auto-detects plan file)
- `create_github_issues.sh` - Creates issues from implementation tasks (redirects to batch script)
- `create_github_issues_batch.sh` - Batch issue creation with advanced options (reads from implementation plans)

### 🔄 Status Update Scripts
- `update_project_status.sh` - Updates project board based on implementation plan progress
- `update_issues_backlog.sh` - Sets non-Phase 1 issues to backlog status
- `update_issues_backlog_simple.sh` - Simplified backlog management

### 🔧 Development Tools
- `test_auth.sh` - Test GitHub authentication and permissions
- `asdf_plugins.sh` - Environment setup utilities

## Usage Workflow

### Initial Project Setup
```bash
# 0. Test authentication and setup
./scripts/test_auth.sh

# 1. Create milestones for all phases (auto-detects plan)
./scripts/create_github_milestones.sh

# Alternative: Preview milestones first
./scripts/create_github_milestones.sh --dry-run

# Alternative: Use specific implementation plan
./scripts/create_github_milestones.sh planning/detailed_implementation_plan.md

# 2. Create issues from implementation plan (auto-detects plan)
./scripts/create_github_issues_batch.sh

# Alternative: Preview issues first
./scripts/create_github_issues_batch.sh --dry-run

# Alternative: Create only specific phase
./scripts/create_github_issues_batch.sh --phase 1

# 3. Set initial backlog status
./scripts/update_issues_backlog.sh
```

### During Development
```bash
# Update project board when phases complete
./scripts/update_project_status.sh
```

### Phase Transitions
```bash
# Move completed issues to backlog, promote next phase
./scripts/update_issues_backlog.sh
```

## Script Execution Log

Track script executions in this format:

| Date | Script | Phase/Context | Outcome | Notes |
|------|--------|---------------|---------|-------|
| 2025-01-24 | `update_project_status.sh` | Phase 1 Complete | ✅ 12 issues marked Done | Core DSL foundation completed |
| | | | | |

## Best Practices

### 1. **Version Control Integration**
- Always commit implementation plan changes before running status scripts
- Reference git commits in script execution logs
- Use descriptive commit messages that match script actions

### 2. **Script Execution Order**
```bash
# Recommended sequence for major updates:
git add planning/implementation_plan.md
git commit -m "Mark Phase X as completed"
./scripts/update_project_status.sh
git add scripts/execution_log.md  # if using log file
git commit -m "Updated project board for Phase X completion"
```

### 3. **Error Handling**
- Always run scripts in dry-run mode first (when available)
- Keep backups of project board states before major changes
- Test scripts on small subsets before full execution

### 4. **Automation Considerations**
- Scripts can be triggered by GitHub Actions on plan file changes
- Consider webhook integration for real-time updates
- Use script output for automated reporting

## Script Dependencies

All scripts require:
- `gh` (GitHub CLI) - **must be authenticated**
- `jq` - JSON processing
- `bash` 4.0+

### Authentication Setup

Before running any scripts, ensure you're authenticated with GitHub:

```bash
# Quick test of authentication and permissions
./scripts/test_auth.sh

# Or check manually:
gh auth status

# If not authenticated, login
gh auth login
```

**Important**: All scripts will now check authentication status and fail fast with clear error messages if not authenticated. This prevents cryptic errors and ensures proper permission handling.

#### New Authentication Test Script

Use `test_auth.sh` to verify your setup:
- ✅ GitHub CLI installation
- ✅ Authentication status
- ✅ Repository access
- ✅ Permission levels
- ✅ Existing project boards

#### Enhanced Milestone Creation

The `create_github_milestones.sh` script now includes:
- **Auto-detection** of implementation plan files
- **Support for multiple plans**: 
  - `planning/implementation_plan.md` (11 phases)
  - `planning/detailed_implementation_plan.md` (14 phases)
- **Dry-run mode** to preview milestones before creation
- **Dynamic parsing** of phase information from markdown files
- **Help documentation** with usage examples

#### Enhanced Issue Creation

The `create_github_issues_batch.sh` script now includes:
- **Auto-detection** of implementation plan files
- **Dynamic parsing** of task items from markdown files
- **Dry-run mode** to preview issues before creation
- **Phase filtering** to create issues for specific phases only
- **Smart labeling** with complexity and priority based on task content
- **Milestone integration** automatically links issues to correct milestones

## Troubleshooting

### Common Issues
1. **Authentication Errors**: 
   - **Error**: "Not authenticated with GitHub"
   - **Solution**: Run `gh auth login` and ensure you have repository permissions
2. **Rate Limiting**: Scripts include delays, but large operations may hit limits
3. **Permission Errors**: Ensure GitHub token has project management permissions
4. **Project Not Found**: Run setup scripts in correct order

### Recovery
```bash
# If project board gets corrupted:
./scripts/update_issues_backlog.sh  # Reset all to backlog
./scripts/update_project_status.sh  # Reapply current progress
```

## Future Enhancements

- [ ] Interactive script selector with current phase detection
- [ ] Automated phase progression based on completion criteria
- [ ] Integration with CI/CD for continuous project board updates
- [ ] Rollback capabilities for script actions
- [ ] Project board backup and restore functionality