# Ash Reports System Design Document

## Executive Summary

This document outlines the design for an extensible reporting system built as extensions to the Ash framework using Spark DSL. The system provides a declarative way to define complex reports with hierarchical band structures, supports multiple output formats (PDF, HTML, HEEX), includes internationalization via CLDR, and exposes reports through both an internal API server and an MCP server for LLM integration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│  MCP Server  │  Internal API  │  Report Designer Interface  │
├─────────────────────────────────────────────────────────────┤
│                    Ash Reports Domain                        │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │   Reports   │  │ Report Bands │  │ Report Variables│   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                  Ash Resource Extensions                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         Reportable Fields & Calculations            │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Rendering Engine                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │   PDF    │  │   HTML   │  │   HEEX   │  │  Custom  │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
├─────────────────────────────────────────────────────────────┤
│          CLDR Internationalization Layer                     │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Ash.Report Extension

The main extension that defines reports within an Ash.Domain:

```elixir
defmodule Ash.Report do
  @report_schema [
    name: [
      type: :atom,
      required: true,
      doc: "The name of the report"
    ],
    title: [
      type: :string,
      required: true,
      doc: "The display title of the report"
    ],
    description: [
      type: :string,
      doc: "A description of what this report contains"
    ],
    driving_resource: [
      type: :atom,
      required: true,
      doc: "The main Ash resource driving this report"
    ],
    scope: [
      type: :any,
      doc: "An Ash.Query to define the report scope"
    ],
    bands: [
      type: {:list, {:spark, Ash.Report.Band}},
      doc: "The hierarchical band structure"
    ],
    variables: [
      type: {:list, {:spark, Ash.Report.Variable}},
      doc: "Report variables for calculations"
    ],
    groups: [
      type: {:list, {:spark, Ash.Report.Group}},
      doc: "Grouping definitions"
    ],
    permissions: [
      type: {:list, :atom},
      doc: "Required permissions to run this report"
    ],
    parameters: [
      type: {:list, {:spark, Ash.Report.Parameter}},
      doc: "Runtime parameters for the report"
    ]
  ]

  use Spark.Dsl.Extension,
    sections: @sections,
    transformers: [
      Ash.Report.Transformers.ValidateBands,
      Ash.Report.Transformers.BuildQuery,
      Ash.Report.Transformers.ValidatePermissions
    ]
end
```

### 2. Report Band DSL

Hierarchical band structure implementation:

```elixir
defmodule Ash.Report.Band do
  @band_types [
    :title,
    :page_header,
    :column_header,
    :group_header,
    :detail_header,
    :detail,
    :detail_footer,
    :group_footer,
    :column_footer,
    :page_footer,
    :summary
  ]

  @band_schema [
    type: [
      type: {:in, @band_types},
      required: true
    ],
    group_level: [
      type: :integer,
      doc: "For group bands, specifies nesting level"
    ],
    detail_number: [
      type: :integer,
      doc: "For multiple detail bands"
    ],
    target_alias: [
      type: :any,
      doc: "Expression for related resource alias"
    ],
    on_entry: [
      type: :any,
      doc: "Ash expression to evaluate on band entry"
    ],
    on_exit: [
      type: :any,
      doc: "Ash expression to evaluate on band exit"
    ],
    elements: [
      type: {:list, {:spark, Ash.Report.Element}},
      doc: "Report elements in this band"
    ],
    options: [
      type: :keyword_list,
      doc: "Band-specific options"
    ]
  ]
end
```

### 3. Report Elements

Elements that can be placed within bands:

```elixir
defmodule Ash.Report.Element do
  @element_types [:field, :label, :expression, :aggregate, :line, :box, :image]

  @element_schema [
    type: [
      type: {:in, @element_types},
      required: true
    ],
    source: [
      type: :any,
      doc: "Field path or expression"
    ],
    format: [
      type: :any,
      doc: "CLDR format specification"
    ],
    position: [
      type: :keyword_list,
      doc: "Layout position (x, y, width, height)"
    ],
    style: [
      type: :keyword_list,
      doc: "Visual styling options"
    ],
    conditional: [
      type: :any,
      doc: "Ash expression for conditional display"
    ]
  ]
end
```

### 4. Ash.Resource.Reportable Extension

Extension for resources to expose reportable fields:

```elixir
defmodule Ash.Resource.Reportable do
  @reportable_schema [
    fields: [
      type: {:list, {:spark, Ash.Resource.Reportable.Field}},
      doc: "Fields exposed for reporting"
    ],
    calculations: [
      type: {:list, {:spark, Ash.Resource.Reportable.Calculation}},
      doc: "Calculated fields for reports"
    ],
    aggregates: [
      type: {:list, {:spark, Ash.Resource.Reportable.Aggregate}},
      doc: "Pre-defined aggregates for reports"
    ]
  ]

  use Spark.Dsl.Extension,
    sections: @sections,
    transformers: [
      Ash.Resource.Reportable.Transformers.ValidateFields
    ]
end
```

### 5. Report Variable System

Variables for calculations and state management:

