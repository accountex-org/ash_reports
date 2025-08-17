# Agent-First Development Workflow

## Specialized Agents - Use Them Heavily!

**CRITICAL**: This system includes specialized agents that you should use
extensively. Do not attempt to work without consulting the appropriate
specialized agents first.

### Available Specialized Agents

#### **elixir-expert** - MANDATORY for All Elixir Work

- **When to use**: ALWAYS when working with Elixir, Phoenix, Ecto, Ash, or any
  Elixir libraries
- **Purpose**: Consults usage_rules.md and provides documentation-backed
  guidance
- **Never**: Attempt Elixir work without consulting this agent first
- **Tools**: `mix usage_rules.docs`, `mix usage_rules.search_docs`

#### **research-agent** - MANDATORY for Technical Research

- **When to use**: ALWAYS when researching documentation, APIs, libraries,
  frameworks, or technical information
- **Purpose**: Conducts comprehensive web research with authoritative sources
- **Never**: Make assumptions about unfamiliar technologies - research them
  first
- **Specializes in**: Official docs, API research, technology comparisons, usage
  patterns

#### **elixir-reviewer** - MANDATORY After Elixir Changes

- **When to use**: ALWAYS after making changes to Elixir code, Ash applications,
  Phoenix applications, or Ecto schemas
- **Purpose**: Runs comprehensive code quality checks, security analysis, and
  validation tools
- **Never**: Commit Elixir changes without running this agent first
- **Tools**: mix format, credo, dialyzer, sobelow, deps.audit, test coverage,
  security scanning

### Specialized Review Agents (Use in Parallel)

#### **factual-reviewer** - Implementation vs Planning Verification

- **Purpose**: Objective analysis comparing implementation against planning
  documents
- **Focus**: Factual assessment, functional correctness, documentation alignment

#### **qa-reviewer** - Testing & Quality Assurance

- **Purpose**: Test coverage analysis, edge case identification, functional
  validation
- **Focus**: Test gaps, error scenarios, quality assurance processes

#### **senior-engineer-reviewer** - Strategic Technical Review

- **Purpose**: Long-term architectural sustainability and strategic decisions
- **Focus**: Scalability (10x/100x), technical debt, future flexibility,
  operational complexity
- **Complements**: architecture-agent by providing strategic vs structural
  perspective

#### **security-reviewer** - Security & Vulnerability Analysis

- **Purpose**: Security vulnerability identification, attack vector assessment
- **Focus**: OWASP Top 10, secure coding practices, threat modeling

#### **consistency-reviewer** - Codebase Consistency

- **Purpose**: Pattern consistency, naming conventions, style guidelines
- **Focus**: Maintaining codebase coherence and established patterns

#### **redundancy-reviewer** - Duplication & Consolidation

- **Purpose**: Code duplication detection, refactoring opportunities
- **Focus**: Eliminating redundancy, improving maintainability

### Documentation Specialists

#### **documentation-expert** - MANDATORY for Documentation Creation

- **When to use**: ALWAYS when creating, updating, or structuring documentation
- **Purpose**: Applies industry-standard methodologies (Docs as Code, DITA,
  minimalism)
- **Specializes in**: API docs, architecture docs, user guides, developer docs
- **Standards**: Google/Microsoft style guides, WCAG accessibility, plain
  language

#### **documentation-reviewer** - Documentation Quality Assurance

- **When to use**: After creating or updating documentation
- **Purpose**: Reviews documentation for accuracy, completeness, and standards
  compliance
- **Focus**: Technical accuracy, readability, accessibility, maintainability
- **Evaluates**: Style guide compliance, documentation coverage, quality metrics

### Planning Specialists

#### **feature-planner** - Comprehensive Feature Planning

- **When to use**: For complex new functionality requiring detailed planning
- **Purpose**: Creates comprehensive feature plans with research integration and
  expert consultation
- **Consults**: research-agent, elixir-expert, senior-engineer-reviewer as
  needed
- **Output**: Structured planning documents in notes/features/

#### **fix-planner** - Focused Fix Planning

- **When to use**: For bug fixes, issues, or problem resolution requiring
  systematic analysis
- **Purpose**: Creates focused fix plans with root cause analysis and risk
  assessment
- **Consults**: elixir-expert, research-agent, security-reviewer as needed
- **Output**: Fix planning documents in notes/fixes/

#### **task-planner** - Lightweight Task Planning

- **When to use**: For simple tasks and quick work items
- **Purpose**: Creates minimal overhead planning while maintaining essential
  structure
- **Smart Escalation**: Recommends feature-planner or fix-planner for complex
  work
- **Output**: Task planning documents in notes/tasks/

