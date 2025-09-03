# Phase 7.1: Project Structure and Dependencies Setup

**Duration**: 3-4 days  
**Complexity**: Medium  
**Priority**: High

## Overview

Phase 7.1 establishes the foundation for the comprehensive AshReportsDemo example application by creating a complete Phoenix project structure, configuring dependencies, and setting up the base domain architecture. This phase focuses exclusively on project scaffolding and infrastructure setup, providing a solid foundation for subsequent business logic implementation.

## Technical Analysis

### Current State Assessment

AshReports has completed comprehensive chart integration across all renderers (Phase 6.3) and now requires a standalone demonstration project that showcases all library capabilities in a realistic business scenario. The main library resides in `/lib/ash_reports/` with established patterns for:

- Domain-driven resource architecture using Ash Framework
- Multi-renderer support (HTML, HEEX, PDF, JSON) 
- Chart integration with comprehensive data processing
- Extensive testing infrastructure with Credo compliance

### Phoenix Project Architecture

The demo project will follow standard Phoenix conventions while leveraging Ash Framework patterns:

```
demo/                          # Standalone Phoenix application
├── lib/                       # Application source code
│   ├── ash_reports_demo/      # Main application namespace
│   │   ├── application.ex     # OTP application behavior
│   │   ├── domain.ex          # Ash domain configuration
│   │   ├── resources/         # Business resource definitions  
│   │   ├── data_generator.ex  # Faker-based data generation
│   │   └── reports/           # Report definitions
│   └── ash_reports_demo.ex    # Public API module
├── test/                      # Comprehensive test suite
├── config/                    # Environment configurations
└── mix.exs                    # Project dependencies and settings
```

### Dependency Management Strategy

The project requires careful dependency management to ensure compatibility:

**Core Dependencies:**
- `ash ~> 3.0` - Declarative resource framework
- `ash_postgres ~> 2.0` - PostgreSQL data layer (for ETS fallback)
- `phoenix ~> 1.7` - Web framework foundation
- `faker ~> 0.18` - Realistic data generation

**Development Dependencies:**
- `credo ~> 1.7` - Static analysis and code consistency
- `ex_doc ~> 0.31` - Documentation generation
- `benchee ~> 1.1` - Performance benchmarking

## Problem Definition

### Primary Challenge

The AshReports library currently lacks a comprehensive, standalone example that demonstrates all implemented features in a realistic business context. Developers evaluating or learning the library need:

1. **Complete Working Example**: Functioning application showcasing all features
2. **Realistic Data Patterns**: Business-like data relationships and scenarios  
3. **Performance Benchmarks**: Reference implementation for optimization
4. **Educational Resource**: Step-by-step demonstration of best practices

### Technical Requirements

**Isolation Requirements:**
- Standalone Phoenix application independent of main library
- Self-contained with minimal external dependencies
- ETS data layer for simplified deployment and testing
- No database setup required for quick evaluation

**Compatibility Requirements:**
- Full compatibility with current AshReports features
- Support for all four renderer types (HTML, HEEX, PDF, JSON)
- Chart integration capabilities preserved
- Zero-configuration startup for demo purposes

**Extensibility Requirements:**
- Clean architecture for adding new reports
- Modular design for selective feature demonstration
- Clear separation between infrastructure and business logic

## Solution Architecture

### Directory Structure Design

