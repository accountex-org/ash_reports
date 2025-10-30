# Phase 9.1: Additional Contex Chart Types - Implementation Plan

**Implementation Date**: October 2025
**Feature**: Sparkline and GanttChart Chart Types
**Status**: 📋 **PLANNED**
**Branch**: `feature/contex-additional-chart-types`

## Overview

Phase 9.1 implements two new chart types from Contex v0.5.0 into AshReports, expanding visualization capabilities with compact trend indicators (Sparkline) and project timeline visualization (GanttChart). This builds upon the existing 5 chart types (BarChart, LineChart, PieChart, AreaChart, ScatterPlot) following established patterns and behaviors.

## Problem Statement

AshReports currently supports 5 chart types for standard data visualization needs. However, two important use cases remain unaddressed:

### Use Case 1: Compact Dashboard Metrics
**Problem**: Dashboard tables and summary views need inline, compact trend indicators that show data patterns without consuming significant vertical space.

**Current Limitation**: Existing chart types (LineChart, AreaChart) are too large (default 400px height) for inline usage in tables or compact layouts.

**Solution**: Sparkline charts provide mini inline visualizations (default 20px high x 100px wide) perfect for:
- Table cells showing sales trends
- Dashboard metric cards with historical context
- Email reports with inline trend indicators
- Mobile-optimized compact displays

**Example Scenario**: A sales dashboard table showing each product's revenue trend inline:
```
Product       | Q4 Revenue | Trend
------------- | ---------- | ------------------
Product A     | $125,000   | [sparkline chart]
Product B     | $98,000    | [sparkline chart]
```

### Use Case 2: Project Timeline Visualization
**Problem**: Project management reports need to display task schedules, dependencies, and timelines in a visual format that shows when tasks occur and their durations.

**Current Limitation**: Existing chart types cannot effectively represent time-based scheduling with start/end dates and task grouping.

**Solution**: GanttChart provides timeline visualization showing:
- Task bars with start and end dates
- Task grouping by category/phase
- Visual timeline for project planning
- Resource allocation visualization

**Example Scenario**: A project status report showing development phases:
```
Phase        | Task              | Timeline
------------ | ----------------- | [===========]
Backend      | API Development   | [=========>    ]
Backend      | Database Design   | [=====>         ]
Frontend     | UI Components     | [   =======>   ]
Frontend     | Integration       | [      =====>  ]
```

## Solution Overview

Implement two new chart types following the existing AshReports.Charts.Types.Behavior pattern:

1. **Sparkline** - Lightweight mini-chart for inline trend visualization
2. **GanttChart** - Timeline chart for project scheduling and task management

Both types will:
- Implement the standard `AshReports.Charts.Types.Behavior` callbacks
- Register in `AshReports.Charts.Registry`
- Generate server-side SVG via Contex v0.5.0
- Work seamlessly with all existing renderers (HTML, PDF, HEEX, JSON)
- Support standard Config options (width, height, colors, theme)
- Include comprehensive test coverage

## Technical Details

### Architecture Overview

```
AshReports.Charts (Public API)
    ↓
Registry.get(:sparkline | :gantt)
    ↓
AshReports.Charts.Types.{Sparkline | GanttChart}
    ↓ build/2, validate/1
Contex.{Sparkline | GanttChart}
    ↓
Renderer.render/3
    ↓ to_svg/1
SVG String Output
```

### File Structure

```
lib/ash_reports/charts/types/
  ├── sparkline.ex          (NEW - Sparkline implementation)
  └── gantt_chart.ex        (NEW - GanttChart implementation)

test/ash_reports/charts/types/
  ├── sparkline_test.exs    (NEW - Sparkline unit tests)
  └── gantt_chart_test.exs  (NEW - GanttChart unit tests)

lib/ash_reports/charts/registry.ex  (UPDATE - Register new types)
test/ash_reports/charts/charts_test.exs  (UPDATE - Add integration tests)
```

### Implementation Details

#### 1. Sparkline Implementation

**Module**: `AshReports.Charts.Types.Sparkline`

**Data Format**: Accepts two formats for flexibility:
```elixir
# Format 1: Simple numeric array (preferred for simplicity)
data = [1, 2, 3, 5, 4, 6, 8, 7, 9]

# Format 2: Map array (consistent with other chart types)
data = [
  %{value: 1},
  %{value: 2},
  %{value: 3}
]
```

**Configuration Mapping**:
```elixir
# Config.width/height map to Sparkline dimensions
config = %Config{
  width: 100,   # Maps to Sparkline.width
  height: 20,   # Maps to Sparkline.height
  colors: ["#FF6B6B"]  # Maps to line/fill colors
}
```

**Key Implementation Notes**:
- Sparkline does NOT use `Contex.Dataset` - it accepts raw arrays
- Convert map format to numeric array in `build/2`
- Sparkline is standalone - no `Contex.Plot` wrapper needed
- Default colors: Green line with faded green fill (Contex default)
- Customization via `Sparkline.colours/3` for line, fill, spot colors

**Contex API Pattern**:
```elixir
# Simple standalone usage
Sparkline.new([1,2,3,4,5])
|> Sparkline.draw()
|> Sparkline.to_svg()

# With customization
Sparkline.new(data)
|> Sparkline.colours("#FF6B6B", "#FFE5E5", "#FF0000")  # line, fill, spot
|> Sparkline.draw()
```