```elixir
defmodule Ash.Report.Variable do
  @reset_types [:detail, :group, :page, :report]
  
  @variable_schema [
    name: [
      type: :atom,
      required: true
    ],
    type: [
      type: {:in, [:sum, :count, :average, :min, :max, :custom]},
      required: true
    ],
    expression: [
      type: :any,
      doc: "Ash expression for variable calculation"
    ],
    reset_on: [
      type: {:in, @reset_types},
      default: :report
    ],
    reset_group: [
      type: :integer,
      doc: "For group resets, which group level"
    ],
    reset_detail: [
      type: :integer,
      doc: "For detail resets, which detail band"
# Comprehensive Architecture for Ash.Domain Reports Extension

This software architecture enables declarative definition of complex hierarchical reports within Ash domains using Spark DSL. The design allows developers to define reports with nested band structures and export them in multiple formats.

## Extension architecture overview

The Reports extension integrates with Ash.Domain through two primary components:

1. **Domain extension** - Configures domain-wide report settings and registers report definitions
2. **Resource extension** - Adds reporting capabilities to individual resources

These extensions leverage Spark DSL to create a declarative interface for defining reports with a hierarchical band structure that mirrors traditional reporting systems.

```
AshReports
├── Domain (extension for Ash.Domain)
├── Resource (extension for Ash.Resource)
├── Dsl (core DSL definitions)
│   ├── Section definitions
│   └── Entity definitions  
├── Transformers (code generators)
│   ├── Report module generator
│   ├── Format-specific generators
│   └── Query generators
└── Renderers (format implementations)
    ├── HTML renderer
    ├── PDF renderer 
    └── HEEX renderer
```

## Spark DSL extension implementation

The core of the reports extension is built using Spark DSL. Here's the implementation of the extension's DSL structure:

```elixir
defmodule AshReports.Dsl do
  @moduledoc """
  DSL definitions for the AshReports extension.
  """

  # Report definition structs
  defmodule Report do
    @moduledoc "Represents a report definition"
    defstruct [:name, :title, :description, :resource, :bands, :formats, :options]
  end

  defmodule Band do
    @moduledoc "Represents a report band"
    defstruct [:type, :name, :title, :data_source, :query, :columns, :sub_bands, :options]
  end

  defmodule Column do
    @moduledoc "Represents a report column"
    defstruct [:name, :title, :field, :format, :aggregation, :width, :options]
  end

  # Column entity definition
  @column %Spark.Dsl.Entity{
    name: :column,
    args: [:name, :field],
    target: Column,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the column"
      ],
      field: [
        type: {:or, [:atom, :string]},
        required: true,
        doc: "The field to display in this column"
      ],
      title: [
        type: :string,
        doc: "The display title for the column"
      ],
      format: [
        type: {:or, [:atom, {:fun, 1}]},
        doc: "Format to apply to the column value"
      ],
      aggregation: [
        type: {:one_of, [:sum, :avg, :count, :min, :max, nil]},
        doc: "Aggregation to apply to the column"
      ],
      width: [
        type: :integer,
        doc: "Width of the column in pixels or units"
      ],
      align: [
        type: {:one_of, [:left, :center, :right]},
        default: :left,
        doc: "Alignment of the column content"
      ]
    ]
  }

  # Sub-band entity definition (recursive)
  @band %Spark.Dsl.Entity{
    name: :band,
    args: [:type, :name],
    target: Band,
    recursive_as: :sub_bands,
    schema: [
      type: [
        type: {:one_of, [:header, :detail, :footer, :group_header, :group_footer]},
        required: true,
        doc: "The type of band"
      ],
      name: [
        type: :atom,
        required: true,
        doc: "The name of the band"
      ],
      title: [
        type: :string,
        doc: "The title displayed in the band"
      ],
      data_source: [
        type: {:or, [:atom, :string]},
        doc: "The data source for this band"
      ],
      query: [
        type: :map,
        doc: "Query configuration for the band's data"
      ],
      options: [
        type: :keyword_list,
        doc: "Additional options for the band"
      ]
    ],
    entities: [@column],
    recursive_entities?: true
  }

  # Report entity definition
  @report %Spark.Dsl.Entity{
    name: :report,
    args: [:name],
    target: Report,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the report"
      ],
      title: [
        type: :string,
        doc: "The title of the report"
      ],
      description: [
        type: :string,
        doc: "Description of the report"
      ],
      resource: [
        type: :atom,
        doc: "The primary resource for this report"
      ],
      formats: [
        type: {:list, :atom},
        default: [:html, :pdf],
        doc: "Output formats supported by this report"
      ],
      options: [
        type: :keyword_list,
        doc: "Additional options for the report"
      ]
    ],
    entities: [@band]
  }

  # Reports section definition for domain extension
  @reports_section %Spark.Dsl.Section{
    name: :reports,
    describe: "Configure reports for this domain",
    schema: [
      default_formats: [
        type: {:list, :atom},
        default: [:html, :pdf],
        doc: "Default output formats for reports"
      ],
      storage_path: [
        type: :string,
        default: "reports",
        doc: "Path where generated reports are stored"
      ],
      cache_enabled: [
        type: :boolean,
        default: true,
        doc: "Whether to cache generated reports"
      ]
    ],
    entities: [@report]
  }

  # Reportable section definition for resource extension
  @reportable_section %Spark.Dsl.Section{
    name: :reportable,
    describe: "Configure reporting capabilities for this resource",
    schema: [
      enabled?: [
        type: :boolean,
        default: true,
        doc: "Whether this resource can be used in reports"
      ],
      title_field: [
        type: :atom,
        doc: "Field to use as title in reports"
      ],
      default_columns: [
        type: {:list, :atom},
        doc: "Default columns to include in reports"
      ],
      group_by_fields: [
        type: {:list, :atom},
        doc: "Fields that can be used for grouping"
      ]
    ],
    entities: [@report]
  }

  # Domain extension
  defmodule Domain do
    @moduledoc """
    Extension for Ash.Domain that adds reporting capabilities.
    """
    use Spark.Dsl.Extension,
      sections: [@reports_section],
      transformers: [
        AshReports.Transformers.RegisterReports,
        AshReports.Transformers.GenerateReportModules
      ]
  end

  # Resource extension
  defmodule Resource do
    @moduledoc """
    Extension for Ash.Resource that adds reporting capabilities.
    """
    use Spark.Dsl.Extension,
      sections: [@reportable_section],
      transformers: [
        AshReports.Transformers.AddReportActions,
        AshReports.Transformers.RegisterResourceReports
      ]
  end