```
demo/
├── lib/
│   ├── ash_reports_demo/
│   │   ├── application.ex              # OTP Application
│   │   ├── domain.ex                   # Ash Domain Configuration
│   │   ├── resources/                  # Business Resources
│   │   │   ├── customer.ex            # Customer resource with relationships
│   │   │   ├── customer_address.ex    # Address resource
│   │   │   ├── customer_type.ex       # Customer classification
│   │   │   ├── product.ex             # Product catalog
│   │   │   ├── product_category.ex    # Product classification
│   │   │   ├── inventory.ex           # Inventory tracking
│   │   │   ├── invoice.ex             # Invoice header
│   │   │   └── invoice_line_item.ex   # Invoice line items
│   │   ├── data_generator.ex          # Faker Integration
│   │   └── reports/                   # Report Definitions
│   │       ├── customer_summary.ex    # Customer analytics
│   │       ├── product_inventory.ex   # Inventory reports  
│   │       ├── invoice_details.ex     # Invoice reporting
│   │       └── financial_summary.ex   # Financial analytics
│   └── ash_reports_demo.ex            # Public API
├── test/
│   ├── ash_reports_demo/
│   │   ├── resources/                  # Resource tests
│   │   ├── reports/                    # Report tests
│   │   └── integration/                # End-to-end tests
│   └── test_helper.exs                # Test configuration
├── config/
│   ├── config.exs                     # Base configuration
│   ├── dev.exs                        # Development settings
│   └── test.exs                       # Test environment
└── mix.exs                            # Project definition
```

### Ash Domain Architecture

```elixir
# AshReportsDemo.Domain
defmodule AshReportsDemo.Domain do
  @moduledoc """
  Main Ash domain for the AshReports demonstration application.
  
  This domain orchestrates all business resources and provides
  the foundation for report generation across multiple renderers.
  """
  
  use Ash.Domain
  
  resources do
    resource AshReportsDemo.Customer
    resource AshReportsDemo.CustomerAddress  
    resource AshReportsDemo.CustomerType
    resource AshReportsDemo.Product
    resource AshReportsDemo.ProductCategory
    resource AshReportsDemo.Inventory
    resource AshReportsDemo.Invoice
    resource AshReportsDemo.InvoiceLineItem
  end
end
```

### Data Layer Configuration

ETS-based data layer for zero-configuration operation:

```elixir
# All resources will use ETS data layer
data_layer AshEts.DataLayer do
  table :customers
  # ETS configuration for fast, in-memory operation
end
```

### Faker Integration Architecture

```elixir  
defmodule AshReportsDemo.DataGenerator do
  @moduledoc """
  GenServer-based data generation system using Faker library.
  
  Provides realistic business data with proper relationship
  integrity and configurable volume controls.
  """
  
  use GenServer
  
  @data_volumes %{
    small: %{customers: 10, products: 50, invoices: 25},
    medium: %{customers: 100, products: 200, invoices: 500}, 
    large: %{customers: 1000, products: 2000, invoices: 10000}
  }
  
  # Public API for data generation
  def generate_sample_data(volume \\ :medium)
  def reset_data()
  def seed_specific_scenario(scenario_name)
end
```

## Implementation Plan

### Phase 7.1.1: Phoenix Project Foundation (Day 1)

**Objectives:**
- Create standalone Phoenix application under `demo/` directory
- Configure basic project structure and dependencies
- Ensure zero-configuration startup capability

**Tasks:**
1. **Create Demo Directory Structure**
   ```bash
   mkdir -p demo/lib/ash_reports_demo/{resources,reports}
   mkdir -p demo/test/ash_reports_demo/{resources,reports,integration}
   mkdir -p demo/config
   ```

2. **Configure mix.exs**
   - Phoenix application setup
   - AshReports dependency (path: "../")
   - Faker dependency for data generation
   - Development and test dependencies
   - Proper application configuration

3. **Create Base Application Module**
   ```elixir
   # lib/ash_reports_demo.ex
   defmodule AshReportsDemo do
     @moduledoc """
     Public API for AshReports demonstration application.
     """
     
     defdelegate generate_sample_data(volume), to: AshReportsDemo.DataGenerator
     defdelegate reset_data(), to: AshReportsDemo.DataGenerator
     
     def run_report(report_name, params \\ %{}, options \\ []) do
       AshReports.Runner.run_report(
         AshReportsDemo.Domain,
         report_name,
         params,
         options
       )
     end
   end
   ```