**Validation Requirements**:
- Data must be list of numbers or maps with `:value` keys
- All values must be numeric (integers or floats)
- Minimum 2 data points required for meaningful visualization
- Reject nil, infinity, NaN values

**Default Dimensions**:
- Height: 20px (compact inline display)
- Width: 100px (reasonable inline width)
- Spot radius: 2px (data point marker)
- Line width: 1px (thin line for compact display)

#### 2. GanttChart Implementation

**Module**: `AshReports.Charts.Types.GanttChart`

**Data Format**: Standard Dataset with required columns:
```elixir
data = [
  %{
    category: "Backend",
    task: "API Development",
    start_date: ~U[2025-01-01 00:00:00Z],  # MUST be DateTime or NaiveDateTime
    end_date: ~U[2025-01-15 00:00:00Z],
    id: "task-1"  # Optional unique identifier
  },
  %{
    category: "Frontend",
    task: "UI Components",
    start_date: ~U[2025-01-10 00:00:00Z],
    end_date: ~U[2025-01-25 00:00:00Z],
    id: "task-2"
  }
]
```

**Configuration Mapping**:
```elixir
config = %Config{
  width: 800,
  height: 400,
  colors: ["#FF6B6B", "#4ECDC4", "#45B7D1"],  # Category colors
  show_data_labels: true  # Show task labels on bars
}
```

**Key Implementation Notes**:
- Uses standard `Contex.Dataset` pattern (like BarChart, LineChart)
- Requires proper DateTime/NaiveDateTime types - NO auto-conversion
- Pattern match DateTime types in `validate/1` for strict type checking
- Use `Contex.Plot` wrapper for consistent rendering
- Task grouping by category_col for organized display

**Contex API Pattern**:
```elixir
# Standard Contex pattern with Dataset + Plot
dataset = Dataset.new(data)

GanttChart.new(dataset,
  mapping: %{
    category_col: :category,
    task_col: :task,
    start_col: :start_date,
    finish_col: :end_date,
    id_col: :id  # Optional
  },
  padding: 2,
  show_task_labels: true,
  colour_palette: ["FF6B6B", "4ECDC4"]  # No # prefix
)
```

**Validation Requirements**:
- Data must be list of maps with required keys
- Required keys: `:category`, `:task`, `:start_date`, `:end_date`
- DateTime types: Must be `%DateTime{}` or `%NaiveDateTime{}` - pattern match strictly
- Start date must be before end date
- Reject string dates - force users to convert to DateTime types
- Minimum 1 task required

**DateTime Handling Philosophy**:
```elixir
# STRICT - No auto-conversion, fail fast with clear error
def validate(data) when is_list(data) do
  if Enum.all?(data, &valid_gantt_task?/1) do
    :ok
  else
    {:error, "All tasks must have DateTime/NaiveDateTime types for start_date and end_date"}
  end
end

defp valid_gantt_task?(%{
  category: _,
  task: _,
  start_date: %DateTime{} = start_dt,
  end_date: %DateTime{} = end_dt
}) do
  DateTime.compare(start_dt, end_dt) == :lt
end

defp valid_gantt_task?(%{
  category: _,
  task: _,
  start_date: %NaiveDateTime{} = start_dt,
  end_date: %NaiveDateTime{} = end_dt
}) do
  NaiveDateTime.compare(start_dt, end_dt) == :lt
end

defp valid_gantt_task?(_), do: false
```

**Default Options**:
- Padding: 2px between task bars
- Show task labels: true (display task names on bars)
- Color palette: Default theme colors applied to categories
- ID column: Optional for unique task identification

### 3. Registry Updates

**File**: `lib/ash_reports/charts/registry.ex`

**Changes Required**:
```elixir
defp register_default_types_direct do
  alias AshReports.Charts.Types.{
    BarChart,
    LineChart,
    PieChart,
    AreaChart,
    ScatterPlot,
    Sparkline,      # NEW
    GanttChart      # NEW
  }

  types = [
    {:bar, BarChart},
    {:line, LineChart},
    {:pie, PieChart},
    {:area, AreaChart},
    {:scatter, ScatterPlot},
    {:sparkline, Sparkline},   # NEW
    {:gantt, GanttChart}       # NEW
  ]

  # ... rest of registration logic
end
```

## Implementation Plan

### Step-by-Step Execution

#### Step 1: Feature Branch Creation
```bash
git checkout develop
git pull origin develop
git checkout -b feature/contex-additional-chart-types
```

**Verification**: Confirm on correct branch with `git branch --show-current`

#### Step 2: Implement Sparkline Chart Type

**Files to Create**:
- `lib/ash_reports/charts/types/sparkline.ex`

**Implementation Checklist**:
- [ ] Module definition with `@behaviour AshReports.Charts.Types.Behavior`
- [ ] Comprehensive `@moduledoc` with data format examples
- [ ] `build/2` callback implementation:
  - [ ] Convert map data `[%{value: n}]` to array `[n]`
  - [ ] Handle simple array data `[1,2,3]` directly
  - [ ] Map Config.width/height to Sparkline struct
  - [ ] Apply colors from Config or defaults
  - [ ] Return Sparkline struct (NOT wrapped in Plot)
- [ ] `validate/1` callback implementation:
  - [ ] Accept list of numbers
  - [ ] Accept list of maps with :value key
  - [ ] Verify all values are numeric
  - [ ] Reject empty lists, nil values, non-numeric values
  - [ ] Return `:ok` or `{:error, message}`