end
```

## Hierarchical band structure implementation

The extension implements a recursive band structure that mirrors traditional reporting engines:

```elixir
defmodule AshReports.Dsl.BandProcessor do
  @moduledoc """
  Processes report bands recursively.
  """

  alias AshReports.Dsl.Band
  
  @doc """
  Processes a band and all its sub-bands recursively.
  """
  def process_band(%Band{} = band, data, context) do
    # Process this band
    {band_output, context} = render_band(band, data, context)
    
    # Process sub-bands if this is a detail or group band
    {sub_bands_output, context} = 
      case band.type do
        type when type in [:detail, :group_header] ->
          process_sub_bands(band.sub_bands, data, context)
        _ ->
          {"", context}
      end
    
    # Combine outputs
    {band_output <> sub_bands_output, context}
  end
  
  @doc """
  Processes all sub-bands of a band.
  """
  def process_sub_bands(sub_bands, data, context) when is_list(sub_bands) do
    Enum.reduce(sub_bands, {"", context}, fn band, {output, ctx} ->
      {band_output, new_ctx} = process_band(band, data, ctx)
      {output <> band_output, new_ctx}
    end)
  end
  def process_sub_bands(_, _, context), do: {"", context}
  
  # Private functions for rendering different band types
  defp render_band(%Band{type: :header} = band, data, context) do
    # Implementation for header band
  end
  
  defp render_band(%Band{type: :detail} = band, data, context) do
    # Implementation for detail band with data rows
  end
  
  defp render_band(%Band{type: :footer} = band, data, context) do
    # Implementation for footer band
  end
  
  defp render_band(%Band{type: :group_header} = band, data, context) do
    # Implementation for group header with group data
  end
  
  defp render_band(%Band{type: :group_footer} = band, data, context) do
    # Implementation for group footer with aggregations
  end