**Success Criteria:**
- [ ] `mix compile` succeeds without warnings
- [ ] Basic Phoenix application starts successfully
- [ ] All dependencies resolve correctly
- [ ] Directory structure matches specification

### Phase 7.1.2: Faker Dependency Integration (Day 1)

**Objectives:**
- Integrate Faker library for realistic data generation
- Configure Faker for business data patterns
- Establish data generation infrastructure

**Tasks:**
1. **Configure Faker Dependency**
   ```elixir
   # mix.exs
   {:faker, "~> 0.18", only: [:dev, :test]}
   ```

2. **Create DataGenerator Module Structure**
   ```elixir  
   # lib/ash_reports_demo/data_generator.ex
   defmodule AshReportsDemo.DataGenerator do
     use GenServer
     
     # Configuration for realistic data patterns
     @business_domains ~w(example.com acme.org business.net company.com)
     @product_categories ~w(Electronics Clothing Home Kitchen Sports)
     @customer_types ~w(Premium Standard Bronze)
   end
   ```

3. **Basic Data Generation Functions**
   - Customer name and contact generation
   - Address generation with realistic patterns
   - Product catalog with SKUs and pricing
   - Invoice numbering and date patterns

**Success Criteria:**
- [ ] Faker library integrates without conflicts
- [ ] Basic data generation functions operational
- [ ] Realistic data patterns validated
- [ ] Memory usage remains stable during generation

### Phase 7.1.3: Demo Project Configuration (Day 2)

**Objectives:**
- Configure development, test, and production environments
- Set up ETS data layer for all resources
- Establish logging and debugging infrastructure

**Tasks:**
1. **Create Configuration Files**
   ```elixir
   # config/config.exs - Base configuration
   import Config
   
   config :ash_reports_demo,
     ash_domains: [AshReportsDemo.Domain]
     
   # Environment-specific configurations
   import_config "#{config_env()}.exs"
   ```

2. **Development Configuration**
   ```elixir
   # config/dev.exs
   import Config
   
   config :ash_reports_demo, AshReportsDemo.DataGenerator,
     auto_generate_on_start: true,
     default_volume: :medium
   
   config :logger, :console,
     level: :debug,
     format: "$date $time [$level] $message\n"
   ```

3. **Test Configuration**
   ```elixir
   # config/test.exs
   import Config
   
   config :ash_reports_demo, AshReportsDemo.DataGenerator,
     auto_generate_on_start: false,
     default_volume: :small
   
   config :logger, level: :warn
   ```

**Success Criteria:**
- [ ] All environment configurations load successfully
- [ ] ETS tables initialize properly
- [ ] Logging configuration operational
- [ ] Test environment isolates data properly

### Phase 7.1.4: Base Module Structure (Day 2-3)

**Objectives:**
- Create Ash domain configuration
- Establish base application module
- Set up OTP application structure
- Create foundation for resource definitions

**Tasks:**
1. **Create Ash Domain**
   ```elixir
   # lib/ash_reports_demo/domain.ex
   defmodule AshReportsDemo.Domain do
     use Ash.Domain
     
     resources do
       # Resource registrations will be added in Phase 7.2
     end
   end
   ```

2. **Create OTP Application**
   ```elixir
   # lib/ash_reports_demo/application.ex
   defmodule AshReportsDemo.Application do
     use Application
     
     def start(_type, _args) do
       children = [
         AshReportsDemo.DataGenerator
         # Additional supervisors will be added as needed
       ]
       
       opts = [strategy: :one_for_one, name: AshReportsDemo.Supervisor]
       Supervisor.start_link(children, opts)
     end
   end
   ```

3. **Create Base Resource Template**
   ```elixir
   # Template for resource creation in Phase 7.2
   defmodule AshReportsDemo.Resources.Base do
     defmacro __using__(_opts) do
       quote do
         use Ash.Resource,
           domain: AshReportsDemo.Domain,
           data_layer: AshEts.DataLayer
         
         # Common resource configuration
         ets do
           # ETS table configuration
         end
       end
     end
   end
   ```

