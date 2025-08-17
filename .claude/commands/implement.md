# /implement

Execute the implementation for the current planning document using the
implementation-agent.

## Process

1. **Identify current work context**:

   - Check git branch to determine work type
   - Locate planning document in:
     - notes/features/<feature_name>.md
     - notes/fixes/<fix_name>.md
     - notes/tasks/<task_name>.md

2. **Use implementation-agent**:

   - The implementation-agent will:
     - Read the planning document
     - Execute implementation steps systematically
     - Consult specialized agents throughout the process
     - Update progress in the planning document
     - Ensure quality through continuous review

3. **Implementation workflow**:
   - Pre-implementation consultations with architecture-agent and elixir-expert
   - Step-by-step execution following the plan
   - Test development alongside features
   - Quality validation with review agents

**CRITICAL**: Implementation is NOT complete without working tests:

- Every feature/fix must have comprehensive test coverage
- Tests must pass before claiming any step complete
- Use test-developer for systematic test creation
- Never report implementation as "done" without working tests

## Usage Examples

```bash
# On a feature branch
git checkout feature/user-authentication
/implement  # Executes notes/features/user-authentication.md

# On a fix branch
git checkout fix/memory-leak
/implement  # Executes notes/fixes/memory-leak.md

# On a task branch
git checkout task/update-dependencies
/implement  # Executes notes/tasks/update-dependencies.md
```

## Key Benefits

- **Systematic execution**: Follows planning documents precisely
- **Expert guidance**: Consults appropriate agents for each component
- **Quality assurance**: Continuous review throughout implementation
- **Progress tracking**: Updates planning documents with status

The implementation-agent ensures that planned work is executed with high
quality, consistency, and proper architectural integration.