- [ ] Private helper functions:
  - [ ] `extract_values/1` - Convert maps to array
  - [ ] `get_colors/1` - Extract colors from Config
  - [ ] `valid_numeric?/1` - Check if value is number

**Reference Implementation Pattern**:
```elixir
defmodule AshReports.Charts.Types.Sparkline do
  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Config
  alias Contex.Sparkline

  @impl true
  def build(data, %Config{} = config) do
    # Convert to array format
    values = extract_values(data)

    # Get colors
    {line_color, fill_color, spot_color} = get_colors(config)

    # Build sparkline (no Dataset needed)
    Sparkline.new(values)
    |> Sparkline.colours(line_color, fill_color, spot_color)
    # Note: width/height handled by renderer via config
  end

  @impl true
  def validate(data) when is_list(data) and length(data) >= 2 do
    # Validate format and values
  end

  defp extract_values(data) when is_list(data) do
    # Handle [1,2,3] or [%{value: 1}, %{value: 2}]
  end
end
```

**Testing Strategy**:
- Unit tests for build/2 with both data formats
- Unit tests for validate/1 with valid/invalid inputs
- Integration test via Charts.generate/3
- SVG output validation (contains sparkline path)

#### Step 3: Write Sparkline Tests

**Files to Create**:
- `test/ash_reports/charts/types/sparkline_test.exs`

**Test Checklist**:
- [ ] Test module setup with ExUnit.Case
- [ ] `describe "build/2"` block:
  - [ ] Simple array format `[1,2,3,4,5]`
  - [ ] Map array format `[%{value: 1}, %{value: 2}]`
  - [ ] Returns Sparkline struct
  - [ ] Applies custom colors from config
  - [ ] Uses default colors when not specified
  - [ ] Handles float values
  - [ ] Handles negative values
- [ ] `describe "validate/1"` block:
  - [ ] Accepts simple numeric array
  - [ ] Accepts map array with :value keys
  - [ ] Rejects empty list
  - [ ] Rejects single-value list (needs at least 2)
  - [ ] Rejects non-numeric values
  - [ ] Rejects nil values
  - [ ] Rejects maps without :value key
  - [ ] Returns appropriate error messages

**Test Template**:
```elixir
defmodule AshReports.Charts.Types.SparklineTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.Sparkline
  alias AshReports.Charts.Config

  describe "build/2" do
    test "builds sparkline with simple array format" do
      data = [1, 2, 3, 5, 4, 6]
      config = %Config{width: 100, height: 20}

      result = Sparkline.build(data, config)

      assert %Contex.Sparkline{} = result
    end

    # ... more tests
  end

  describe "validate/1" do
    test "accepts simple numeric array" do
      data = [1, 2, 3, 4, 5]

      assert :ok = Sparkline.validate(data)
    end

    # ... more tests
  end
end
```

#### Step 4: Implement GanttChart Chart Type

**Files to Create**:
- `lib/ash_reports/charts/types/gantt_chart.ex`