end
```

## Transformer implementation for code generation

The transformers are responsible for generating the code that implements report functionality:

```elixir
defmodule AshReports.Transformers.GenerateReportModules do
  @moduledoc """
  Generates runtime modules for reports defined in a domain.
  """
  use Spark.Dsl.Transformer
  
  alias Spark.Dsl.Transformer
  alias AshReports.Dsl.Report
  
  def transform(dsl_state) do
    # Extract all reports from the domain
    reports = AshReports.Domain.Info.reports(dsl_state)
    
    # Generate a module for each report
    Enum.reduce_while(reports, {:ok, dsl_state}, fn report, {:ok, state} ->
      case generate_report_module(report, state) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
  
  defp generate_report_module(%Report{} = report, dsl_state) do
    domain_module = Transformer.get_persisted(dsl_state, :module)
    report_module = Module.concat([domain_module, "Reports", Macro.camelize(to_string(report.name))])
    
    # Generate common report functionality
    code = generate_base_module(report_module, report, domain_module)
    
    # Generate format-specific modules
    format_modules = Enum.map(report.formats, fn format ->
      generate_format_module(report_module, report, format)
    end)
    
    # Combine all code
    all_code = [code | format_modules]
    
    # Evaluate the code in the context of the domain module
    {:ok, Transformer.eval(dsl_state, [], all_code)}
  end
  
  defp generate_base_module(module, report, domain_module) do
    quote do
      defmodule unquote(module) do
        @moduledoc """
        Report: #{unquote(report.title || to_string(report.name))}
        
        #{unquote(report.description || "")}
        """
        
        @report unquote(Macro.escape(report))
        @domain unquote(domain_module)
        
        def report, do: @report
        def domain, do: @domain
        
        @doc """
        Generate the report in the specified format.
        """
        def generate(params \\ %{}, format \\ nil)
        
        def generate(params, nil) do
          format = List.first(@report.formats)
          generate(params, format)
        end
        
        # Each format will have its own implementation
        # added by the format-specific modules
        
        @doc """
        Get the data for this report based on parameters.
        """
        def get_data(params \\ %{}) do
          # Implementation to fetch data based on report definition
          # and query parameters
        end
      end
    end
  end
  
  defp generate_format_module(base_module, report, format) do
    format_module = Module.concat(base_module, Macro.camelize(to_string(format)))
    
    case format do
      :html -> generate_html_module(format_module, base_module, report)
      :pdf -> generate_pdf_module(format_module, base_module, report)
      :heex -> generate_heex_module(format_module, base_module, report)
      _ -> raise "Unsupported format: #{format}"
    end
  end
  
  defp generate_html_module(module, base_module, report) do
    quote do
      defmodule unquote(module) do
        @moduledoc "HTML renderer for #{unquote(report.title || to_string(report.name))}"
        
        def generate(params \\ %{}) do
          data = unquote(base_module).get_data(params)
          render_html(data, params)
        end
        
        defp render_html(data, params) do
          # Implementation for HTML rendering
        end
      end
      
      # Add the HTML format implementation to the base module
      defimpl unquote(base_module), :generate, :html do
        def generate(params, :html) do
          unquote(module).generate(params)
        end
      end
    end
  end
  
  defp generate_pdf_module(module, base_module, report) do
    quote do
      defmodule unquote(module) do
        @moduledoc "PDF renderer for #{unquote(report.title || to_string(report.name))}"
        
        def generate(params \\ %{}) do
          # Either generate PDF directly or convert from HTML
          html = unquote(Module.concat(base_module, "Html")).generate(params)
          convert_to_pdf(html, params)
        end
        
        defp convert_to_pdf(html, params) do
          # Implementation using ChromicPDF or other PDF library
          ChromicPDF.print_to_pdf({:html, html}, output: output_path(params))
        end
        
        defp output_path(params) do
          # Generate output path based on report and params
        end
      end
      
      # Add the PDF format implementation to the base module
      defimpl unquote(base_module), :generate, :pdf do
        def generate(params, :pdf) do
          unquote(module).generate(params)
        end
      end
    end
  end
  
  defp generate_heex_module(module, base_module, report) do
    quote do
      defmodule unquote(module) do
        @moduledoc "HEEX renderer for #{unquote(report.title || to_string(report.name))}"
        
        def generate(params \\ %{}) do
          data = unquote(base_module).get_data(params)
          render_heex(data, params)
        end
        
        defp render_heex(data, params) do
          # Implementation for HEEX rendering
        end
      end
      
      # Add the HEEX format implementation to the base module
      defimpl unquote(base_module), :generate, :heex do
        def generate(params, :heex) do
          unquote(module).generate(params)
        end
      end
    end
  end
end
```

## Data binding and query generation

The extension generates queries based on report definitions and binds data to templates:

```elixir
defmodule AshReports.QueryGenerator do
  @moduledoc """
  Generates Ash queries based on report definitions.
  """

  @doc """
  Builds a query for a report based on parameters.
  """
  def build_query(report, params) do
    resource = report.resource
    
    # Start with base query
    query = Ash.Query.new(resource)
    
    # Add filters from params
    query = apply_filters(query, params)
    
    # Add sort order
    query = apply_sorting(query, params)
    
    # Load relationships
    query = load_relationships(query, report)
    
    # Load aggregates
    query = load_aggregates(query, report)
    
    # Apply pagination if needed
    apply_pagination(query, params)
  end
  
  @doc """
  Builds a query for a specific band based on parameters.
  """
  def build_band_query(band, parent_data, params) do
    case band.data_source do
      nil -> 
        # Use parent data if no specific data source
        parent_data
      
      data_source when is_atom(data_source) ->
        # Look up the data source in the parent data
        Map.get(parent_data, data_source)
      
      relationship when is_binary(relationship) ->
        # Follow a relationship path
        get_in(parent_data, String.split(relationship, "."))
    end
    |> apply_band_filters(band, params)
  end
  
  # Private implementation details...
  
  defp apply_filters(query, params) do
    # Implementation for applying filters from params
  end
  
  defp apply_sorting(query, params) do
    # Implementation for applying sorting
  end
  
  defp load_relationships(query, report) do
    # Implementation for loading relationships
  end
  
  defp load_aggregates(query, report) do
    # Implementation for loading aggregates
  end
  
  defp apply_pagination(query, params) do
    # Implementation for pagination
  end
  
  defp apply_band_filters(data, band, params) do
    # Implementation for filtering band data
  end
end
```

## Integration with Ash.Domain

The extension integrates with Ash.Domain through the domain extension and adds actions to resources:

```elixir
defmodule AshReports.Transformers.AddReportActions do
  @moduledoc """
  Adds report-related actions to resources.
  """
  use Spark.Dsl.Transformer
  
  alias Spark.Dsl.Transformer
  
  def transform(dsl_state) do
    # Check if reporting is enabled for this resource
    enabled? = AshReports.Resource.Info.reportable_enabled?(dsl_state)
    
    if enabled? do
      # Add actions for generating reports
      add_report_actions(dsl_state)
    else
      {:ok, dsl_state}
    end
  end
  
  defp add_report_actions(dsl_state) do
    # Get all reports for this resource
    reports = AshReports.Resource.Info.reports(dsl_state)
    
    # Add a generate_report action for each report
    Enum.reduce_while(reports, {:ok, dsl_state}, fn report, {:ok, state} ->
      case add_report_action(state, report) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
  
  defp add_report_action(dsl_state, report) do
    action_name = :"generate_#{report.name}_report"
    
    # Build an action entity for generating this report
    {:ok, action} = Transformer.build_entity(
      Ash.Resource.Dsl,
      [:actions],
      :read,
      name: action_name,
      arguments: [
        %{name: :format, type: :atom, allow_nil?: true},
        %{name: :params, type: :map, default: %{}}
      ],
      controller?: true
    )
    
    # Add the action to the resource
    {:ok, new_state} = Transformer.add_entity(dsl_state, [:actions], action)
    
    # Generate the implementation
    code = quote do
      def unquote(action_name)(format \\ nil, params \\ %{}) do
        report_module = unquote(report.module)
        report_module.generate(params, format)
      end
    end
    
    # Add the implementation to the resource
    {:ok, Transformer.eval(new_state, [], code)}
  end
end
```

## Example usage

Here's how a developer would use this extension to define reports in an Ash.Domain:

```elixir
defmodule MyApp.Sales do
  use Ash.Domain,
    extensions: [AshReports.Domain]
  
  # Configure reports for this domain
  reports do
    # Domain-wide report configuration
    default_formats [:html, :pdf, :csv]
    storage_path "sales_reports"
    
    # Define a sales report
    report :monthly_sales do
      title "Monthly Sales Report"
      description "Shows sales aggregated by month and product category"
      resource MyApp.Sales.Order
      formats [:html, :pdf, :xlsx]
      
      # Define the report structure with bands
      band :header, :report_header do
        title "MONTHLY SALES REPORT"
        
        # Add columns to the header
        column :report_date, "Generated on"
        column :period, "Reporting Period"
      end
      
      band :detail, :monthly_data do
        title "Monthly Data"
        data_source :sales_by_month
        
        # Add columns to show in the detail band
        column :month, :month
        column :total_sales, :sales, format: :currency
        column :growth, :growth_rate, format: :percentage
        
        # Sub-band for product categories within each month
        band :detail, :product_categories do
          data_source "sales_by_category"
          
          column :category, :name
          column :sales, :amount, format: :currency
          column :percentage, :percentage, format: :percentage
        end
      end
      
      band :footer, :report_footer do
        column :total_label, "Total Sales"
        column :grand_total, :total_sales, format: :currency
      end
    end
  end
  
  resources do
    resource MyApp.Sales.Order
    resource MyApp.Sales.Product
    resource MyApp.Sales.Customer
  end
end

defmodule MyApp.Sales.Order do
  use Ash.Resource,
    domain: MyApp.Sales,
    extensions: [AshReports.Resource]
  
  attributes do
    uuid_primary_key :id
    attribute :order_date, :date
    attribute :total, :decimal
    attribute :status, :atom, constraints: [one_of: [:pending, :completed, :cancelled]]
  end
  
  relationships do
    belongs_to :customer, MyApp.Sales.Customer
    has_many :line_items, MyApp.Sales.LineItem
  end
  
  # Configure reporting capabilities
  reportable do
    enabled? true
    title_field :id
    default_columns [:id, :order_date, :total, :status]
    group_by_fields [:order_date, :status, :customer_id]
    
    # Resource-specific report
    report :orders_by_customer do
      title "Orders by Customer"
      description "Shows all orders grouped by customer"
      
      band :header, :report_header do
        title "ORDERS BY CUSTOMER"
      end
      
      band :detail, :customers do
        data_source :customers
        
        column :name, :name
        column :email, :email
        
        band :detail, :customer_orders do
          data_source "line_items"
          
          column :order_id, :id
          column :date, :order_date
          column :total, :total, format: :currency
          column :status, :status
        end
      end
      
      band :footer, :report_footer do
        column :total_orders, :order_count
        column :total_value, :total_value, format: :currency
      end
    end
  end
end
```

## Format-specific renderer implementation

Here's the implementation for the HTML renderer:

```elixir
defmodule AshReports.Renderers.Html do
  @moduledoc """
  Renders reports as HTML.
  """
  
  alias AshReports.Dsl.{Report, Band, Column}
  
  @doc """
  Renders a report as HTML based on data and params.
  """
  def render(report, data, params \\ %{}) do
    """
    <!DOCTYPE html>
    <html>
      <head>
        <title>#{report.title}</title>
        <style>
          #{default_styles()}
          #{custom_styles(report)}
        </style>
      </head>
      <body>
        <div class="report">
          #{render_title(report)}
          #{render_bands(report.bands, data, params)}
        </div>
      </body>
    </html>
    """
  end
  
  # Private implementation details...
  
  defp render_title(report) do
    """
    <div class="report-title">
      <h1>#{report.title}</h1>
      #{if report.description, do: "<p>#{report.description}</p>", else: ""}
    </div>
    """
  end
  
  defp render_bands(bands, data, params) do
    bands
    |> Enum.map(fn band -> render_band(band, data, params) end)
    |> Enum.join("\n")
  end
  
  defp render_band(%Band{type: :header} = band, data, params) do
    """
    <div class="band header-band #{band.name}">
      #{if band.title, do: "<h2>#{band.title}</h2>", else: ""}
      <table>
        #{render_columns(band.columns, data, params)}
      </table>
    </div>
    """
  end
  
  defp render_band(%Band{type: :detail} = band, data, params) do
    band_data = get_band_data(band, data, params)
    
    """
    <div class="band detail-band #{band.name}">
      #{if band.title, do: "<h3>#{band.title}</h3>", else: ""}
      <table>
        <thead>
          <tr>
            #{render_column_headers(band.columns)}
          </tr>
        </thead>
        <tbody>
          #{render_detail_rows(band, band_data, params)}
        </tbody>
      </table>
      #{render_sub_bands(band.sub_bands, band_data, params)}
    </div>
    """
  end
  
  defp render_band(%Band{type: :footer} = band, data, params) do
    """
    <div class="band footer-band #{band.name}">
      <table>
        #{render_columns(band.columns, data, params)}
      </table>
    </div>
    """
  end
  
  defp render_column_headers(columns) do
    columns
    |> Enum.map(fn col -> "<th>#{col.title || col.name}</th>" end)
    |> Enum.join("\n")
  end
  
  defp render_detail_rows(band, data, params) when is_list(data) do
    data
    |> Enum.map(fn row -> render_detail_row(band, row, params) end)
    |> Enum.join("\n")
  end
  
  defp render_detail_row(band, row, params) do
    """
    <tr>
      #{
        band.columns
        |> Enum.map(fn col -> render_cell(col, row, params) end)
        |> Enum.join("\n")
      }
    </tr>
    """
  end
  
  defp render_cell(column, data, params) do
    value = get_column_value(column, data)
    formatted_value = format_value(value, column.format)
    
    """
    <td class="#{column.name}" style="text-align: #{column.align || "left"}">
      #{formatted_value}
    </td>
    """
  end
  
  defp render_sub_bands(sub_bands, data, params) when is_list(sub_bands) do
    sub_bands
    |> Enum.map(fn band -> render_band(band, data, params) end)
    |> Enum.join("\n")
  end
  defp render_sub_bands(_, _, _), do: ""
  
  defp get_band_data(band, data, params) do
    # Implementation to get data for a specific band
  end
  
  defp get_column_value(column, data) do
    # Get raw value from data
  end
  
  defp format_value(value, format) do
    # Format the value based on the specified format
    case format do
      :currency -> "$#{:erlang.float_to_binary(value, decimals: 2)}"
      :percentage -> "#{:erlang.float_to_binary(value * 100, decimals: 1)}%"
      :date -> Calendar.strftime(value, "%Y-%m-%d")
      :datetime -> Calendar.strftime(value, "%Y-%m-%d %H:%M:%S")
      format when is_function(format, 1) -> format.(value)
      _ -> to_string(value)
    end
  end
  
  defp default_styles do
    """
    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
    .report { max-width: 1200px; margin: 0 auto; }
    .report-title h1 { color: #333; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    th { background: #f2f2f2; padding: 8px; text-align: left; border: 1px solid #ddd; }
    td { padding: 8px; border: 1px solid #ddd; }
    .header-band { margin-bottom: 20px; }
    .footer-band { margin-top: 20px; border-top: 2px solid #333; padding-top: 10px; }
    """
  end
  
  defp custom_styles(report) do
    # Extract custom styles from report options
    report.options[:styles] || ""
  end
end
```

## Recursive band structure handling

The key to implementing the recursive band structure is the recursive entity in Spark DSL:

```elixir
@band %Spark.Dsl.Entity{
  name: :band,
  args: [:type, :name],
  target: Band,
  recursive_as: :sub_bands,  # This is the key for recursion
  schema: [
    # Schema definition...
  ],
  entities: [@column],
  recursive_entities?: true  # This allows entities in recursive instances
}
```

This allows for defining nested bands like:

```elixir
band :detail, :customers do
  # Customer band configuration
  
  band :detail, :orders do
    # Orders band (sub-band of customers)
    
    band :detail, :line_items do
      # Line items band (sub-band of orders)
    end
  end
end
```

The renderer processes these nested structures recursively, building a hierarchical report.

## Conclusion

This comprehensive architecture provides a declarative way to define complex reports within Ash domains. The design leverages Spark DSL's capabilities for creating extensible, hierarchical DSLs and integrates seamlessly with the Ash Framework.

Key features of this architecture include:

1. **Declarative report definition** - Define reports with a clean, hierarchical DSL
2. **Recursive band structure** - Support for nested bands with arbitrary depth
3. **Multiple output formats** - Generate reports in HTML, PDF, and HEEX formats
4. **Integration with Ash queries** - Leverage Ash's powerful query capabilities
5. **Code generation** - Automatically generate modules for report rendering
6. **Domain-level configuration** - Configure reporting at both domain and resource levels

By following the patterns established in the Ash ecosystem, this extension maintains consistency with other Ash components while providing powerful reporting capabilities.
    ],
    initial_value: [
      type: :any,
      default: 0
    ]
  ]
end
```

## Domain Definition Example

```elixir
defmodule MyApp.Reports do
  use Ash.Domain,
    extensions: [Ash.Report]

  reports do
    report :sales_summary do
      title "Sales Summary Report"
      description "Monthly sales by region with totals"
      driving_resource MyApp.Sales.Order
      
      parameters do
        parameter :start_date, :date, required: true
        parameter :end_date, :date, required: true
        parameter :region, :string
      end

      scope fn params ->
        MyApp.Sales.Order
        |> Ash.Query.filter(order_date >= ^params.start_date)
        |> Ash.Query.filter(order_date <= ^params.end_date)
        |> Ash.Query.filter(if params.region, do: region == ^params.region, else: true)
        |> Ash.Query.load([:customer, :line_items])
      end

      groups do
        group :region, expr(region), level: 1
        group :month, expr(fragment("date_trunc('month', ?)", order_date)), level: 2
      end

      variables do
        variable :region_total, :sum, 
          expression: expr(total_amount),
          reset_on: :group,
          reset_group: 1

        variable :month_total, :sum,
          expression: expr(total_amount),
          reset_on: :group,
          reset_group: 2

        variable :grand_total, :sum,
          expression: expr(total_amount),
          reset_on: :report
      end

      bands do
        band :title do
          elements do
            label "Sales Summary Report",
              position: [x: :center, y: 10],
              style: [font_size: 24, font_weight: :bold]
            
            expression expr("Report Period: #{format_date(^params.start_date)} to #{format_date(^params.end_date)}"),
              position: [x: :center, y: 40]
          end
        end

        band :page_header do
          elements do
            label "Order Date", position: [x: 50, y: 10, width: 100]
            label "Customer", position: [x: 150, y: 10, width: 200]
            label "Amount", position: [x: 350, y: 10, width: 100]
            line position: [x: 50, y: 25, width: 400, height: 1]
          end
        end

        band :group_header, group_level: 1 do
          on_entry expr(reset_variable(:region_total))
          
          elements do
            label "Region:", position: [x: 50, y: 5]
            field :region, position: [x: 100, y: 5],
              style: [font_weight: :bold]
          end
        end

        band :group_header, group_level: 2 do
          on_entry expr(reset_variable(:month_total))
          
          elements do
            label "Month:", position: [x: 70, y: 5]
            expression expr(format_date(^current.month, format: :month_year)),
              position: [x: 120, y: 5]
          end
        end

        band :detail do
          elements do
            field :order_date, 
              position: [x: 50, y: 5, width: 100],
              format: [date: :short]
            
            field [:customer, :name],
              position: [x: 150, y: 5, width: 200]
            
            field :total_amount,
              position: [x: 350, y: 5, width: 100],
              format: [currency: :USD]
          end
        end

        band :group_footer, group_level: 2 do
          elements do
            label "Month Total:",
              position: [x: 250, y: 5],
              style: [font_weight: :bold]
            
            variable :month_total,
              position: [x: 350, y: 5, width: 100],
              format: [currency: :USD],
              style: [font_weight: :bold]
          end
        end

        band :group_footer, group_level: 1 do
          elements do
            label "Region Total:",
              position: [x: 250, y: 5],
              style: [font_weight: :bold, font_size: 12]
            
            variable :region_total,
              position: [x: 350, y: 5, width: 100],
              format: [currency: :USD],
              style: [font_weight: :bold, font_size: 12]
            
            line position: [x: 50, y: 15, width: 400, height: 2]
          end
        end

        band :summary do
          elements do
            label "Grand Total:",
              position: [x: 250, y: 10],
              style: [font_weight: :bold, font_size: 14]
            
            variable :grand_total,
              position: [x: 350, y: 10, width: 100],
              format: [currency: :USD],
              style: [font_weight: :bold, font_size: 14]
          end
        end
      end

      permissions [:view_sales_reports, :view_financial_data]
    end
  end
end
```

## Rendering Engine

Abstract rendering interface with pluggable backends:

```elixir
defmodule Ash.Report.Renderer do
  @callback render(report :: Ash.Report.t(), data :: term(), opts :: keyword()) ::
              {:ok, binary()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Ash.Report.Renderer
      
      def render(report, data, opts) do
        locale = Keyword.get(opts, :locale, "en")
        Cldr.with_locale(locale, fn ->
          do_render(report, data, opts)
        end)
      end
      
      defoverridable render: 3
    end
  end
end
```

### PDF Renderer Example

```elixir
defmodule Ash.Report.Renderer.PDF do
  use Ash.Report.Renderer
  
  def do_render(report, data, opts) do
    # Use a library like ChromicPDF or wkhtmltopdf
    html = Ash.Report.Renderer.HTML.render!(report, data, opts)
    
    ChromicPDF.print_to_pdf(html,
      print_to_pdf: %{
        format: :A4,
        landscape: Keyword.get(opts, :landscape, false)
      }
    )
  end
end
```

### HEEX Renderer

```elixir
defmodule Ash.Report.Renderer.HEEX do
  use Ash.Report.Renderer
  use Phoenix.Component
  
  def do_render(report, data, opts) do
    assigns = %{
      report: report,
      data: data,
      opts: opts,
      bands: process_bands(report, data)
    }
    
    ~H"""
    <div class="ash-report" data-report={@report.name}>
      <.render_band :for={band <- @bands} band={band} />
    </div>
    """
  end
  
  defp render_band(assigns) do
    ~H"""
    <div class={"ash-report-band ash-report-band-#{@band.type}"}>
      <.render_element :for={element <- @band.elements} element={element} />
    </div>
    """
  end
  
  defp render_element(assigns) do
    case assigns.element.type do
      :field -> render_field(assigns)
      :label -> render_label(assigns)
      :expression -> render_expression(assigns)
      # ... other element types
    end
  end
end
```

## Internal Report Server

GenServer for managing report execution:

```elixir
defmodule Ash.Report.Server do
  use GenServer
  
  defmodule State do
    defstruct [:reports_domain, :cache, :active_jobs]
  end
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def run_report(report_name, params, opts \\ []) do
    GenServer.call(__MODULE__, {:run_report, report_name, params, opts})
  end
  
  def run_report_async(report_name, params, opts \\ []) do
    GenServer.cast(__MODULE__, {:run_report_async, report_name, params, opts})
  end
  
  def get_report_status(job_id) do
    GenServer.call(__MODULE__, {:get_status, job_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(opts) do
    state = %State{
      reports_domain: Keyword.fetch!(opts, :reports_domain),
      cache: :ets.new(:report_cache, [:set, :public]),
      active_jobs: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:run_report, name, params, opts}, _from, state) do
    case execute_report(state.reports_domain, name, params, opts) do
      {:ok, result} ->
        cache_result(state.cache, name, params, result)
        {:reply, {:ok, result}, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_cast({:run_report_async, name, params, opts}, state) do
    job_id = generate_job_id()
    
    task = Task.async(fn ->
      execute_report(state.reports_domain, name, params, opts)
    end)
    
    new_state = put_in(state.active_jobs[job_id], task)
    {:noreply, new_state}
  end
  
  defp execute_report(domain, name, params, opts) do
    with {:ok, report} <- get_report(domain, name),
         :ok <- validate_permissions(report, opts[:user]),
         {:ok, data} <- fetch_report_data(report, params),
         {:ok, rendered} <- render_report(report, data, opts) do
      {:ok, %{
        report: name,
        params: params,
        generated_at: DateTime.utc_now(),
        format: Keyword.get(opts, :format, :pdf),
        content: rendered
      }}
    end
  end
end
```

## MCP Server Integration

Model Context Protocol server for LLM access:

```elixir
defmodule Ash.Report.MCPServer do
  use GenServer
  
  @protocol_version "1.0.0"
  
  defmodule Tool do
    defstruct [:name, :description, :parameters, :permissions]
  end
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  # MCP Protocol Implementation
  
  def handle_info({:tcp, socket, data}, state) do
    case Jason.decode(data) do
      {:ok, %{"method" => method, "params" => params, "id" => id}} ->
        response = handle_mcp_request(method, params, state)
        :gen_tcp.send(socket, Jason.encode!(%{
          jsonrpc: "2.0",
          id: id,
          result: response
        }))
        
      {:error, _} ->
        # Invalid JSON
    end
    
    {:noreply, state}
  end
  
  defp handle_mcp_request("initialize", _params, state) do
    %{
      protocolVersion: @protocol_version,
      capabilities: %{
        tools: true,
        resources: false
      }
    }
  end
  
  defp handle_mcp_request("tools/list", _params, state) do
    tools = build_tools_list(state.reports_domain, state.allowed_reports)
    
    %{
      tools: Enum.map(tools, fn tool ->
        %{
          name: "report_#{tool.name}",
          description: tool.description,
          inputSchema: build_json_schema(tool.parameters)
        }
      end)
    }
  end
  
  defp handle_mcp_request("tools/call", %{"name" => tool_name, "arguments" => args}, state) do
    case String.trim_leading(tool_name, "report_") do
      "" -> {:error, "Invalid tool name"}
      
      report_name ->
        report_name = String.to_existing_atom(report_name)
        
        case validate_mcp_access(report_name, state) do
          :ok ->
            run_report_for_mcp(report_name, args, state)
            
          {:error, reason} ->
            %{error: reason}
        end
    end
  end
  
  defp build_json_schema(parameters) do
    %{
      type: "object",
      properties: Enum.reduce(parameters, %{}, fn param, acc ->
        Map.put(acc, param.name, %{
          type: parameter_type_to_json_type(param.type),
          description: param.description,
          required: param.required
        })
      end)
    }
  end
  
  defp run_report_for_mcp(report_name, params, state) do
    case Ash.Report.Server.run_report(report_name, params, format: :json) do
      {:ok, result} ->
        %{
          content: [
            %{
              type: "text",
              text: format_report_for_llm(result)
            }
          ]
        }
        
      {:error, reason} ->
        %{
          content: [
            %{
              type: "text", 
              text: "Error running report: #{inspect(reason)}"
            }
          ]
        }
    end
  end
end
```

## Internationalization with CLDR

Integration with ex_cldr for formatting:

```elixir
defmodule Ash.Report.Formatter do
  def format_value(value, format_spec, locale \\ "en") do
    Cldr.with_locale(locale, fn ->
      case format_spec do
        [date: format] -> 
          MyApp.Cldr.DateTime.to_string!(value, format: format)
          
        [currency: currency] ->
          MyApp.Cldr.Number.to_string!(value, currency: currency)
          
        [number: opts] ->
          MyApp.Cldr.Number.to_string!(value, opts)
          
        [unit: {unit, opts}] ->
          MyApp.Cldr.Unit.to_string!(value, unit: unit)
          
        _ ->
          to_string(value)
      end
    end)
  end
end
```

## Security Considerations

### Permission System

```elixir
defmodule Ash.Report.Authorization do
  def authorize_report(report, user, context \\ %{}) do
    required_permissions = report.permissions || []
    user_permissions = get_user_permissions(user)
    
    if MapSet.subset?(
      MapSet.new(required_permissions),
      MapSet.new(user_permissions)
    ) do
      :ok
    else
      {:error, :unauthorized}
    end
  end
  
  def filter_allowed_reports(reports, user) do
    Enum.filter(reports, fn report ->
      match?(:ok, authorize_report(report, user))
    end)
  end
end
```

### Data Access Control

Reports respect Ash policies and filters:

```elixir
defmodule Ash.Report.Transformers.ApplyPolicies do
  use Spark.Dsl.Transformer
  
  def transform(dsl_state) do
    {:ok, 
     dsl_state
     |> update_report_queries(&apply_policies/1)}
  end
  
  defp apply_policies(query) do
    query
    |> Ash.Query.for_read(:report_read, actor: current_actor())
    |> apply_report_specific_filters()
  end
end
```

## Configuration

### Application Configuration

```elixir
# config/config.exs
config :my_app, :ash_reports,
  report_server: [
    reports_domain: MyApp.Reports,
    cache_ttl: :timer.minutes(15),
    max_concurrent_reports: 10
  ],
  mcp_server: [
    port: 5173,
    allowed_reports: [:sales_summary, :inventory_status],
    require_authentication: true
  ],
  renderers: [
    pdf: Ash.Report.Renderer.PDF,
    html: Ash.Report.Renderer.HTML,
    heex: Ash.Report.Renderer.HEEX,
    json: Ash.Report.Renderer.JSON
  ]
```

### Supervision Tree

```elixir
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # ... other children
      {Ash.Report.Server, Application.get_env(:my_app, :ash_reports)[:report_server]},
      {Ash.Report.MCPServer, Application.get_env(:my_app, :ash_reports)[:mcp_server]},
      {Ash.Report.Cache, []}
    ]
    
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Testing Strategy

### Report Definition Testing

```elixir
defmodule MyApp.ReportTest do
  use ExUnit.Case
  
  describe "sales_summary report" do
    test "validates required parameters" do
      assert {:error, _} = 
        MyApp.Reports.run_report(:sales_summary, %{})
    end
    
    test "generates correct bands" do
      report = MyApp.Reports.get_report!(:sales_summary)
      band_types = Enum.map(report.bands, & &1.type)
      
      assert :title in band_types
      assert :page_header in band_types
      assert :detail in band_types
      assert :summary in band_types
    end
    
    test "calculates variables correctly" do
      data = create_test_data()
      result = MyApp.Reports.run_report(:sales_summary, %{
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-12-31]
      })
      
      assert result.variables.grand_total == calculate_expected_total(data)
    end
  end
end
```

### Renderer Testing

```elixir
defmodule Ash.Report.Renderer.PDFTest do
  use ExUnit.Case
  
  test "renders PDF with correct formatting" do
    report = build_test_report()
    data = build_test_data()
    
    {:ok, pdf_binary} = Ash.Report.Renderer.PDF.render(report, data, [])
    
    assert is_binary(pdf_binary)
    assert String.starts_with?(pdf_binary, "%PDF")
  end
end
```

## Performance Considerations

### Query Optimization

- Use Ash.Query.load/2 to preload associations
- Implement query result caching for repeated report runs
- Use database-level aggregations where possible

### Streaming for Large Reports

```elixir
defmodule Ash.Report.Stream do
  def stream_report(report, params, chunk_size \\ 1000) do
    Stream.resource(
      fn -> init_report_state(report, params) end,
      fn state -> fetch_next_chunk(state, chunk_size) end,
      fn state -> cleanup_report_state(state) end
    )
  end
end
```

### Concurrent Report Generation

- Use Task.async_stream for parallel processing of independent report sections
- Implement connection pooling for database access
- Rate limiting for MCP server requests

## Future Extensions

### 1. Report Designer UI
- Visual band layout designer
- Drag-and-drop element positioning
- Live preview with sample data

### 2. Advanced Features
- Sub-reports within detail bands
- Cross-tab/pivot reports
- Chart integration (using VegaLite)
- Conditional formatting rules

### 3. Export/Import
- Report definition serialization
- Version control integration
- Report templates marketplace

### 4. Analytics Integration
- Report usage tracking
- Performance metrics
- User behavior analytics

## Conclusion

This design provides a comprehensive, extensible reporting system built on Ash framework principles. The hierarchical band structure matches traditional report writers while leveraging Elixir's strengths and Ash's powerful query and authorization systems. The system is internationalized, supports multiple output formats, and can be accessed both programmatically and through LLM integration via MCP.
