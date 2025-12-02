defmodule AshReports.Typst.DSLGenerator do
  @moduledoc """
  Converts AshReports Spark DSL definitions into Typst templates.

  This module provides the core functionality to transform declarative AshReports
  definitions into functional Typst templates that maintain Crystal Reports-style
  band hierarchies and element positioning.

  ## Architecture

  The generator follows a recursive approach:
  1. Extract report structure from DSL
  2. Generate Typst function signature with data parameters
  3. Process bands hierarchically (title → headers → detail → footers)
  4. Convert elements within bands to Typst constructs
  5. Apply conditional rendering and grouping logic

  ## Supported Features

  - **Band Types**: All 11 AshReports band types
  - **Element Types**: All 7 element types (field, label, expression, aggregate, line, box, image)
  - **Conditional Rendering**: Expression-based conditional display
  - **Grouping**: Multi-level group headers and footers
  - **Variables**: Report-level variables and aggregates
  - **Styling**: Position, dimensions, and basic styling

  ## Example

      report = AshReports.Info.report(MyDomain, :sales_report)
      {:ok, template} = DSLGenerator.generate_template(report)

      # Generated Typst template:
      # #let sales_report(data, config) = {
      #   // Title band
      #   = Sales Report
      #
      #   // Detail processing
      #   #for item in data.records {
      #     [Customer: #item.customer_name]
      #   }
      # }

  """

  require Logger

  alias AshReports.{Band, Report}

  @doc """
  Generates a Typst template from an AshReports report definition.

  ## Parameters

    * `report` - The AshReports.Report struct containing the full report definition
    * `options` - Generation options:
      * `:format` - Target format (:pdf, :png, :svg), defaults to :pdf
      * `:theme` - Theme name for styling, defaults to "default"
      * `:debug` - Include debug comments in template, defaults to false

  ## Returns

    * `{:ok, template_string}` - Successfully generated Typst template
    * `{:error, reason}` - Generation failure with detailed error

  ## Examples

      iex> report = %Report{name: :simple_report, bands: [%Band{type: :title}]}
      iex> DSLGenerator.generate_template(report)
      {:ok, "#let simple_report(data, config) = {\\n  // Title band\\n  = Simple Report\\n}"}

  """
  @spec generate_template(Report.t() | nil, Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def generate_template(report, options \\ [])
  def generate_template(nil, _options), do: {:error, {:generation_failed, :invalid_report}}

  def generate_template(%Report{} = report, options) do
    context = build_generation_context(report, options)

    # Serialize data from context if available
    data_string = serialize_context_data(context)

    template =
      """
      // Generated Typst template for report: #{report.name}
      // Generated at: #{DateTime.utc_now() |> DateTime.to_iso8601()}
      #{if context.debug, do: generate_debug_info(report), else: ""}

      #let #{report.name}(data, config: (:)) = {
        #{generate_page_setup(report, context)}

        #{generate_report_content(report, context)}
      }

      // Call the function to render the report with data
      #{data_string}
      ##{report.name}(report_data, config: ())
      """
      |> String.trim()

    {:ok, template}
  rescue
    error ->
      Logger.debug(fn ->
        "Template generation failed for report #{report.name}: #{inspect(error)}"
      end)

      Logger.error("Template generation failed for report #{report.name}")
      {:error, {:generation_failed, error}}
  end

  @doc """
  Generates a Typst template section for a specific band.

  This function handles individual band processing and can be used
  for testing or partial template generation.
  """
  @spec generate_band_section(Band.t(), map()) :: String.t()
  def generate_band_section(%Band{} = band, context) do
    band_comment = if context.debug, do: "  // #{band.type} band: #{band.name}\n", else: ""

    """
    #{band_comment}#{generate_band_content(band, context)}
    """
    |> String.trim()
  end

  @doc """
  Generates Typst code for a specific element.

  Converts individual AshReports elements to their Typst equivalents
  with proper positioning and styling.
  """
  @spec generate_element(struct(), map()) :: String.t()
  def generate_element(element, context) do
    element_type = element.__struct__ |> Module.split() |> List.last()

    case element_type do
      "Field" ->
        generate_field_element(element, context)

      "Label" ->
        generate_label_element(element, context)

      "Expression" ->
        generate_expression_element(element, context)

      "Aggregate" ->
        generate_aggregate_element(element, context)

      "Line" ->
        generate_line_element(element, context)

      "Box" ->
        generate_box_element(element, context)

      "Image" ->
        generate_image_element(element, context)

      "Chart" ->
        generate_chart_element(element, context)

      _ ->
        Logger.warning("Unknown element type: #{element_type}")
        "// Unknown element: #{element_type}"
    end
  end

  # Private Functions - Context and Setup

  defp build_generation_context(report, options) do
    base_context = %{
      report: report,
      format: Keyword.get(options, :format, :pdf),
      theme: Keyword.get(options, :theme, "default"),
      debug: Keyword.get(options, :debug, false),
      variables: extract_report_variables(report),
      groups: extract_report_groups(report)
    }

    # Add RenderContext if provided
    case Keyword.get(options, :context) do
      nil -> base_context
      render_context -> Map.put(base_context, :context, render_context)
    end
  end

  defp generate_debug_info(report) do
    driving_resource_name =
      case report.driving_resource do
        nil ->
          "None"

        module when is_atom(module) ->
          module
          |> Module.split()
          |> List.last()

        other ->
          inspect(other)
      end

    """
    // Report Debug Information
    // Name: #{report.name}
    // Title: #{report.title || "Untitled"}
    // Driving Resource: #{driving_resource_name}
    // Bands: #{length(report.bands || [])}
    // Parameters: #{length(report.parameters || [])}
    """
  end

  defp generate_page_setup(report, context) do
    """
    // Page configuration
    set page(
      paper: "#{get_paper_size(context.format)}",
      margin: (x: 2cm, y: 2cm),
      #{generate_page_headers_footers(report, context)}
    )

    // Document properties
    set document(
      title: "#{report.title || report.name}",
      author: "AshReports"
    )

    // Text formatting
    set text(
      font: "Liberation Serif",
      size: 11pt
    )
    """
  end

  defp generate_page_headers_footers(report, context) do
    page_header = find_band_by_type(report.bands, :page_header)
    page_footer = find_band_by_type(report.bands, :page_footer)

    # Page headers/footers are placed inside content blocks [], so band content
    # needs # prefix for function calls (content mode vs code mode)
    content_mode_context = Map.put(context, :content_mode, true)

    header_content =
      if page_header do
        header_band_content = generate_band_content(page_header, content_mode_context)

        # Check if header should repeat on all pages (default: true)
        if Map.get(page_header, :repeat_on_pages, true) do
          "header: [#{header_band_content}],"
        else
          # Only show on first page using context
          "header: context [#if counter(page).get().first() == 1 [#{header_band_content}]],"
        end
      else
        ""
      end

    footer_content =
      if page_footer do
        "footer: [#{generate_band_content(page_footer, content_mode_context)}]"
      else
        "footer: context [Page #counter(page).display() of #counter(page).final().at(0)]"
      end

    "#{header_content}\n    #{footer_content}"
  end

  defp generate_report_content(report, context) do
    bands = report.bands || []

    # Group bands by processing order
    title_bands = filter_bands_by_type(bands, :title)
    column_header_bands = filter_bands_by_type(bands, :column_header)
    _group_header_bands = filter_bands_by_type(bands, :group_header)
    _detail_bands = filter_bands_by_type(bands, :detail)
    _group_footer_bands = filter_bands_by_type(bands, :group_footer)
    summary_bands = filter_bands_by_type(bands, :summary)

    content_parts = []

    # Title bands (once per report)
    content_parts =
      if length(title_bands) > 0 do
        content_parts ++ [generate_title_section(title_bands, context)]
      else
        content_parts
      end

    # Column headers (once before data)
    content_parts =
      if length(column_header_bands) > 0 do
        content_parts ++ [generate_column_header_section(column_header_bands, context)]
      else
        content_parts
      end

    # Main data processing section
    content_parts =
      if has_data_bands?(bands) do
        content_parts ++ [generate_data_processing_section(report, context)]
      else
        content_parts
      end

    # Summary bands (once per report)
    content_parts =
      if length(summary_bands) > 0 do
        content_parts ++ [generate_summary_section(summary_bands, context)]
      else
        content_parts
      end

    Enum.join(content_parts, "\n\n")
  end

  # Private Functions - Band Processing

  defp generate_title_section(title_bands, context) do
    """
    // Title Section
    #{Enum.map(title_bands, fn band -> generate_band_content(band, context) end) |> Enum.join("\n")}
    """
  end

  defp generate_column_header_section(column_header_bands, context) do
    """
    // Column Header Section
    #{Enum.map(column_header_bands, fn band -> generate_band_content(band, context) end) |> Enum.join("\n")}
    """
  end

  defp generate_data_processing_section(report, context) do
    """
    // Data Processing Section
    #{generate_grouping_logic(report, context)}
    """
  end

  defp generate_grouping_logic(report, context) do
    groups = report.groups || []

    if length(groups) > 0 do
      # Multi-level grouping
      generate_nested_grouping(groups, report, context)
    else
      # Simple detail processing
      generate_simple_detail_processing(report, context)
    end
  end

  defp generate_nested_grouping(groups, report, context) do
    bands = report.bands || []

    # Get all band types we need
    group_header_bands = filter_bands_by_type(bands, :group_header)
    detail_bands = filter_bands_by_type(bands, :detail)
    group_footer_bands = filter_bands_by_type(bands, :group_footer)

    # Sort groups by level
    sorted_groups = Enum.sort_by(groups, & &1.level)

    # Generate the nested iteration logic
    nested_loops = generate_nested_group_loops(
      sorted_groups,
      group_header_bands,
      detail_bands,
      group_footer_bands,
      context,
      0
    )

    """
    #{nested_loops}
    """
  end

  defp generate_simple_detail_processing(report, context) do
    detail_bands = filter_bands_by_type(report.bands || [], :detail)

    if length(detail_bands) > 0 do
      band_content = Enum.map(detail_bands, fn band -> generate_band_content(band, context) end) |> Enum.join("\n")

      """
      // Iterate over records
      for record in data.records {
      #{band_content}
      }
      """
    else
      "// No detail bands defined"
    end
  end

  defp generate_summary_section(summary_bands, context) do
    """
    // Summary Section
    #{Enum.map(summary_bands, fn band -> generate_band_content(band, context) end) |> Enum.join("\n")}
    """
  end

  defp generate_band_content(%Band{} = band, context) do
    # Check for layout primitives (new DSL format)
    grids = band.grids || []
    tables = band.tables || []
    stacks = band.stacks || []
    elements = band.elements || []

    cond do
      # Render grids
      length(grids) > 0 ->
        grids
        |> Enum.map(&generate_grid_content(&1, context))
        |> Enum.join("\n")

      # Render tables
      length(tables) > 0 ->
        tables
        |> Enum.map(&generate_table_content(&1, context))
        |> Enum.join("\n")

      # Render stacks
      length(stacks) > 0 ->
        stacks
        |> Enum.map(&generate_stack_content(&1, context))
        |> Enum.join("\n")

      # Render elements (labels, fields, etc.)
      length(elements) > 0 ->
        elements
        |> Enum.map(&generate_element(&1, context))
        |> Enum.join("\n")

      # No layout primitives or elements - empty band
      true ->
        "// Empty band: #{band.name}"
    end
  end

  # Generate Typst content from a Grid DSL entity
  defp generate_grid_content(grid, context) do
    alias AshReports.Layout.Transformer.Grid, as: GridTransformer
    alias AshReports.Renderer.Typst.Grid, as: GridRenderer

    case GridTransformer.transform(grid) do
      {:ok, ir} ->
        # Use generate_refs: true to output Typst variable references for fields
        # The actual data will be passed at runtime when the band function is called
        rendered = GridRenderer.render(ir, generate_refs: true)

        # If we're in a group context, post-process the output to replace
        # group-level variable references with actual group calculations
        rendered = maybe_replace_group_variables(rendered, context)

        # Check if grid has center alignment - if so, wrap in align(center)
        # Use # prefix when in content mode (inside [] blocks like page headers)
        prefix = if context[:content_mode], do: "#", else: ""
        align = get_in(ir.properties, [:align])
        if has_center_align?(align) do
          "#{prefix}align(center)[#{rendered}]"
        else
          "#{prefix}block(width: 100%, above: 0pt, below: 0pt)[#{rendered}]"
        end

      {:error, reason} ->
        Logger.warning("Failed to transform grid #{grid.name}: #{inspect(reason)}")
        "// Grid transformation failed: #{grid.name}"
    end
  end

  # Generate Typst content from a Table DSL entity
  defp generate_table_content(table, context) do
    alias AshReports.Layout.Transformer.Table, as: TableTransformer
    alias AshReports.Renderer.Typst.Table, as: TableRenderer

    case TableTransformer.transform(table) do
      {:ok, ir} ->
        # Use generate_refs: true to output Typst variable references for fields
        # The actual data will be passed at runtime when the band function is called
        rendered = TableRenderer.render(ir, generate_refs: true)

        # If we're in a group context, post-process the output to replace
        # group-level variable references with actual group calculations
        rendered = maybe_replace_group_variables(rendered, context)

        # Wrap in block with full width and no spacing to prevent gaps between repeated tables
        # in detail band loops. Use # prefix when in content mode (inside [] blocks like page headers)
        prefix = if context[:content_mode], do: "#", else: ""
        "#{prefix}block(width: 100%, above: 0pt, below: 0pt)[#{rendered}]"

      {:error, reason} ->
        Logger.warning("Failed to transform table #{table.name}: #{inspect(reason)}")
        "// Table transformation failed: #{table.name}"
    end
  end

  # Generate Typst content from a Stack DSL entity
  defp generate_stack_content(stack, context) do
    alias AshReports.Layout.Transformer.Stack, as: StackTransformer
    alias AshReports.Renderer.Typst.Stack, as: StackRenderer

    case StackTransformer.transform(stack) do
      {:ok, ir} ->
        # Use generate_refs: true to output Typst variable references for fields
        # The actual data will be passed at runtime when the band function is called
        rendered = StackRenderer.render(ir, generate_refs: true)

        # If we're in a group context, post-process the output to replace
        # group-level variable references with actual group calculations
        rendered = maybe_replace_group_variables(rendered, context)

        # Wrap in block with full width and no spacing to prevent gaps between repeated stacks
        # in detail band loops. Use # prefix when in content mode (inside [] blocks like page headers)
        prefix = if context[:content_mode], do: "#", else: ""
        "#{prefix}block(width: 100%, above: 0pt, below: 0pt)[#{rendered}]"

      {:error, reason} ->
        Logger.warning("Failed to transform stack #{stack.name}: #{inspect(reason)}")
        "// Stack transformation failed: #{stack.name}"
    end
  end

  # Post-process rendered content to replace group-level variable references
  # with actual group calculations when in a group header/footer context
  defp maybe_replace_group_variables(rendered, context) do
    is_group_context = Map.get(context, :is_group_header) || Map.get(context, :is_group_footer)
    report = Map.get(context, :report)

    if is_group_context do
      # First, replace the special group_value placeholder with group.key
      rendered = String.replace(rendered, "#data.variables.group_value", "#group.key")

      # Then, if we have report variables, replace group-level variable references
      if report do
        group_variables = Enum.filter(report.variables || [], fn v -> v.reset_on == :group end)

        Enum.reduce(group_variables, rendered, fn variable, acc ->
          # Replace #data.variables.variable_name with the group calculation
          pattern = "#data.variables.#{variable.name}"
          replacement = generate_group_variable_calculation(variable)
          String.replace(acc, pattern, replacement)
        end)
      else
        rendered
      end
    else
      rendered
    end
  end

  # Private Functions - Element Generation (kept for data iteration context)

  defp generate_field_element(%{source: source} = field, _context) do
    content =
      case source do
        {:resource, field_name} ->
          "[#record.#{field_name}]"

        {:parameter, param_name} ->
          "[#config.#{param_name}]"

        {:variable, var_name} ->
          "[#variables.#{var_name}]"

        field_name when is_atom(field_name) ->
          "[#record.#{field_name}]"

        %Ash.Query.Ref{attribute: %Ash.Resource.Attribute{name: field_name}} ->
          "[#record.#{field_name}]"

        %Ash.Query.Ref{relationship_path: [], attribute: attr} when is_atom(attr) ->
          "[#record.#{attr}]"

        %{__struct__: Ash.Query.Ref} = ref ->
          # Extract field name from Ash reference
          field_name = extract_field_from_ref(ref)
          "[#record.#{field_name}]"

        # Handle Ash expression structs
        %{__struct__: struct_module} = expr when is_atom(struct_module) ->
          case extract_field_from_expression(expr) do
            {:ok, field_name} -> "[#record.#{field_name}]"
            :error -> "[#record.unknown_field]"
          end

        _ ->
          Logger.warning("Unknown field source type: #{inspect(source)} for field: #{inspect(field.name)}")
          "[#record.unknown_field]"
      end

    apply_element_wrappers(content, field)
  end

  defp extract_field_from_ref(%Ash.Query.Ref{attribute: %{name: name}}), do: name
  defp extract_field_from_ref(%Ash.Query.Ref{attribute: name}) when is_atom(name), do: name
  defp extract_field_from_ref(_), do: :unknown_field

  defp extract_field_from_expression(%Ash.Query.Ref{} = ref), do: {:ok, extract_field_from_ref(ref)}
  defp extract_field_from_expression(_), do: :error

  defp generate_label_element(%{text: text} = label, context) do
    # Step 1: Replace group value placeholders if in group header/footer
    processed_text = if Map.get(context, :is_group_header) || Map.get(context, :is_group_footer) do
      # Replace [group_value] with actual Typst code to access the group key
      String.replace(text, "[group_value]", "#group.key")
    else
      text
    end

    # Step 2: Replace variable placeholders like [variable_name]
    # For group-level variables, calculate from group.records instead of using pre-computed values
    is_group_context = Map.get(context, :is_group_header) || Map.get(context, :is_group_footer)
    report = Map.get(context, :report)

    processed_text = Regex.replace(~r/\[([a-z_][a-z0-9_]*)\]/i, processed_text, fn _full_match, var_name ->
      var_atom = String.to_atom(var_name)

      # Try to find variable definition in report
      variable_def = if report do
        Enum.find(report.variables || [], fn v -> v.name == var_atom end)
      end

      cond do
        # Group-level variable in group context - calculate from group.records
        is_group_context && variable_def && variable_def.reset_on == :group ->
          generate_group_variable_calculation(variable_def)

        # Regular variable - use data.variables
        true ->
          "#data.variables.#{var_name}"
      end
    end)

    content = "[#{processed_text}]"
    apply_element_wrappers(content, label)
  end

  # Generate Typst code to calculate group-level variable from group.records
  defp generate_group_variable_calculation(variable_def) do
    field_name = extract_variable_field_name(variable_def.expression)

    case variable_def.type do
      :count ->
        "\#group.records.len()"

      :sum ->
        if field_name do
          # Sum the field values from group records
          "\#{ group.records.map(r => r." <> field_name <> ").fold(0, (a, b) => a + b) }"
        else
          "\#group.records.len()"
        end

      :average ->
        if field_name do
          # Calculate average: sum / count, with divide-by-zero protection
          "\#{ let vals = group.records.map(r => r." <> field_name <> "); let sum = vals.fold(0, (a, b) => a + b); let count = vals.len(); if count == 0 { 0 } else { calc.round(sum / count, digits: 2) } }"
        else
          "0"
        end

      :avg ->
        if field_name do
          "\#{ let vals = group.records.map(r => r." <> field_name <> "); let sum = vals.fold(0, (a, b) => a + b); let count = vals.len(); if count == 0 { 0 } else { calc.round(sum / count, digits: 2) } }"
        else
          "0"
        end

      _ ->
        "#data.variables.#{variable_def.name}"
    end
  end

  # Extract field name from variable expression
  defp extract_variable_field_name(expression) when is_atom(expression), do: Atom.to_string(expression)

  defp extract_variable_field_name(%Ash.Query.Ref{attribute: %{name: name}}), do: Atom.to_string(name)

  defp extract_variable_field_name(%Ash.Query.Ref{attribute: name}) when is_atom(name), do: Atom.to_string(name)

  defp extract_variable_field_name(_), do: nil

  defp generate_expression_element(%{expression: expression} = expr, context) do
    # Convert AshReports expression to Typst expression
    typst_expr = convert_expression_to_typst(expression, context)
    content = "[#(#{typst_expr})]"
    apply_element_wrappers(content, expr)
  end

  defp generate_aggregate_element(%{function: function, source: source} = aggregate, _context) do
    # Generate aggregate calculation with division-by-zero protection
    content =
      case function do
        :sum -> "[Sum: #data.records.map(r => r.#{source}).sum()]"
        :count -> "[Count: #data.records.len()]"
        # Protect against division by zero in average calculations
        :average -> "[Avg: \#{ let len = data.records.len(); if len == 0 { 0 } else { data.records.map(r => r.#{source}).sum() / len } }]"
        :avg -> "[Avg: \#{ let len = data.records.len(); if len == 0 { 0 } else { data.records.map(r => r.#{source}).sum() / len } }]"
        :min -> "[Min: #calc.min(..data.records.map(r => r.#{source}))]"
        :max -> "[Max: #calc.max(..data.records.map(r => r.#{source}))]"
        _ -> "[Aggregate: #{function}]"
      end

    apply_element_wrappers(content, aggregate)
  end

  defp generate_line_element(%{} = line, _context) do
    orientation = Map.get(line, :orientation, :horizontal)
    thickness = Map.get(line, :thickness, 1)
    stroke = "#{thickness}pt"

    case orientation do
      :horizontal -> "[#line(length: 100%, stroke: #{stroke})]"
      :vertical -> "[#line(angle: 90deg, length: 2em, stroke: #{stroke})]"
      _ -> "[#line(length: 100%, stroke: #{stroke})]"
    end
  end

  defp generate_box_element(%{} = box, _context) do
    # Extract box properties with safe defaults
    border =
      case Map.get(box, :border) do
        nil -> %{}
        border when is_map(border) -> border
        _ -> %{}
      end

    fill =
      case Map.get(box, :fill) do
        nil -> %{}
        fill when is_map(fill) -> fill
        _ -> %{}
      end

    # Build Typst rect parameters
    params = ["width: 100%", "height: 1em"]

    # Add stroke (border)
    stroke_width = Map.get(border, :width, 0.5)
    stroke_color = Map.get(border, :color, "black")
    params = params ++ ["stroke: #{stroke_width}pt + #{stroke_color}"]

    # Add fill color if specified
    params =
      case Map.get(fill, :color) do
        nil -> params
        color -> params ++ ["fill: #{color}"]
      end

    param_string = Enum.join(params, ", ")
    "[#rect(#{param_string})]"
  end

  defp generate_image_element(%{source: source} = image, _context) do
    scale_mode = Map.get(image, :scale_mode, :fit)

    # Convert scale mode to Typst fit parameter
    fit_param =
      case scale_mode do
        :fit -> "fit: \"contain\""
        :fill -> "fit: \"cover\""
        :stretch -> "fit: \"stretch\""
        :none -> "fit: \"contain\""
        _ -> "fit: \"contain\""
      end

    "[#image(\"#{source}\", width: 5cm, #{fit_param})]"
  end

  defp generate_chart_element(chart, context) do
    # Check if preprocessed chart data is available
    chart_data = get_in(context, [:charts, chart.name])

    if chart_data do
      # Use preprocessed chart
      generate_preprocessed_chart(chart, chart_data, context)
    else
      # No preprocessed data - generate placeholder
      generate_chart_placeholder(chart, context)
    end
  end

  defp generate_preprocessed_chart(chart, chart_data, _context) do
    lines = []

    # Add title if present
    lines =
      case Map.get(chart, :title) do
        nil -> lines
        title when is_binary(title) -> lines ++ ["#text(size: 14pt, weight: \"bold\")[#{title}]"]
        _ -> lines
      end

    # Add embedded chart code
    lines = lines ++ [chart_data.embedded_code]

    # Add caption if present
    lines =
      case Map.get(chart, :caption) do
        nil ->
          lines

        caption when is_binary(caption) ->
          lines ++ ["#text(size: 10pt, style: \"italic\")[#{caption}]"]

        _ ->
          lines
      end

    Enum.join(lines, "\n")
  end

  defp generate_chart_placeholder(chart, _context) do
    chart_type = Map.get(chart, :chart_type, :bar)
    caption = Map.get(chart, :caption)
    title = Map.get(chart, :title)

    lines = []

    # Add title if present
    lines =
      if title do
        lines ++ ["#text(size: 14pt, weight: \"bold\")[#{title}]"]
      else
        lines
      end

    # Add chart placeholder (will be replaced with actual chart generation)
    lines = lines ++ ["// Chart: #{chart.name} (#{chart_type})"]

    # Add caption if present
    lines =
      if caption do
        lines ++ ["#text(size: 10pt, style: \"italic\")[#{caption}]"]
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  # Private Functions - Expression Conversion

  defp convert_expression_to_typst(expression, _context) when is_binary(expression) do
    # Simple string expressions - TODO: implement proper parsing
    expression
  end

  defp convert_expression_to_typst({:field, field_name}, _context) do
    "record.#{field_name}"
  end

  defp convert_expression_to_typst({:add, left, right}, context) do
    "(#{convert_expression_to_typst(left, context)} + #{convert_expression_to_typst(right, context)})"
  end

  defp convert_expression_to_typst({:gt, left, right}, context) do
    "#{convert_expression_to_typst(left, context)} > #{convert_expression_to_typst(right, context)}"
  end

  defp convert_expression_to_typst(expression, _context) do
    inspect(expression)
  end

  # Private Functions - Utilities

  defp extract_report_variables(report) do
    report.variables || []
  end

  defp extract_report_groups(report) do
    report.groups || []
  end

  defp find_band_by_type(bands, type) do
    Enum.find(bands || [], &(&1.type == type))
  end

  defp filter_bands_by_type(bands, type) do
    Enum.filter(bands || [], &(&1.type == type))
  end

  # Grouping helper functions

  defp extract_group_field_name(expression) when is_atom(expression) do
    Atom.to_string(expression)
  end

  # Handle Ash.Query.Ref (from expr(field_name))
  defp extract_group_field_name(%Ash.Query.Ref{attribute: %{name: field_name}}) when is_atom(field_name) do
    Atom.to_string(field_name)
  end

  defp extract_group_field_name(%Ash.Query.Ref{attribute: field_name}) when is_atom(field_name) do
    Atom.to_string(field_name)
  end

  defp extract_group_field_name(%{expression: {:ref, [], field}}) when is_atom(field) do
    Atom.to_string(field)
  end

  defp extract_group_field_name(%{expression: {:get_path, _, [%{expression: {:ref, [], rel}}, field]}}) do
    # Handle relationship traversal like addresses.state
    "#{rel}.#{field}"
  end

  defp extract_group_field_name(_), do: "unknown"

  defp generate_nested_group_loops(groups, group_header_bands, detail_bands, group_footer_bands, context, level) do
    if level >= length(groups) do
      # Base case: generate detail bands
      generate_detail_iteration_simple(detail_bands, context)
    else
      # Recursive case: generate group break logic
      current_group = Enum.at(groups, level)
      group_level = current_group.level
      group_field = extract_group_field_name(current_group.expression)

      # Find bands for this group level
      header_band = Enum.find(group_header_bands, &(&1.group_level == group_level))
      footer_band = Enum.find(group_footer_bands, &(&1.group_level == group_level))

      # Generate header content
      header_content = if header_band do
        generate_band_content(header_band, Map.put(context, :is_group_header, true))
      else
        ""
      end

      # Generate footer content
      footer_content = if footer_band do
        generate_band_content(footer_band, Map.put(context, :is_group_footer, true))
      else
        ""
      end

      # For level 0, we use a simple approach: track group value changes
      if level == 0 do
        # Try direct field name first (for simple fields/aggregates), then calculated field (for complex expressions)
        calc_field_name = "__group_#{group_level}_#{current_group.name}"

        """
        // Grouping by #{group_field}
        {
          let prev_group_value = none
          let group_records = ()

          for record in data.records {
            // Try direct field first, fall back to calculated field
            let current_group_value = if "#{group_field}" in record {
              record.at("#{group_field}", default: none)
            } else {
              record.at("#{calc_field_name}", default: none)
            }

            // Check for group break
            if prev_group_value != none and prev_group_value != current_group_value {
              // Process accumulated group records
              if group_records.len() > 0 {
                let group = (key: prev_group_value, records: group_records)
        #{indent_content(header_content, 4)}
        #{indent_content("v(8pt)", 4)}
        #{indent_content("// Detail records", 4)}
        #{indent_content(generate_detail_records_loop(detail_bands, context), 4)}
        #{indent_content(footer_content, 4)}
        #{indent_content("v(12pt)", 4)}
              }
              group_records = ()
            }

            group_records.push(record)
            prev_group_value = current_group_value
          }

          // Process final group
          if group_records.len() > 0 {
            let group = (key: prev_group_value, records: group_records)
        #{indent_content(header_content, 3)}
        #{indent_content("v(8pt)", 3)}
        #{indent_content("// Detail records", 3)}
        #{indent_content(generate_detail_records_loop(detail_bands, context), 3)}
        #{indent_content(footer_content, 3)}
        #{indent_content("v(12pt)", 3)}
          }
        }
        """
      else
        # Nested grouping not yet supported
        generate_detail_iteration_simple(detail_bands, context)
      end
    end
  end

  defp generate_detail_iteration_simple(detail_bands, context) do
    if length(detail_bands) > 0 do
      band_content = Enum.map(detail_bands, fn band ->
        generate_band_content(band, context)
      end) |> Enum.join("\n")

      """
      // Detail records iteration
      for record in data.records {
      #{indent_content(band_content, 1)}
      }
      """
    else
      "// No detail bands defined"
    end
  end

  defp generate_detail_records_loop(detail_bands, context) do
    if length(detail_bands) > 0 do
      band_content = Enum.map(detail_bands, fn band ->
        generate_band_content(band, context)
      end) |> Enum.join("\n")

      """
      for record in group.records {
      #{indent_content(band_content, 1)}
      }
      """
    else
      ""
    end
  end

  defp indent_content(content, levels) do
    indent = String.duplicate("  ", levels)
    content
    |> String.split("\n")
    |> Enum.map(fn line -> if String.trim(line) == "", do: "", else: indent <> line end)
    |> Enum.join("\n")
  end

  defp has_data_bands?(bands) do
    data_band_types = [:detail, :group_header, :group_footer]
    Enum.any?(bands || [], fn band -> band.type in data_band_types end)
  end

  defp get_paper_size(:pdf), do: "a4"
  defp get_paper_size(_), do: "a4"

  # Private Functions - Data Serialization

  defp serialize_context_data(%{context: %{records: records, variables: variables}}) when is_list(records) do
    # Serialize records and variables from RenderContext
    serialized_records = serialize_records(records)
    serialized_variables = serialize_variables(variables)
    "#let report_data = (records: #{serialized_records}, variables: #{serialized_variables})"
  end

  defp serialize_context_data(%{context: %{records: records}}) when is_list(records) do
    # Serialize records from RenderContext (no variables)
    serialized_records = serialize_records(records)
    "#let report_data = (records: #{serialized_records}, variables: (:))"
  end

  defp serialize_context_data(_context) do
    # No context or no records - use empty data
    "#let report_data = (records: (), variables: (:))"
  end

  # Helper to check if alignment includes center
  defp has_center_align?(:center), do: true
  defp has_center_align?({:center, _}), do: true
  defp has_center_align?({_, :center}), do: true
  defp has_center_align?("center"), do: true
  defp has_center_align?(align) when is_binary(align), do: String.contains?(align, "center")
  defp has_center_align?(_), do: false

  defp serialize_records([]), do: "()"

  defp serialize_records(records) when is_list(records) do
    serialized =
      records
      |> Enum.take(100)  # Limit to first 100 records to prevent huge templates
      |> Enum.map(&serialize_record/1)
      |> Enum.join(",\n    ")

    "(#{serialized})"
  end

  defp serialize_variables(variables) when is_map(variables) do
    if map_size(variables) == 0 do
      "(:)"
    else
      fields =
        variables
        |> Enum.map(fn {key, value} -> "#{key}: #{serialize_value(value)}" end)
        |> Enum.join(", ")

      "(#{fields})"
    end
  end

  defp serialize_variables(_), do: "(:)"

  defp serialize_record(%_{} = struct) do
    # Convert struct to map - Ash stores loaded calculations directly on the struct
    base_map = Map.from_struct(struct)

    # Remove internal Ash keys that shouldn't be serialized
    base_map
    |> Map.drop([:__meta__, :calculations, :aggregates, :__metadata__, :__lateral_join_source__, :__order__])
    |> serialize_map()
  end

  defp serialize_record(map) when is_map(map) do
    serialize_map(map)
  end

  defp serialize_map(map) do
    fields =
      map
      |> Enum.reject(fn {key, _value} -> key == :__meta__ end)
      |> Enum.map(fn {key, value} -> "#{key}: #{serialize_value(value)}" end)
      |> Enum.join(", ")

    "(#{fields})"
  end

  defp serialize_value(nil), do: "none"
  defp serialize_value(true), do: "true"
  defp serialize_value(false), do: "false"

  defp serialize_value(value) when is_binary(value) do
    # Escape quotes and wrap in quotes
    escaped = String.replace(value, "\"", "\\\"")
    "\"#{escaped}\""
  end

  defp serialize_value(value) when is_integer(value), do: to_string(value)
  defp serialize_value(value) when is_float(value), do: to_string(value)

  defp serialize_value(%Decimal{} = decimal) do
    Decimal.to_string(decimal)
  end

  defp serialize_value(%DateTime{} = dt) do
    "\"#{DateTime.to_iso8601(dt)}\""
  end

  defp serialize_value(%Date{} = date) do
    "\"#{Date.to_iso8601(date)}\""
  end

  defp serialize_value(value) when is_atom(value) do
    "\"#{Atom.to_string(value)}\""
  end

  defp serialize_value(value) when is_list(value) do
    serialized = Enum.map(value, &serialize_value/1) |> Enum.join(", ")
    "(#{serialized})"
  end

  defp serialize_value(_value), do: "none"

  # Private Functions - Position and Style Support

  @doc false
  defp extract_position(element) when is_map(element) do
    Map.get(element, :position, [])
  end

  @doc false
  defp extract_style(element) when is_map(element) do
    Map.get(element, :style, [])
  end

  @doc false
  defp alignment_to_typst(align) when is_atom(align) do
    case align do
      :center -> "center"
      :top -> "top"
      :bottom -> "bottom"
      :horizon -> "horizon"
      :left -> "left"
      :right -> "right"
      :start -> "start"
      :end -> "end"
      _ -> nil
    end
  end

  @doc false
  defp build_alignment_string(align) when is_atom(align) do
    alignment_to_typst(align)
  end

  defp build_alignment_string(align) when is_list(align) do
    # Convert list of alignment atoms to Typst syntax: top + center
    align
    |> Enum.map(&alignment_to_typst/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" + ")
  end

  @doc false
  defp generate_position_wrapper(content, element) when is_map(element) do
    position = extract_position(element)

    if position != [] and is_list(position) do
      # Check if using alignment-based positioning
      align = Keyword.get(position, :align)

      cond do
        # Alignment-based positioning (e.g., position align: :center or align: [:top, :center])
        align != nil ->
          alignment_str = build_alignment_string(align)
          if alignment_str != "" do
            # No # prefix - we're in code mode inside function body
            "place(#{alignment_str})[#{content}]"
          else
            content
          end

        # Horizontal-only positioning - skip, handled at band level for columns
        Keyword.has_key?(position, :x) and not Keyword.has_key?(position, :y) ->
          content

        # Absolute positioning with both x and y (existing behavior)
        Keyword.has_key?(position, :x) or Keyword.has_key?(position, :y) ->
          dx = Keyword.get(position, :x, 0)
          dy = Keyword.get(position, :y, 0)

          # Convert to Typst units (assuming pixels to points conversion)
          dx_pt = "#{dx}pt"
          dy_pt = "#{dy}pt"

          # No # prefix - we're in code mode inside function body
          "place(dx: #{dx_pt}, dy: #{dy_pt})[#{content}]"

        # No valid positioning attributes
        true ->
          content
      end
    else
      content
    end
  end

  @doc false
  defp generate_style_wrapper(content, element) when is_map(element) do
    style = extract_style(element)

    if style != [] and is_list(style) do
      # Build Typst text() parameters from style attributes
      params = build_style_params(style)

      if params != "" do
        # No # prefix - we're in code mode inside function body
        "text(#{params})[#{content}]"
      else
        content
      end
    else
      content
    end
  end

  @doc false
  defp build_style_params(style) when is_list(style) do
    params = []

    # Font size
    params =
      case Keyword.get(style, :font_size) do
        nil -> params
        size when is_integer(size) -> params ++ ["size: #{size}pt"]
        size when is_binary(size) -> params ++ ["size: #{size}"]
        _ -> params
      end

    # Color (convert hex to rgb())
    params =
      case Keyword.get(style, :color) do
        nil ->
          params

        color when is_binary(color) ->
          # Strip leading # if present (Typst rgb() doesn't accept it)
          clean_color = String.trim_leading(color, "#")
          params ++ ["fill: rgb(\"#{clean_color}\")"]

        _ ->
          params
      end

    # Font weight
    params =
      case Keyword.get(style, :font_weight) do
        nil -> params
        weight when is_binary(weight) -> params ++ ["weight: \"#{weight}\""]
        weight when is_atom(weight) -> params ++ ["weight: \"#{Atom.to_string(weight)}\""]
        _ -> params
      end

    # Font family
    params =
      case Keyword.get(style, :font) do
        nil -> params
        font when is_binary(font) -> params ++ ["font: \"#{font}\""]
        _ -> params
      end

    # Alignment
    params =
      case Keyword.get(style, :alignment) do
        nil -> params
        :left -> params ++ ["align: left"]
        :center -> params ++ ["align: center"]
        :right -> params ++ ["align: right"]
        :justify -> params ++ ["align: justify"]
        align when is_atom(align) -> params ++ ["align: #{Atom.to_string(align)}"]
        _ -> params
      end

    Enum.join(params, ", ")
  end

  @doc false
  defp apply_element_wrappers(content, element) when is_map(element) do
    # Strip outer brackets from content if present, since wrappers will add them back
    inner_content = strip_outer_brackets(content)

    # Apply wrappers in order: style (innermost) -> padding -> margin -> position (outermost)
    wrapped =
      inner_content
      |> generate_style_wrapper(element)
      |> generate_padding_wrapper(element)
      |> generate_margin_wrapper(element)
      |> generate_position_wrapper(element)

    # If no wrappers were applied, re-add the brackets
    if wrapped == inner_content do
      content  # Return original with brackets
    else
      wrapped  # Return wrapped (wrappers add brackets)
    end
  end

  @doc false
  defp generate_padding_wrapper(content, element) when is_map(element) do
    padding = Map.get(element, :padding)

    case padding do
      nil ->
        content

      # Single value padding (e.g., "10pt")
      value when is_binary(value) ->
        # No # prefix - we're in code mode inside function body
        "pad(#{value})[#{content}]"

      # Keyword list padding (e.g., [top: "5pt", bottom: "10pt"])
      opts when is_list(opts) ->
        params = build_padding_params(opts)

        if params != "" do
          # No # prefix - we're in code mode inside function body
          "pad(#{params})[#{content}]"
        else
          content
        end

      _ ->
        content
    end
  end

  @doc false
  defp generate_margin_wrapper(content, element) when is_map(element) do
    margin = Map.get(element, :margin)

    case margin do
      nil ->
        content

      # Single value margin (e.g., "10pt")
      value when is_binary(value) ->
        # No # prefix - we're in code mode inside function body
        "pad(#{value})[#{content}]"

      # Keyword list margin (e.g., [top: "5pt", bottom: "10pt"])
      opts when is_list(opts) ->
        params = build_padding_params(opts)

        if params != "" do
          # No # prefix - we're in code mode inside function body
          "pad(#{params})[#{content}]"
        else
          content
        end

      _ ->
        content
    end
  end

  @doc false
  defp build_padding_params(opts) when is_list(opts) do
    params = []

    # Individual sides
    params =
      case Keyword.get(opts, :top) do
        nil -> params
        value -> params ++ ["top: #{value}"]
      end

    params =
      case Keyword.get(opts, :bottom) do
        nil -> params
        value -> params ++ ["bottom: #{value}"]
      end

    params =
      case Keyword.get(opts, :left) do
        nil -> params
        value -> params ++ ["left: #{value}"]
      end

    params =
      case Keyword.get(opts, :right) do
        nil -> params
        value -> params ++ ["right: #{value}"]
      end

    # Shortcuts
    params =
      case Keyword.get(opts, :x) do
        nil -> params
        value -> params ++ ["x: #{value}"]
      end

    params =
      case Keyword.get(opts, :y) do
        nil -> params
        value -> params ++ ["y: #{value}"]
      end

    params =
      case Keyword.get(opts, :rest) do
        nil -> params
        value -> params ++ ["rest: #{value}"]
      end

    Enum.join(params, ", ")
  end

  @doc false
  defp strip_outer_brackets(content) when is_binary(content) do
    # Remove outer [...] if present
    content = String.trim(content)

    if String.starts_with?(content, "[") and String.ends_with?(content, "]") do
      content
      |> String.slice(1..-2//1)
    else
      content
    end
  end
end