**Implementation Checklist**:
- [ ] Module definition with `@behaviour AshReports.Charts.Types.Behavior`
- [ ] Comprehensive `@moduledoc` with DateTime requirements clearly documented
- [ ] `build/2` callback implementation:
  - [ ] Create Contex.Dataset from data
  - [ ] Detect column names (atom vs string keys)
  - [ ] Map category_col, task_col, start_col, finish_col, optional id_col
  - [ ] Apply colors from Config (strip # prefix for Contex)
  - [ ] Set show_task_labels from Config.show_data_labels
  - [ ] Return GanttChart struct
- [ ] `validate/1` callback implementation:
  - [ ] Verify list of maps with required keys
  - [ ] Pattern match DateTime/NaiveDateTime types (STRICT)
  - [ ] Verify start_date < end_date
  - [ ] Return clear error for string dates
  - [ ] Return `:ok` or `{:error, message}`
- [ ] Private helper functions:
  - [ ] `get_column_names/1` - Detect atom vs string keys
  - [ ] `get_colors/1` - Extract and format colors
  - [ ] `valid_gantt_task?/1` - Validate single task entry

**Reference Implementation Pattern**:
```elixir
defmodule AshReports.Charts.Types.GanttChart do
  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.Config
  alias Contex.{Dataset, GanttChart}

  @impl true
  def build(data, %Config{} = config) do
    # Standard Dataset pattern
    dataset = Dataset.new(data)

    # Detect column names
    {cat_col, task_col, start_col, finish_col, id_col} = get_column_names(data)

    # Get colors (strip # prefix)
    colors = get_colors(config)

    # Build GanttChart
    GanttChart.new(dataset,
      mapping: %{
        category_col: cat_col,
        task_col: task_col,
        start_col: start_col,
        finish_col: finish_col,
        id_col: id_col
      },
      padding: 2,
      show_task_labels: config.show_data_labels || true,
      colour_palette: colors
    )
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Strict DateTime validation with pattern matching
  end

  defp valid_gantt_task?(%{
    category: _,
    task: _,
    start_date: %DateTime{} = start_dt,
    end_date: %DateTime{} = end_dt
  }) do
    DateTime.compare(start_dt, end_dt) == :lt
  end

  defp valid_gantt_task?(%{
    category: _,
    task: _,
    start_date: %NaiveDateTime{} = start_dt,
    end_date: %NaiveDateTime{} = end_dt
  }) do
    NaiveDateTime.compare(start_dt, end_dt) == :lt
  end

  defp valid_gantt_task?(_), do: false
end
```

**DateTime Documentation**:
```elixir
@moduledoc """
GanttChart implementation using Contex.

## DateTime Requirements

⚠️ IMPORTANT: This chart type requires proper DateTime or NaiveDateTime types
for start_date and end_date fields. String dates are NOT supported and will
fail validation.

Convert string dates before passing to the chart:

    # GOOD - Proper DateTime types
    data = [
      %{
        task: "Task 1",
        start_date: ~U[2025-01-01 00:00:00Z],
        end_date: ~U[2025-01-15 00:00:00Z]
      }
    ]

    # BAD - String dates will fail validation
    data = [
      %{
        task: "Task 1",
        start_date: "2025-01-01",  # ❌ Will fail
        end_date: "2025-01-15"     # ❌ Will fail
      }
    ]

Use DateTime.from_iso8601/1 or similar functions to convert string dates.
"""
```

#### Step 5: Write GanttChart Tests

**Files to Create**:
- `test/ash_reports/charts/types/gantt_chart_test.exs`

**Test Checklist**:
- [ ] Test module setup with ExUnit.Case
- [ ] `describe "build/2"` block:
  - [ ] Standard task data with DateTime
  - [ ] Task data with NaiveDateTime
  - [ ] Returns GanttChart struct
  - [ ] Applies custom colors from config
  - [ ] Uses default colors when not specified
  - [ ] Handles optional id_col
  - [ ] Maps show_data_labels to show_task_labels
  - [ ] Detects atom vs string keys
- [ ] `describe "validate/1"` block:
  - [ ] Accepts valid DateTime format
  - [ ] Accepts valid NaiveDateTime format
  - [ ] Rejects empty list
  - [ ] Rejects missing required keys
  - [ ] Rejects string dates with clear error
  - [ ] Rejects end_date before start_date
  - [ ] Rejects non-DateTime types
  - [ ] Returns appropriate error messages

**Test Template**:
```elixir
defmodule AshReports.Charts.Types.GanttChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.GanttChart
  alias AshReports.Charts.Config

  describe "build/2" do
    test "builds gantt chart with DateTime values" do
      data = [
        %{
          category: "Phase 1",
          task: "Task A",
          start_date: ~U[2025-01-01 00:00:00Z],
          end_date: ~U[2025-01-15 00:00:00Z]
        }
      ]
      config = %Config{width: 800, height: 400}

      result = GanttChart.build(data, config)

      assert %Contex.GanttChart{} = result
    end

    # ... more tests
  end

  describe "validate/1" do
    test "accepts valid DateTime format" do
      data = [
        %{
          category: "Phase 1",
          task: "Task A",
          start_date: ~U[2025-01-01 00:00:00Z],
          end_date: ~U[2025-01-15 00:00:00Z]
        }
      ]

      assert :ok = GanttChart.validate(data)
    end

    test "rejects string dates with clear error" do
      data = [
        %{
          category: "Phase 1",
          task: "Task A",
          start_date: "2025-01-01",  # String, not DateTime
          end_date: "2025-01-15"
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert message =~ "DateTime/NaiveDateTime"
    end

    # ... more tests
  end
end
```

#### Step 6: Register Chart Types in Registry

**Files to Update**:
- `lib/ash_reports/charts/registry.ex`

**Changes Required**:
1. Add module aliases at top of register function
2. Add chart type entries to types list
3. Verify no conflicts with existing types

**Implementation**:
```elixir
# In register_default_types_direct/0 function

# Update alias list (around line 174)
alias AshReports.Charts.Types.{
  BarChart,
  LineChart,
  PieChart,
  AreaChart,
  ScatterPlot,
  Sparkline,      # ADD THIS
  GanttChart      # ADD THIS
}

# Update types list (around line 176)
types = [
  {:bar, BarChart},
  {:line, LineChart},
  {:pie, PieChart},
  {:area, AreaChart},
  {:scatter, ScatterPlot},
  {:sparkline, Sparkline},   # ADD THIS
  {:gantt, GanttChart}       # ADD THIS
]
```

**Verification**:
- No compilation errors
- Logger.debug messages show registration on app start
- Registry.list() includes :sparkline and :gantt

#### Step 7: Add Integration Tests

**Files to Update**:
- `test/ash_reports/charts/charts_test.exs`

**Tests to Add**:

```elixir
# In ChartsTest module, after existing chart type tests

describe "generate/3 - sparkline chart" do
  test "generates sparkline with simple array data" do
    data = [1, 2, 3, 5, 4, 6, 8, 7, 9, 11]
    config = %Config{width: 100, height: 20}

    assert {:ok, svg} = Charts.generate(:sparkline, data, config)
    assert is_binary(svg)
    assert String.contains?(svg, "<svg")
    assert String.contains?(svg, "</svg>")
  end

  test "generates sparkline with map array data" do
    data = [
      %{value: 10},
      %{value: 15},
      %{value: 12},
      %{value: 18}
    ]
    config = %Config{width: 100, height: 20}

    assert {:ok, svg} = Charts.generate(:sparkline, data, config)
    assert is_binary(svg)
    assert String.contains?(svg, "<svg")
  end

  test "returns error for invalid sparkline data" do
    data = ["not", "numbers"]
    config = %Config{}

    assert {:error, _reason} = Charts.generate(:sparkline, data, config)
  end
end

describe "generate/3 - gantt chart" do
  test "generates gantt chart with DateTime values" do
    data = [
      %{
        category: "Backend",
        task: "API Development",
        start_date: ~U[2025-01-01 00:00:00Z],
        end_date: ~U[2025-01-15 00:00:00Z]
      },
      %{
        category: "Frontend",
        task: "UI Design",
        start_date: ~U[2025-01-10 00:00:00Z],
        end_date: ~U[2025-01-25 00:00:00Z]
      }
    ]
    config = %Config{width: 800, height: 400}

    assert {:ok, svg} = Charts.generate(:gantt, data, config)
    assert is_binary(svg)
    assert String.contains?(svg, "<svg")
    assert String.contains?(svg, "</svg>")
  end

  test "generates gantt chart with NaiveDateTime values" do
    data = [
      %{
        category: "Phase 1",
        task: "Task A",
        start_date: ~N[2025-01-01 00:00:00],
        end_date: ~N[2025-01-15 00:00:00]
      }
    ]
    config = %Config{}

    assert {:ok, svg} = Charts.generate(:gantt, data, config)
    assert is_binary(svg)
    assert String.contains?(svg, "<svg")
  end

  test "returns error for string dates in gantt chart" do
    data = [
      %{
        category: "Phase 1",
        task: "Task A",
        start_date: "2025-01-01",  # Invalid: string instead of DateTime
        end_date: "2025-01-15"
      }
    ]
    config = %Config{}

    assert {:error, _reason} = Charts.generate(:gantt, data, config)
  end

  test "returns error for invalid date range" do
    data = [
      %{
        category: "Phase 1",
        task: "Task A",
        start_date: ~U[2025-01-15 00:00:00Z],
        end_date: ~U[2025-01-01 00:00:00Z]  # End before start
      }
    ]
    config = %Config{}

    assert {:error, _reason} = Charts.generate(:gantt, data, config)
  end
end

describe "list_types/0 - with new chart types" do
  test "includes sparkline and gantt in available types" do
    types = Charts.list_types()

    assert :sparkline in types
    assert :gantt in types
    assert length(types) == 7  # bar, line, pie, area, scatter, sparkline, gantt
  end
end

describe "type_available?/1 - with new chart types" do
  test "returns true for sparkline and gantt" do
    assert Charts.type_available?(:sparkline) == true
    assert Charts.type_available?(:gantt) == true
  end
end
```

#### Step 8: Update Documentation

**Files to Update**:
- `lib/ash_reports/charts/charts.ex` (module @moduledoc)

**Documentation Updates**:

Update the "Supported Chart Types" section:
```elixir
@moduledoc """
Main module for chart generation in AshReports.

# ... existing content ...

## Supported Chart Types

- `:bar` - Bar charts (grouped, stacked, horizontal)
- `:line` - Line charts (single/multi-series)
- `:pie` - Pie charts (with percentage labels)
- `:area` - Area charts (stacked areas for time-series)
- `:scatter` - Scatter plots (with optional regression lines)
- `:sparkline` - Compact inline trend charts (20px height)
- `:gantt` - Project timeline/Gantt charts (task scheduling)

# ... rest of existing content ...
"""
```

**Additional Documentation Considerations**:
- Consider adding CHANGELOG.md entry
- Consider updating README.md if it lists available chart types
- Update any API documentation or guides

#### Step 9: Run Full Test Suite

**Commands to Execute**:
```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test files for new chart types
mix test test/ash_reports/charts/types/sparkline_test.exs
mix test test/ash_reports/charts/types/gantt_chart_test.exs
mix test test/ash_reports/charts/charts_test.exs

# Check for warnings
mix compile --warnings-as-errors

# Run formatter
mix format

# Run linter (if using Credo)
mix credo --strict
```

**Success Criteria**:
- [ ] All existing tests pass (no regressions)
- [ ] New Sparkline tests pass (100% coverage)
- [ ] New GanttChart tests pass (100% coverage)
- [ ] Integration tests pass
- [ ] No compilation warnings
- [ ] Code formatted correctly
- [ ] Credo checks pass (if applicable)

**Common Issues to Check**:
- DateTime timezone handling in tests
- Color format consistency (# prefix handling)
- Empty data handling
- Registry registration order
- Renderer compatibility (HTML/PDF/HEEX/JSON)

#### Step 10: Verify Multi-Renderer Compatibility

**Manual Testing Checklist**:

Test each chart type with each renderer to ensure SVG compatibility:

**Sparkline + HTML Renderer**:
```elixir
data = [1, 2, 3, 5, 4, 6, 8, 7, 9]
config = %AshReports.Charts.Config{width: 100, height: 20}
{:ok, svg} = AshReports.Charts.generate(:sparkline, data, config)
# Verify: SVG renders correctly in HTML reports
```

**Sparkline + PDF Renderer**:
```elixir
# Verify: SVG embeds correctly in PDF via Typst
# Check: Height doesn't disrupt layout (compact 20px)
```

**Sparkline + HEEX Renderer**:
```elixir
# Verify: LiveView component displays sparkline inline
# Check: Responsive behavior in table cells
```

**Sparkline + JSON Renderer**:
```elixir
# Verify: JSON includes SVG string
# Check: Data structure matches API contract
```

**GanttChart + HTML Renderer**:
```elixir
data = [
  %{
    category: "Backend",
    task: "API Development",
    start_date: ~U[2025-01-01 00:00:00Z],
    end_date: ~U[2025-01-15 00:00:00Z]
  }
]
config = %AshReports.Charts.Config{width: 800, height: 400}
{:ok, svg} = AshReports.Charts.generate(:gantt, data, config)
# Verify: Timeline renders correctly
# Check: Task bars display properly
```

**GanttChart + All Other Renderers**:
- PDF: Verify timeline fits page width
- HEEX: Verify interactive responsiveness
- JSON: Verify data structure with DateTime serialization

## Success Criteria

### Functional Requirements ✅
- [ ] Sparkline chart type fully implemented
- [ ] GanttChart chart type fully implemented
- [ ] Both types registered in Registry
- [ ] Charts.generate/3 works with :sparkline and :gantt
- [ ] Charts.list_types/0 returns both new types
- [ ] Charts.type_available?/1 returns true for both

### Technical Requirements ✅
- [ ] Both implement AshReports.Charts.Types.Behavior
- [ ] Both generate valid SVG output
- [ ] Both work with all 4 renderers (HTML, PDF, HEEX, JSON)
- [ ] Both support Config.colors customization
- [ ] Both handle theme application correctly
- [ ] Both validate data strictly
- [ ] DateTime types strictly enforced for GanttChart
- [ ] Sparkline accepts both array formats

### Quality Requirements ✅
- [ ] All tests pass (100% suite success)
- [ ] New tests have good coverage (>95%)
- [ ] No compilation warnings
- [ ] Code follows existing patterns
- [ ] Documentation is comprehensive
- [ ] Error messages are clear and actionable

### Performance Requirements ✅
- [ ] Chart generation <100ms for typical data sizes
- [ ] Sparkline: <10ms for 50 data points
- [ ] GanttChart: <100ms for 20 tasks
- [ ] No memory leaks
- [ ] Efficient SVG generation

### Compatibility Requirements ✅
- [ ] Works with existing cache system
- [ ] Works with theme system
- [ ] Works with telemetry events
- [ ] No breaking changes to existing chart types
- [ ] Maintains API consistency

## Testing Strategy

### Unit Testing

**Sparkline Tests** (`sparkline_test.exs`):
- `build/2` with simple array format
- `build/2` with map array format
- `build/2` with custom colors
- `build/2` with default colors
- `validate/1` success cases (numeric arrays, map arrays)
- `validate/1` failure cases (empty, non-numeric, nil, single value)

**GanttChart Tests** (`gantt_chart_test.exs`):
- `build/2` with DateTime values
- `build/2` with NaiveDateTime values
- `build/2` with custom colors
- `build/2` with optional id_col
- `build/2` with show_data_labels config
- `validate/1` success cases (valid DateTime pairs)
- `validate/1` failure cases (string dates, invalid ranges, missing keys, wrong types)

**Expected Test Count**:
- Sparkline: ~15 tests
- GanttChart: ~20 tests
- Integration: ~10 tests
- Total: ~45 new tests

### Integration Testing

**Charts.generate/3 Integration** (`charts_test.exs`):
- Sparkline with simple array data
- Sparkline with map array data
- Sparkline with custom config
- Sparkline with theme
- Sparkline error cases
- GanttChart with DateTime
- GanttChart with NaiveDateTime
- GanttChart with multiple tasks
- GanttChart with custom config
- GanttChart error cases (string dates, invalid ranges)

**Registry Integration**:
- Verify types registered on app start
- Verify list_types/0 includes new types
- Verify type_available?/1 works correctly
- Verify get/1 returns correct modules

### Manual Testing

**Visual Inspection**:
1. Generate sample sparklines with various data patterns
2. Verify sparkline appears compact (20px height)
3. Generate sample Gantt charts with multiple tasks
4. Verify timeline rendering is accurate
5. Test with different theme configurations
6. Test in all renderer contexts (HTML, PDF, HEEX, JSON)

**Edge Cases**:
1. Empty data lists
2. Single data point (should fail validation)
3. Very large data sets (performance)
4. Extreme date ranges for Gantt
5. Unicode in task names
6. Special characters in categories

### Performance Testing

**Benchmarks to Run**:
```elixir
# Sparkline performance
data = Enum.to_list(1..100)
Benchee.run(%{
  "sparkline" => fn ->
    AshReports.Charts.generate(:sparkline, data, %Config{})
  end
})
# Target: <10ms for 100 points

# GanttChart performance
data = Enum.map(1..50, fn i ->
  %{
    category: "Phase #{div(i, 10)}",
    task: "Task #{i}",
    start_date: DateTime.add(~U[2025-01-01 00:00:00Z], i * 86400),
    end_date: DateTime.add(~U[2025-01-01 00:00:00Z], (i + 5) * 86400)
  }
end)
Benchee.run(%{
  "gantt" => fn ->
    AshReports.Charts.generate(:gantt, data, %Config{})
  end
})
# Target: <100ms for 50 tasks
```

## Risk Analysis

### Technical Risks

**Risk 1: Sparkline Standalone API Difference**
- **Severity**: Medium
- **Probability**: High
- **Impact**: May not integrate cleanly with Renderer.render/3
- **Mitigation**:
  - Renderer already handles different Contex types
  - Test early with renderer integration
  - May need special case in renderer for Sparkline type

**Risk 2: DateTime Serialization in JSON Renderer**
- **Severity**: Medium
- **Probability**: Medium
- **Impact**: DateTime types may not serialize correctly to JSON
- **Mitigation**:
  - JSON renderer may need DateTime encoding
  - Test JSON output thoroughly
  - Document DateTime handling requirements

**Risk 3: Contex API Instability**
- **Severity**: Low
- **Probability**: Low
- **Impact**: Contex API could change in future versions
- **Mitigation**:
  - Currently on stable v0.5.0
  - Version pinned in mix.exs
  - Monitor Contex releases

### Implementation Risks

**Risk 4: DateTime Validation Too Strict**
- **Severity**: Low
- **Probability**: Medium
- **Impact**: Users may struggle with DateTime conversion
- **Mitigation**:
  - Provide clear error messages
  - Document DateTime requirements prominently
  - Consider helper function in docs for common conversions

**Risk 5: Test Coverage Gaps**
- **Severity**: Medium
- **Probability**: Low
- **Impact**: Edge cases not tested could cause runtime failures
- **Mitigation**:
  - Comprehensive test plan (see Testing Strategy)
  - Code review for edge cases
  - Manual testing with edge case data

### Integration Risks

**Risk 6: Renderer Compatibility Issues**
- **Severity**: High
- **Probability**: Low
- **Impact**: Charts may not render in one or more renderers
- **Mitigation**:
  - Test with all 4 renderers early (Step 10)
  - SVG is standard format - should work everywhere
  - Have fallback strategies ready

**Risk 7: Cache Key Generation**
- **Severity**: Low
- **Probability**: Low
- **Impact**: Cache key generation may not work with DateTime types
- **Mitigation**:
  - Cache system uses :erlang.term_to_binary/1 which handles DateTime
  - Test cache hit/miss scenarios
  - Monitor cache telemetry

## Estimation

### Time Estimates

**Development Time**:
- Sparkline implementation: 3-4 hours
- Sparkline tests: 2-3 hours
- GanttChart implementation: 4-5 hours
- GanttChart tests: 3-4 hours
- Registry updates: 0.5 hours
- Integration tests: 2-3 hours
- Documentation: 1-2 hours
- Testing and verification: 2-3 hours

**Total Estimated Time**: 18-25 hours (2-3 days)

**Breakdown by Phase**:
- Phase 1 (Sparkline): 5-7 hours
- Phase 2 (GanttChart): 7-9 hours
- Phase 3 (Integration): 6-9 hours

### Complexity Assessment

**Sparkline**: ⭐⭐ (Low-Medium)
- Simpler API (no Dataset)
- Straightforward validation
- Minimal configuration options
- Well-documented Contex API

**GanttChart**: ⭐⭐⭐ (Medium)
- Standard Dataset pattern
- DateTime handling adds complexity
- More configuration options
- Requires date range validation

**Overall Phase**: ⭐⭐⭐ (Medium)
- Follows established patterns
- Clear requirements
- Good test coverage needed
- Multiple integration points

## Dependencies

### External Dependencies
- `contex ~> 0.5.0` - Already in deps, provides Sparkline and GanttChart modules
- No new dependencies required

### Internal Dependencies
- `AshReports.Charts.Types.Behavior` - Existing behavior interface
- `AshReports.Charts.Config` - Existing configuration struct
- `AshReports.Charts.Registry` - Existing registry for chart types
- `AshReports.Charts.Renderer` - Existing renderer for SVG generation
- All existing renderers (HTML, PDF, HEEX, JSON)

### Development Dependencies
- ExUnit - Test framework (already available)
- Benchee - Performance testing (optional, may need to add)

## Future Enhancements

### Potential Future Work (Out of Scope for Phase 9.1)

**Sparkline Enhancements**:
- Add reference line support (target values)
- Add data point highlighting (min/max indicators)
- Support multiple sparklines in single chart (comparison)
- Add smooth curve option (currently linear)
- Add threshold zones (colored regions)

**GanttChart Enhancements**:
- Add task dependencies (arrows between tasks)
- Add milestone markers (key dates)
- Add progress indicators (partial completion)
- Add resource allocation visualization
- Add interactive tooltips (for web renderers)
- Add task grouping/hierarchy (nested categories)
- Add current date indicator line

**General Enhancements**:
- Add animation support (for LiveView renderer)
- Add accessibility features (ARIA labels, screen reader support)
- Add export format options (PNG rasterization via external tool)
- Add chart templating system (predefined layouts)

### SimplePie Chart Note

**Decision**: SimplePie chart was explicitly skipped in this phase.

**Rationale**:
- Redundant with existing PieChart implementation
- SimplePie is a simplified version with fewer features
- Existing PieChart covers all SimplePie use cases
- No compelling reason to add a less-featured alternative

**Future Consideration**: If user feedback indicates need for ultra-lightweight pie chart variant, can revisit in future phase.

## Appendix

### Data Format Reference

#### Sparkline Data Formats

**Format 1: Simple Array** (Recommended)
```elixir
data = [1, 2, 3, 5, 4, 6, 8, 7, 9, 11, 10]

# Use case: Quick inline trends
# Pros: Minimal code, clear intent
# Cons: No labels, just values
```

**Format 2: Map Array** (Consistent)
```elixir
data = [
  %{value: 1},
  %{value: 2},
  %{value: 3},
  %{value: 5}
]

# Use case: Consistency with other chart types
# Pros: Matches AshReports patterns
# Cons: More verbose
```

#### GanttChart Data Format

**Standard Format** (Required)
```elixir
data = [
  %{
    category: "Backend Development",
    task: "API Implementation",
    start_date: ~U[2025-01-01 09:00:00Z],
    end_date: ~U[2025-01-15 17:00:00Z],
    id: "task-001"  # Optional
  },
  %{
    category: "Backend Development",
    task: "Database Schema",
    start_date: ~U[2025-01-02 09:00:00Z],
    end_date: ~U[2025-01-10 17:00:00Z],
    id: "task-002"
  },
  %{
    category: "Frontend Development",
    task: "UI Components",
    start_date: ~U[2025-01-08 09:00:00Z],
    end_date: ~U[2025-01-20 17:00:00Z],
    id: "task-003"
  }
]

# Use case: Project timeline visualization
# Requirements:
# - category: String, groups related tasks
# - task: String, task name/description
# - start_date: DateTime/NaiveDateTime, task start
# - end_date: DateTime/NaiveDateTime, task end
# - id: Optional string, unique task identifier
```

**DateTime Conversion Examples**:
```elixir
# From ISO8601 string
{:ok, dt, _offset} = DateTime.from_iso8601("2025-01-01T09:00:00Z")

# From Unix timestamp
DateTime.from_unix!(1735722000)

# From Date + Time
date = ~D[2025-01-01]
time = ~T[09:00:00]
NaiveDateTime.new!(date, time)

# Current time
DateTime.utc_now()
```

### Configuration Examples

#### Sparkline Configuration

**Minimal** (Uses defaults):
```elixir
config = %AshReports.Charts.Config{
  width: 100,
  height: 20
}
# Result: Default green line/fill, compact size
```

**Custom Colors**:
```elixir
config = %AshReports.Charts.Config{
  width: 120,
  height: 25,
  colors: ["#FF6B6B"]  # Red sparkline
}
# Result: Red line with faded red fill
```

**Theme-Based**:
```elixir
config = %AshReports.Charts.Config{
  width: 100,
  height: 20,
  theme_name: :corporate
}
# Result: Uses corporate theme colors
```

#### GanttChart Configuration

**Minimal** (Uses defaults):
```elixir
config = %AshReports.Charts.Config{
  width: 800,
  height: 400
}
# Result: Default colors, task labels shown
```

**Custom Styling**:
```elixir
config = %AshReports.Charts.Config{
  title: "Project Timeline - Q1 2025",
  width: 1000,
  height: 600,
  colors: ["#3498db", "#e74c3c", "#2ecc71"],  # Custom category colors
  show_data_labels: true,  # Show task names on bars
  x_axis_label: "Timeline",
  y_axis_label: "Tasks"
}
# Result: Titled chart with custom colors and labels
```

**Theme-Based**:
```elixir
config = %AshReports.Charts.Config{
  title: "Development Schedule",
  width: 900,
  height: 500,
  theme_name: :minimal,
  show_grid: false
}
# Result: Minimal theme, no grid lines
```

### Code Review Checklist

**Before Requesting Review**:
- [ ] All files formatted with `mix format`
- [ ] No compilation warnings
- [ ] All tests passing locally
- [ ] No debug code (IO.inspect, etc.) remaining
- [ ] Documentation complete and accurate
- [ ] Error messages are clear and actionable
- [ ] Code follows existing patterns
- [ ] No hardcoded values (use Config)
- [ ] DateTime handling is explicit and strict

**Review Focus Areas**:
- Behavior callback implementations
- Data validation logic
- Error message clarity
- Test coverage completeness
- Documentation accuracy
- Pattern consistency with existing types

### Troubleshooting Guide

**Problem**: Sparkline not rendering
- Check: Data is numeric array or maps with :value key
- Check: At least 2 data points provided
- Check: No nil or NaN values in data
- Debug: Inspect Sparkline struct returned from build/2

**Problem**: GanttChart validation failing
- Check: Using DateTime/NaiveDateTime types (not strings)
- Check: start_date is before end_date
- Check: All required keys present (category, task, start_date, end_date)
- Debug: Inspect validation error message for specific issue

**Problem**: Charts not showing in renderer
- Check: Registry registration successful (check logs)
- Check: SVG output is valid (contains <svg> tags)
- Check: Renderer supports SVG embedding
- Debug: Test with Charts.generate/3 directly, check result

**Problem**: Colors not applied
- Check: Colors array in Config is not empty
- Check: Colors are valid hex format (#RRGGBB)
- Check: Contex expects colors without # prefix (handled in get_colors/1)
- Debug: Inspect config colors in build/2

**Problem**: Test failures
- Check: Async test conflicts (use async: true only if safe)
- Check: DateTime timezone issues (use UTC consistently)
- Check: Test data matches required format exactly
- Debug: Run single test with `mix test path/to/test.exs:line_number`

---

## Summary

Phase 9.1 adds two valuable chart types to AshReports:

1. **Sparkline**: Compact inline trend visualization (20px x 100px default) perfect for dashboard tables, email reports, and mobile displays. Accepts simple numeric arrays or map format, generates minimal SVG with customizable colors.

2. **GanttChart**: Project timeline visualization showing task scheduling with start/end dates, category grouping, and optional task labels. Requires proper DateTime types for date handling, supports standard Config options for styling.

Both implementations follow existing AshReports patterns:
- Implement AshReports.Charts.Types.Behavior
- Use Contex library for SVG generation
- Register in Charts.Registry
- Support Config customization
- Work with all 4 renderers

**Estimated Effort**: 18-25 hours (2-3 days)
**Risk Level**: Medium (well-defined requirements, established patterns)
**Dependencies**: None (uses existing Contex v0.5.0)

**Next Steps**:
1. Create feature branch
2. Implement Sparkline (5-7 hours)
3. Implement GanttChart (7-9 hours)
4. Integration and testing (6-9 hours)
5. Code review and merge

This completes the planning phase. Implementation can proceed following the detailed step-by-step plan above.
