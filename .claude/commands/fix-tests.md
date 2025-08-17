# Systematic Test Failure Resolution

**IMPORTANT**: Use the **test-fixer** agent to systematically diagnose and fix
failing tests using proven methodology and expert consultation.

## Command Overview

This command delegates to the **test-fixer** agent, which provides systematic
test failure resolution methodology while consulting language-specific experts
and maintaining test suite integrity.

## How to Use

The **test-fixer** agent will:

1. **Analyze Test Failures**: Run comprehensive test analysis and categorize
   failures
2. **Consult Language Experts**: Get specific debugging guidance from
   **elixir-expert**, **research-agent**, etc.
3. **Apply Systematic Resolution**: Use proven debugging methodology for any
   programming language
4. **Ensure Quality**: Coordinate with **qa-reviewer** and
   **consistency-reviewer** for fix validation
5. **Track Progress**: Systematic one-test-at-a-time approach with progress
   tracking

## What the Agent Provides

### **Language-Agnostic Debugging Methodology**

- Proven systematic approach for any programming language and testing framework
- Focus-driven debugging (one test at a time)
- Root cause analysis rather than symptom fixes

### **Expert Consultation Integration**

- **For Elixir Projects**: Consults **elixir-expert** for ExUnit, Ash, and
  Phoenix debugging patterns
- **For Other Languages**: Uses **research-agent** for framework-specific
  debugging guidance
- **Pattern Consistency**: Uses **consistency-reviewer** to ensure fixes align
  with existing patterns

### **Quality Assurance**

- Systematic failure prioritization (infrastructure → core → integration → edge
  cases)
- Complete regression testing after each fix
- Expert validation of fix quality and approach

## Agent Workflow

The **test-fixer** agent follows this systematic approach:

### Phase 1: Failure Assessment & Expert Consultation

- Run comprehensive test failure analysis
- Consult appropriate language experts for debugging guidance
- Prioritize failures using proven framework

### Phase 2: Focused Test Resolution

- Isolate target test using focus mechanisms
- Apply systematic failure analysis with expert guidance
- Investigate root causes rather than symptoms

### Phase 3: Implementation & Verification

- Implement fixes based on expert consultation
- Verify fixes don't introduce regressions
- Apply language-specific quality checks

### Phase 4: Progress Tracking & Quality Assurance

- Remove focus tags and continue with next failure
- Track resolution progress and patterns
- Final quality verification with expert agents

## Success Criteria

The **test-fixer** agent ensures:

- ✅ **Root Cause Resolution**: Fixes address underlying issues, not just
  symptoms
- ✅ **Language-Appropriate Fixes**: Uses correct patterns and conventions
- ✅ **No Regressions**: Comprehensive testing prevents new issues
- ✅ **Pattern Consistency**: Fixes align with existing codebase patterns
- ✅ **Expert-Validated Approach**: Guidance from relevant language specialists

## Example Usage

Simply invoke the **test-fixer** agent and it will:

1. Identify your project's testing framework and common failure patterns
2. Consult the appropriate experts (**elixir-expert** for Elixir,
   **research-agent** for others)
3. Guide you through systematic test failure resolution
4. Ensure quality through expert review and regression testing

The agent handles the complexity of language-specific debugging while providing
universal systematic resolution principles.

---

## Reference: Detailed Methodology

The **test-fixer** agent contains the complete methodology. For reference,
here's a brief overview:

### Core Principles

1. **One Test at a Time**: Focus-driven debugging to avoid context switching
2. **Root Cause Analysis**: Fix underlying issues, not just symptoms
3. **Expert Consultation**: Always consult language experts for guidance
4. **Systematic Approach**: Proven prioritization and resolution framework

### Key Commands (Elixir Example)

```bash
# Run full test suite analysis
mix test

# Focus on single failing test
mix test --only focus --trace

# Quality checks after fixes
mix format && mix credo && mix dialyzer
```

**Note**: The complete methodology with detailed examples, patterns, and
language-specific guidance is contained within the **test-fixer** agent. Use the
agent for comprehensive test failure resolution.