**Success Criteria:**
- [ ] Ash domain compiles successfully
- [ ] OTP application starts and supervises processes
- [ ] Base resource template ready for Phase 7.2
- [ ] Clean module structure established

### Phase 7.1.5: Project Structure Validation (Day 3-4)

**Objectives:**
- Comprehensive testing of project structure
- Validation of dependency resolution
- Performance baseline establishment
- Documentation foundation

**Tasks:**
1. **Create Project Structure Tests**
   ```elixir
   # test/ash_reports_demo/project_structure_test.exs
   defmodule AshReportsDemo.ProjectStructureTest do
     use ExUnit.Case
     
     test "all required modules load successfully" do
       assert Code.ensure_loaded?(AshReportsDemo)
       assert Code.ensure_loaded?(AshReportsDemo.Domain) 
       assert Code.ensure_loaded?(AshReportsDemo.DataGenerator)
       assert Code.ensure_loaded?(AshReportsDemo.Application)
     end
     
     test "OTP application starts successfully" do
       # Test application startup
     end
     
     test "Faker integration operational" do
       # Test data generation capability
     end
   end
   ```

2. **Dependency Validation Tests**
   ```elixir
   # test/ash_reports_demo/dependency_test.exs  
   defmodule AshReportsDemo.DependencyTest do
     use ExUnit.Case
     
     test "all required dependencies available" do
       # Verify Ash, Phoenix, Faker availability
     end
     
     test "version compatibility validated" do
       # Check for version conflicts
     end
   end
   ```

3. **Performance Baseline**
   - Application startup time measurement
   - Memory usage baseline
   - Basic operation performance metrics

**Success Criteria:**
- [ ] All structure tests pass
- [ ] Zero compilation warnings  
- [ ] Credo analysis passes
- [ ] Performance baseline established

## Testing Strategy

### Unit Testing Approach

**Module Testing:**
- Each module has corresponding test file
- Public API functions comprehensively tested
- Error handling scenarios covered
- Mock dependencies where appropriate

**Configuration Testing:**
- Environment configurations load correctly
- Default values applied properly
- Invalid configurations handled gracefully
- ETS table initialization verified

### Integration Testing Strategy

**Application Integration:**
- Full application startup and shutdown
- Service supervision and recovery
- Cross-module communication
- Error propagation and handling

**Dependency Integration:**
- Faker library integration
- Ash framework compatibility
- Phoenix framework compatibility
- Version conflict detection

### Structure Validation Testing

**Directory Structure:**
```elixir
# test/support/structure_validator.ex
defmodule AshReportsDemo.Test.StructureValidator do
  @required_directories [
    "lib/ash_reports_demo",
    "lib/ash_reports_demo/resources", 
    "lib/ash_reports_demo/reports",
    "test/ash_reports_demo/resources",
    "test/ash_reports_demo/reports",
    "test/ash_reports_demo/integration",
    "config"
  ]
  
  @required_files [
    "lib/ash_reports_demo.ex",
    "lib/ash_reports_demo/application.ex",
    "lib/ash_reports_demo/domain.ex", 
    "lib/ash_reports_demo/data_generator.ex",
    "mix.exs",
    "config/config.exs",
    "config/dev.exs", 
    "config/test.exs"
  ]
  
  def validate_structure do
    # Implementation for structure validation
  end
end
```

**Automated Validation:**
```elixir
# test/project_structure_validation_test.exs
defmodule AshReportsDemo.ProjectStructureValidationTest do
  use ExUnit.Case
  alias AshReportsDemo.Test.StructureValidator
  
  test "all required directories exist" do
    assert StructureValidator.validate_structure() == :ok
  end
  
  test "all required files present" do
    missing_files = StructureValidator.find_missing_files()
    assert missing_files == [], "Missing files: #{inspect(missing_files)}"
  end
end
```

## Quality Assurance

### Code Quality Standards

