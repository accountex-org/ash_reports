# DSL Test Refactoring Plan

## Problem Statement

All DSL tests currently use `Code.eval_string` to dynamically compile DSL strings at runtime. This approach has several critical issues:

1. **Incorrect Syntax**: Tests use `bands do`, `parameters do`, `variables do`, `groups do` syntax which **does not compile**
2. **Runtime Compilation**: Dynamic string evaluation doesn't properly handle Spark DSL macro expansion
3. **Maintenance Burden**: DSL strings are duplicated across tests and hard to maintain

## Root Cause Analysis

### Syntax Discovery

Through investigation, we discovered:

1. **Documentation shows wrapper syntax**:
   ```elixir
   bands do
     band :detail do
       type :detail
     end
   end
   ```

2. **Working demo uses direct syntax**:
   ```elixir
   band :detail do
     type :detail
   end
   ```

3. **Spark DSL defines entity collections** but doesn't generate wrapper functions:
   ```elixir
   entities: [
     bands: [band_entity()],      # Defines band entities
     parameters: [parameter_entity()]  # Defines parameter entities
   ]
   ```

4. **Conclusion**: Section wrappers (`bands do`, `parameters do`, etc.) are **not implemented**, despite appearing in documentation examples

### Correct DSL Syntax

```elixir
report :my_report do
  # Direct entity definitions (CORRECT)
  parameter :start_date, :date

  variable :total do
    type :sum
    expression :amount
  end

  group :by_region do
    level 1
    expression :region
  end

  band :detail do
    type :detail
  end
end
```

## Solution: Pre-Compiled Test Domains

Instead of using `Code.eval_string`, create pre-compiled test domain modules that:

1. Compile at test suite compile-time (not runtime)
2. Use correct DSL syntax
3. Can be directly tested with Spark introspection APIs
4. Are maintainable and reusable

### Created Test Domains

File: `test/support/dsl_test_domains.ex`

**Valid Domains** (for positive testing):
- `AshReports.Test.MinimalDomain` - Minimal valid report
- `AshReports.Test.MultiReportDomain` - Multiple reports
- `AshReports.Test.CompleteReportDomain` - All top-level fields
- `AshReports.Test.ParametersDomain` - Parameters with options
- `AshReports.Test.BandsDomain` - Multiple band types
- `AshReports.Test.BandOptionsDomain` - Band with all options
- `AshReports.Test.ElementsDomain` - All element types
- `AshReports.Test.VariablesDomain` - Variables with options
- `AshReports.Test.GroupsDomain` - Groups with options
- `AshReports.Test.FormatSpecsDomain` - Format specifications

**Invalid Domains** (for negative testing):
- `AshReports.Test.MissingTitleDomain` - Missing required title
- `AshReports.Test.MissingResourceDomain` - Missing driving_resource
- `AshReports.Test.NoDetailBandDomain` - Missing required detail band

## Refactoring Steps

### Phase 1: Test Infrastructure
- [x] Create pre-compiled test domains
- [x] Verify compilation
- [ ] Update test helpers to work with compiled modules
- [ ] Remove `Code.eval_string` helpers

### Phase 2: Refactor Test Files

#### Files to Refactor (9 total)

1. **test/ash_reports/dsl_test.exs** (1137 lines)
   - 36 tests using `assert_dsl_valid()` and `assert_dsl_error()`
   - Replace with direct module introspection
   - Example transformation:
     ```elixir
     # OLD (doesn't work)
     test "parses valid report" do
       dsl_content = """
       reports do
         report :test_report do
           title "Test"
           driving_resource Customer
           band :detail do
             type :detail
           end
         end
       end
       """
       assert_dsl_valid(dsl_content)
     end

     # NEW (works)
     test "parses valid report" do
       reports = AshReports.Info.reports(AshReports.Test.MinimalDomain)
       assert length(reports) == 1

       report = hd(reports)
       assert report.name == :test_report
       assert report.title == "Test Report"
     end
     ```

2. **test/ash_reports/schema_validation_test.exs**
   - Validation tests
   - Use invalid test domains for negative cases

3. **test/ash_reports/entities/band_test.exs**
   - Use `BandsDomain` and `BandOptionsDomain`

4. **test/ash_reports/entities/group_test.exs**
   - Use `GroupsDomain`

5. **test/ash_reports/entities/variable_test.exs**
   - Use `VariablesDomain`

6. **test/ash_reports/entities/element_test.exs**
   - Use `ElementsDomain`

7. **test/ash_reports/entities/report_test.exs**
   - Use various test domains

8. **test/ash_reports/recursive_entities_test.exs**
   - May need new recursive test domain

9. **test/ash_reports/minimal_test.exs**
   - Use `MinimalDomain`

### Phase 3: Cleanup
- [ ] Remove deprecated test helpers (`parse_dsl`, `assert_dsl_valid`, `assert_dsl_error`)
- [ ] Update test documentation
- [ ] Fix any remaining compilation warnings

## Testing Strategy

### Positive Tests (Valid DSL)
Use pre-compiled domains and assert on:
- `AshReports.Info.reports(domain)` - Get all reports
- Report struct fields (name, title, driving_resource, etc.)
- Nested entities (parameters, bands, variables, groups)
- Element properties

### Negative Tests (Invalid DSL)
Two approaches:
1. Use invalid pre-compiled domains (will fail at compile-time verification)
2. For runtime validation, create domains that compile but should fail verification

### Introspection APIs

```elixir
# Get reports
reports = AshReports.Info.reports(domain)

# Get specific report
report = AshReports.Info.report(domain, :report_name)

# Access nested entities
report.parameters  # List of parameters
report.bands       # List of bands
report.variables   # List of variables
report.groups      # List of groups

# Access band elements
band.elements      # List of elements (labels, fields, etc.)
```

## Benefits

1. **Correctness**: Tests use actual working DSL syntax
2. **Performance**: Compile-time vs runtime compilation
3. **Maintainability**: Reusable test domains, no string duplication
4. **Clarity**: Direct assertions on domain structure
5. **Type Safety**: Work with actual structs, not dynamic strings

## Risks & Mitigation

### Risk: Large Refactor Scope
- **Impact**: 9 files, ~2000+ lines affected
- **Mitigation**: Incremental approach, one test file at a time
- **Testing**: Run test suite after each file

### Risk: Test Coverage Gaps
- **Impact**: Might miss edge cases during refactor
- **Mitigation**: Review original test intent, ensure equivalent coverage

### Risk: Documentation Outdated
- **Impact**: Examples still show incorrect syntax
- **Mitigation**: Update DSL documentation as separate task

## Next Steps

1. **Immediate**:
   - Update `test_helpers.ex` to add domain introspection helpers
   - Start with `dsl_test.exs` (largest file)

2. **Short-term**:
   - Refactor remaining 8 test files
   - Remove deprecated helpers
   - Run full test suite

3. **Long-term**:
   - Fix documentation examples to use correct syntax
   - Consider: Should wrapper syntax be implemented or removed from docs?

## Time Estimate

- Phase 1 (Infrastructure): **COMPLETED** ✅
- Phase 2 (Test Refactoring): **4-6 hours**
  - dsl_test.exs: 2-3 hours
  - Other 8 files: 2-3 hours
- Phase 3 (Cleanup): **1 hour**

**Total**: 5-7 hours

## Success Criteria

- [ ] All 9 test files refactored
- [ ] No `Code.eval_string` usage in tests
- [ ] All DSL tests passing
- [ ] No compilation errors
- [ ] Test coverage maintained or improved
