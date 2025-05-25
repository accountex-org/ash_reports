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