**Credo Compliance:**
- All code passes Credo analysis with zero issues
- Consistent code formatting via `mix format`
- Documentation coverage for all public functions
- Proper module and function organization

**Static Analysis:**
```elixir
# .credo.exs adjustments for demo project
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "demo/lib/",
          "test/",
          "demo/test/"
        ]
      },
      checks: [
        # Specific checks for demo project
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Consistency.TabsOrSpaces, []}
      ]
    }
  ]
}
```

**Documentation Standards:**
- Module documentation with purpose and usage
- Function documentation with examples
- Type specifications for public functions
- README with setup and usage instructions

### Performance Standards

**Startup Performance:**
- Application startup < 2 seconds
- Memory usage < 50MB on startup
- ETS table initialization < 100ms
- Module compilation without warnings

**Runtime Performance:**
- Basic data generation < 1 second for small dataset
- Memory usage remains stable during operation
- No memory leaks in repeated operations
- Proper resource cleanup on shutdown

### Reliability Standards

**Error Handling:**
- Graceful handling of missing dependencies
- Clear error messages for configuration issues
- Proper supervision tree recovery
- No silent failures in critical operations

**Resource Management:**
- ETS tables properly managed
- Process memory usage bounded
- File handle management
- Network resource cleanup (if applicable)

## Risk Assessment

### Technical Risks

**Dependency Conflicts (Medium Risk)**
- *Risk*: Version conflicts between AshReports and demo dependencies
- *Mitigation*: Lock file management, comprehensive dependency testing
- *Contingency*: Version pinning, alternative dependency selection

**ETS Memory Management (Low Risk)** 
- *Risk*: Memory leaks with large datasets
- *Mitigation*: Proper ETS table cleanup, memory monitoring
- *Contingency*: Alternative data storage, memory limits

**Phoenix Integration Complexity (Low Risk)**
- *Risk*: Integration issues with Phoenix framework
- *Mitigation*: Minimal Phoenix usage, standard patterns
- *Contingency*: Standalone application without Phoenix

### Project Risks

**Scope Creep (Medium Risk)**
- *Risk*: Adding business logic during infrastructure phase
- *Mitigation*: Clear phase boundaries, focused deliverables
- *Contingency*: Strict scope enforcement, phase separation

**Configuration Complexity (Low Risk)**
- *Risk*: Over-complex configuration requirements
- *Mitigation*: Sensible defaults, minimal configuration
- *Contingency*: Hard-coded configurations, simplified setup

## Success Criteria

### Functional Requirements

**Core Infrastructure:**
- [ ] Phoenix application structure created under `demo/` directory
- [ ] Faker dependency integrated and operational
- [ ] ETS data layer configured for all resources
- [ ] Ash domain properly configured with resource registration
- [ ] OTP application starts and supervises processes correctly

**Configuration Management:**
- [ ] Development, test, and production configurations functional
- [ ] Environment-specific settings properly isolated
- [ ] Default values provide zero-configuration startup
- [ ] Configuration validation prevents invalid states

**Module Organization:**
- [ ] Clean separation between infrastructure and business logic
- [ ] Base module templates ready for Phase 7.2 extension
- [ ] Public API provides intuitive interface
- [ ] Proper module documentation and organization

### Technical Requirements

**Code Quality:**
- [ ] Zero compilation warnings across all environments
- [ ] All Credo checks pass without issues
- [ ] Consistent code formatting via `mix format`
- [ ] Comprehensive documentation coverage

**Performance Benchmarks:**
- [ ] Application startup time < 2 seconds
- [ ] Memory usage < 50MB on startup  
- [ ] Basic operations complete within acceptable timeframes
- [ ] No memory leaks during repeated operations

**Testing Coverage:**
- [ ] All modules have corresponding test coverage
- [ ] Integration tests validate cross-module functionality
- [ ] Structure validation tests ensure proper organization
- [ ] Error handling scenarios comprehensively tested

### Operational Requirements