### Architecture & Implementation Specialists

#### **architecture-agent** - Project Structure & Integration

- **When to use**: For code placement, module organization, and integration
  decisions
- **Purpose**: Analyzes existing structure and guides proper code organization
- **Consults**: elixir-expert, research-agent for framework-specific patterns
- **Focus**: File placement, module boundaries, integration patterns, structural
  consistency
- **Complements**: senior-engineer-reviewer by providing structural vs strategic
  perspective

#### **implementation-agent** - Plan Execution Specialist

- **When to use**: To execute planning documents (features, fixes, tasks)
- **Purpose**: Systematically implements plans while coordinating all agents
- **Consults**: architecture-agent, elixir-expert, test-developer, all reviewers
- **Focus**: Quality implementation following plans with continuous validation

### Methodology Specialists

#### **test-developer** - Systematic Test Development

- **When to use**: When developing comprehensive test coverage for new features
  or existing code
- **Purpose**: Language-agnostic test development methodology with expert
  consultation
- **Consults**: elixir-expert, research-agent, consistency-reviewer, qa-reviewer
- **Focus**: Incremental development, comprehensive coverage, quality assurance

#### **test-fixer** - Test Failure Resolution

- **When to use**: When systematically diagnosing and fixing failing tests
- **Purpose**: Language-agnostic debugging methodology with expert consultation
- **Consults**: elixir-expert, research-agent, consistency-reviewer, qa-reviewer
- **Focus**: Root cause analysis, systematic resolution, regression prevention

### Agent Usage Principles

1. **Agent-First Approach**: Always identify which specialized agent(s) to use
   before starting work
2. **Use Right-Sized Planning**: feature-planner → fix-planner → task-planner
   based on complexity
3. **Leverage Methodology Agents**: Use test-developer and test-fixer for
   systematic testing approaches
4. **Multiple Agent Consultation**: Complex tasks require multiple agents (e.g.,
   research-agent + elixir-expert)
5. **Trust Agent Expertise**: Follow agent recommendations rather than making
   assumptions
6. **Complete Elixir Workflow**: elixir-expert (before & during) → implement →
   elixir-reviewer (after)

# Development Workflow

## Command-Agent Integration

Commands now delegate to specialized agents rather than containing detailed
procedures:

- **feature.md** → Uses **feature-planner** for comprehensive planning
- **fix.md** → Uses **fix-planner** for focused problem resolution
- **task.md** → Uses **task-planner** for lightweight planning
- **add-tests.md** → Uses **test-developer** for systematic test development
- **fix-tests.md** → Uses **test-fixer** for test failure resolution
- **review.md** → Uses all review agents for comprehensive analysis

## Planning Document Creation

- **Use appropriate planning agent**: feature-planner → fix-planner →
  task-planner based on complexity
- **Agent consultations documented**: All planning agents automatically document
  expert consultations
- **Right-sized approach**: Each planner provides appropriate level of detail
  for work type
- **Save in correct location**: notes/features/, notes/fixes/, or notes/tasks/
- **Keep updated**: Mark tasks completed and update status as work progresses

## Git Workflow

- Check if already on an appropriate branch (feature/_, fix/_, task/\*)
- If not on an appropriate branch, create a new one
- Use conventional commits
- Make small commits while working, so we can better analyze changes and revert
  if necessary
- Do not reference claude in the commit messages

## Planning Examples

The specialized planning agents (**feature-planner**, **fix-planner**,
**task-planner**) contain comprehensive examples and templates. Each agent
provides:

- **Structured templates** for their specific work type
- **Agent consultation patterns** with clear examples
- **Complete workflows** from planning through implementation
- **Quality standards** and success criteria

Refer to the individual agent definitions for detailed examples and guidance.

## Critical Success Factors

1. **Plan thoroughly upfront** - saves time and prevents architectural issues
2. **Update documentation as you go** - don't leave it until the end
3. **Use the tools you create** - if you make a Makefile, use it consistently
4. **Test frequently** - both automated tests and manual UX testing
5. **Track progress visibly** - todos and planning docs show momentum and help
   prioritize
6. **Be critical and explain reasoning** - don't just agree with user requests,
   think through decisions

## Communication Patterns

### Be Critical and Analytical

- **Question decisions** rather than just implementing requests
- **Explain reasoning** behind technical choices
- **Point out potential issues** before they become problems
- **Suggest alternatives** when you see better approaches

### User Feedback Integration

- **Listen to user observations** about workflow issues (e.g., "why create
  Makefile if not using it?")
- **Learn from mistakes** and update processes accordingly
- **Ask clarifying questions** about requirements and priorities
- **Validate understanding** by explaining back what you're going to do