**Developer Experience:**
- [ ] Simple setup process: `mix deps.get && iex -S mix`
- [ ] Clear error messages for common issues
- [ ] Intuitive API for common operations
- [ ] Comprehensive documentation and examples

**Maintainability:**
- [ ] Modular architecture supports easy extension
- [ ] Clear separation of concerns
- [ ] Consistent patterns throughout codebase
- [ ] Proper abstraction layers

## Implementation Timeline

### Day 1: Foundation and Dependencies ✅ **COMPLETED**
**Morning (4 hours):** ✅
- ✅ Create directory structure (complete demo/ project structure)
- ✅ Configure mix.exs with dependencies (Ash, Faker, Phoenix, testing tools)
- ✅ Set up basic Phoenix application structure (application.ex, domain.ex)

**Afternoon (4 hours):** ✅
- ✅ Integrate Faker dependency (ready for Phase 7.3 data generation)
- ✅ Create DataGenerator module skeleton (GenServer-based with volume controls)
- ✅ Basic configuration files (config.exs, dev.exs, test.exs)

### Day 2: Configuration and Base Modules
**Morning (4 hours):**
- Complete environment configurations
- Set up ETS data layer infrastructure  
- Create test helper and basic test structure

**Afternoon (4 hours):**
- Create Ash domain configuration
- Implement OTP application module
- Base resource template creation

### Day 3: Structure Validation and Testing
**Morning (4 hours):**
- Comprehensive test suite creation
- Structure validation tests
- Dependency validation tests

**Afternoon (4 hours):**
- Performance baseline establishment
- Error handling validation
- Integration testing

### Day 4: Polish and Documentation
**Morning (4 hours):**
- Credo compliance verification
- Documentation completion
- Final testing and validation

**Afternoon (2 hours):**
- Performance optimization
- Final review and cleanup

## Dependencies

### External Dependencies
- **Faker ~> 0.18**: Realistic data generation library
- **Phoenix ~> 1.7**: Web framework foundation (minimal usage)
- **Ash ~> 3.0**: Declarative resource framework
- **AshEts**: ETS data layer for Ash resources

### Internal Dependencies  
- **AshReports**: Main library (path dependency)
- **Existing configurations**: Credo, formatter, test setup

### Development Dependencies
- **ExDoc**: Documentation generation
- **Benchee**: Performance benchmarking  
- **Credo**: Static analysis and code quality

## Deliverables

### Code Deliverables
1. **Complete demo/ directory structure** with all required files and folders
2. **Phoenix application configuration** with proper dependency management
3. **Ash domain setup** ready for resource registration
4. **DataGenerator module** with Faker integration infrastructure
5. **Comprehensive test suite** with structure and integration validation

### Documentation Deliverables
1. **Setup instructions** in demo/README.md
2. **Module documentation** for all public APIs
3. **Configuration guide** for environment setup
4. **Development workflow** documentation

### Validation Deliverables
1. **Test coverage report** showing comprehensive coverage
2. **Performance baseline** measurements
3. **Credo analysis report** with zero issues  
4. **Dependency audit** confirming compatibility

## Conclusion

Phase 7.1 establishes the essential foundation for the AshReportsDemo application by creating a robust, well-structured Phoenix project with comprehensive dependency management and infrastructure setup. This phase prioritizes:

**Clean Architecture**: Modular design supporting future extension and maintenance
**Zero-Configuration Operation**: Sensible defaults enabling immediate evaluation
**Comprehensive Testing**: Robust validation ensuring reliability and maintainability  
**Developer Experience**: Intuitive setup and clear documentation

Upon completion of Phase 7.1, the project will have a solid infrastructure foundation ready for Phase 7.2's business logic implementation, with all dependencies resolved, configurations operational, and testing infrastructure in place.

The deliverables provide a professional-grade project structure that demonstrates best practices in Elixir/Phoenix development while showcasing the power and flexibility of the Ash Framework integrated with AshReports functionality.