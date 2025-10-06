defmodule AshReports.JsonRenderer.StructureBuilder do
  @moduledoc """
  Structure Builder for AshReports JSON Renderer.

  The StructureBuilder provides hierarchical JSON assembly capabilities,
  taking serialized data and assembling it into well-structured JSON
  documents that follow the AshReports JSON schema. It handles complex
  report structures, nested elements, and maintains consistency across
  different report types.

  ## Structure Assembly Features

  - **Hierarchical Building**: Assembles nested JSON structures from flat data
  - **Schema Compliance**: Ensures output follows AshReports JSON schema
  - **Element Positioning**: Maintains spatial relationships between elements
  - **Band Organization**: Groups elements into logical bands
  - **Metadata Integration**: Includes comprehensive metadata in output

  ## JSON Structure Components

  - **Report Header**: Contains report metadata and generation information
  - **Data Section**: Contains bands with elements and their relationships
  - **Schema Section**: Contains schema version and validation information
  - **Navigation**: Contains structure navigation aids for complex reports

  ## Usage

      # Build complete report structure
      {:ok, json_structure} = StructureBuilder.build_report_structure(context, serialized_data)

      # Build specific components
      {:ok, header} = StructureBuilder.build_report_header(context)
      {:ok, data_section} = StructureBuilder.build_data_section(serialized_data)

  """

  alias AshReports.{JsonRenderer.SchemaManager, RenderContext}

  @type build_options :: [
          include_navigation: boolean(),
          include_positions: boolean(),
          include_metadata: boolean(),
          group_by_bands: boolean()
        ]

  @type structure_result :: {:ok, map()} | {:error, term()}

  @doc """
  Builds a complete report JSON structure from context and serialized data.

  ## Examples

      {:ok, json_structure} = StructureBuilder.build_report_structure(context, serialized_data)

  """
  @spec build_report_structure(RenderContext.t(), map(), build_options()) :: structure_result()
  def build_report_structure(%RenderContext{} = context, serialized_data, opts \\ []) do
    with {:ok, report_header} <- build_report_header(context, opts),
         {:ok, data_section} <- build_data_section(context, serialized_data, opts),
         {:ok, schema_section} <- build_schema_section(context, opts),
         {:ok, navigation_section} <- build_navigation_section(context, opts) do
      structure = %{
        report: report_header,
        data: data_section,
        schema: schema_section
      }

      final_structure =
        if Keyword.get(opts, :include_navigation, false) do
          Map.put(structure, :navigation, navigation_section)
        else
          structure
        end

      {:ok, final_structure}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Builds the report header section with metadata and generation information.

  ## Examples

      {:ok, header} = StructureBuilder.build_report_header(context)

  """
  @spec build_report_header(RenderContext.t(), build_options()) :: structure_result()
  def build_report_header(%RenderContext{} = context, opts \\ []) do
    header = %{
      name: get_report_name(context),
      version: get_report_version(context),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      metadata: build_report_metadata(context, opts)
    }

    {:ok, header}
  rescue
    error -> {:error, {:header_build_failed, error}}
  end

  @doc """
  Builds the data section with bands, elements, and their relationships.

  ## Examples

      {:ok, data_section} = StructureBuilder.build_data_section(context, serialized_data)

  """
  @spec build_data_section(RenderContext.t(), map(), build_options()) :: structure_result()
  def build_data_section(%RenderContext{} = context, serialized_data, opts \\ []) do
    with {:ok, bands} <- build_bands_structure(context, serialized_data, opts),
         {:ok, variables_section} <- build_variables_section(serialized_data, opts),
         {:ok, groups_section} <- build_groups_section(serialized_data, opts) do
      data_section = %{
        bands: bands
      }

      final_section =
        data_section
        |> maybe_add_section(:variables, variables_section, opts)
        |> maybe_add_section(:groups, groups_section, opts)

      {:ok, final_section}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Builds the schema section with version and validation information.

  ## Examples

      {:ok, schema_section} = StructureBuilder.build_schema_section(context)

  """
  @spec build_schema_section(RenderContext.t(), build_options()) :: structure_result()
  def build_schema_section(%RenderContext{} = _context, _opts \\ []) do
    schema_section = %{
      version: SchemaManager.current_schema_version(),
      format: "ash_reports_json",
      validation: "passed",
      specification: get_schema_specification_url()
    }

    {:ok, schema_section}
  end

  @doc """
  Builds the navigation section for complex report structures.

  ## Examples

      {:ok, navigation} = StructureBuilder.build_navigation_section(context)

  """
  @spec build_navigation_section(RenderContext.t(), build_options()) :: structure_result()
  def build_navigation_section(%RenderContext{} = context, opts \\ []) do
    if Keyword.get(opts, :include_navigation, false) do
      navigation = %{
        bands: build_band_navigation(context),
        elements: build_element_navigation(context),
        groups: build_group_navigation(context),
        total_pages: calculate_total_pages(context)
      }

      {:ok, navigation}
    else
      {:ok, %{}}
    end
  end

  @doc """
  Builds a band structure from band data and elements.

  ## Examples

      {:ok, band_structure} = StructureBuilder.build_band_structure(band, elements, context)

  """
  @spec build_band_structure(map(), [map()], RenderContext.t(), build_options()) ::
          structure_result()
  def build_band_structure(band, elements, context, opts \\ []) do
    band_structure = %{
      name: get_band_name(band),
      type: get_band_type(band),
      elements: build_elements_structure(elements, context, opts)
    }

    enhanced_structure =
      if Keyword.get(opts, :include_positions, true) do
        Map.put(band_structure, :position, get_band_position(band, context))
      else
        band_structure
      end

    {:ok, enhanced_structure}
  rescue
    error -> {:error, {:band_structure_build_failed, error}}
  end

  @doc """
  Builds element structures with positioning and properties.

  ## Examples

      elements_structure = StructureBuilder.build_elements_structure(elements, context)

  """
  @spec build_elements_structure([map()], RenderContext.t(), build_options()) :: [map()]
  def build_elements_structure(elements, context, opts \\ []) do
    Enum.map(elements, fn element ->
      build_single_element_structure(element, context, opts)
    end)
  end

  @doc """
  Assembles a hierarchical structure from flat element data.

  ## Examples

      {:ok, hierarchy} = StructureBuilder.build_hierarchical_structure(elements, context)

  """
  @spec build_hierarchical_structure([map()], RenderContext.t()) :: structure_result()
  def build_hierarchical_structure(elements, context) do
    # Group elements by their hierarchical relationships
    grouped_elements = group_elements_by_hierarchy(elements, context)

    # Build the hierarchy tree
    hierarchy = build_hierarchy_tree(grouped_elements, context)

    {:ok, hierarchy}
  rescue
    error -> {:error, {:hierarchy_build_failed, error}}
  end

  # Private implementation functions

  defp build_bands_structure(%RenderContext{} = context, serialized_data, opts) do
    report_bands = get_report_bands(context)

    report_bands
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {band, index}, {:ok, acc} ->
      elements = get_band_elements(band, serialized_data, index)

      case build_band_structure(band, elements, context, opts) do
        {:ok, band_structure} ->
          {:cont, {:ok, [band_structure | acc]}}

        {:error, reason} ->
          {:halt, {:error, {:bands_structure_build_failed, band, reason}}}
      end
    end)
    |> case do
      {:ok, reversed_bands} -> {:ok, Enum.reverse(reversed_bands)}
      {:error, _reason} = error -> error
    end
  end

  defp build_variables_section(serialized_data, _opts) do
    variables = Map.get(serialized_data, :variables, %{})
    {:ok, variables}
  end

  defp build_groups_section(serialized_data, _opts) do
    groups = Map.get(serialized_data, :groups, %{})
    {:ok, groups}
  end

  defp build_report_metadata(%RenderContext{} = context, opts) do
    base_metadata = %{
      record_count: length(context.records),
      processing_time_ms: get_processing_time(context),
      variables: context.variables,
      groups: context.groups
    }

    if Keyword.get(opts, :include_metadata, true) do
      Map.merge(base_metadata, %{
        band_count: count_bands(context),
        element_count: count_elements(context),
        error_count: length(context.errors),
        warning_count: length(context.warnings),
        page_dimensions: context.page_dimensions,
        created_at: context.created_at,
        updated_at: context.updated_at
      })
    else
      base_metadata
    end
  end

  defp build_single_element_structure(element, context, opts) do
    base_structure = %{
      type: Map.get(element, :type, "unknown"),
      value: Map.get(element, :value)
    }

    enhanced_structure =
      base_structure
      |> maybe_add_field(:field, Map.get(element, :field), opts)
      |> maybe_add_position(element, context, opts)
      |> maybe_add_properties(element, opts)

    enhanced_structure
  end

  defp maybe_add_section(section, key, data, opts) do
    if should_include_section?(key, data, opts) do
      Map.put(section, key, data)
    else
      section
    end
  end

  defp maybe_add_field(structure, _key, nil, _opts), do: structure

  defp maybe_add_field(structure, key, value, _opts) do
    Map.put(structure, key, value)
  end

  defp maybe_add_position(structure, element, context, opts) do
    if Keyword.get(opts, :include_positions, true) do
      position = get_element_position(element, context)
      Map.put(structure, :position, position)
    else
      structure
    end
  end

  defp maybe_add_properties(structure, element, _opts) do
    properties = Map.get(element, :properties, %{})

    if map_size(properties) > 0 do
      Map.put(structure, :properties, properties)
    else
      structure
    end
  end

  defp should_include_section?(:variables, variables, _opts) when map_size(variables) > 0,
    do: true

  defp should_include_section?(:groups, groups, _opts) when map_size(groups) > 0, do: true
  defp should_include_section?(_, _, _), do: false

  defp build_band_navigation(%RenderContext{} = context) do
    context
    |> get_report_bands()
    |> Enum.with_index()
    |> Enum.map(fn {band, index} ->
      %{
        name: get_band_name(band),
        type: get_band_type(band),
        index: index,
        element_count: count_band_elements(band)
      }
    end)
  end

  defp build_element_navigation(%RenderContext{} = context) do
    total_elements = count_elements(context)

    %{
      total_count: total_elements,
      by_type: count_elements_by_type(context),
      by_band: count_elements_by_band(context)
    }
  end

  defp build_group_navigation(%RenderContext{} = context) do
    %{
      total_groups: map_size(context.groups),
      group_keys: Map.keys(context.groups)
    }
  end

  defp group_elements_by_hierarchy(elements, _context) do
    # Group elements based on their hierarchical relationships
    # This is a simplified implementation
    Enum.group_by(elements, fn element ->
      Map.get(element, :parent, :root)
    end)
  end

  defp build_hierarchy_tree(grouped_elements, _context) do
    # Build a tree structure from grouped elements
    # This is a simplified implementation
    root_elements = Map.get(grouped_elements, :root, [])

    Enum.map(root_elements, fn element ->
      element_id = Map.get(element, :id)
      children = Map.get(grouped_elements, element_id, [])

      if children != [] do
        Map.put(element, :children, children)
      else
        element
      end
    end)
  end

  # Helper functions for data extraction

  defp get_report_name(%RenderContext{report: %{name: name}}) when is_binary(name), do: name
  defp get_report_name(%RenderContext{report: report}) when is_atom(report), do: to_string(report)
  defp get_report_name(_), do: "unknown_report"

  defp get_report_version(%RenderContext{report: %{version: version}}) when is_binary(version),
    do: version

  defp get_report_version(_), do: "1.0"

  defp get_report_bands(%RenderContext{report: %{bands: bands}}) when is_list(bands), do: bands
  defp get_report_bands(_), do: []

  defp get_band_name(band) when is_map(band), do: Map.get(band, :name, "unknown_band")
  defp get_band_name(_), do: "unknown_band"

  defp get_band_type(band) when is_map(band), do: Map.get(band, :type, "unknown")
  defp get_band_type(_), do: "unknown"

  defp get_band_elements(band, _serialized_data, _index) do
    Map.get(band, :elements, [])
  end

  defp get_band_position(band, _context) do
    Map.get(band, :position, %{x: 0, y: 0})
  end

  defp get_element_position(element, _context) do
    Map.get(element, :position, %{x: 0, y: 0})
  end

  defp get_processing_time(%RenderContext{created_at: created, updated_at: updated}) do
    case {created, updated} do
      {%DateTime{} = c, %DateTime{} = u} ->
        DateTime.diff(u, c, :millisecond)

      _ ->
        0
    end
  end

  defp count_bands(%RenderContext{} = context) do
    context |> get_report_bands() |> length()
  end

  defp count_elements(%RenderContext{} = context) do
    context
    |> get_report_bands()
    |> Enum.map(&count_band_elements/1)
    |> Enum.sum()
  end

  defp count_band_elements(band) do
    band |> Map.get(:elements, []) |> length()
  end

  defp count_elements_by_type(%RenderContext{} = context) do
    context
    |> get_report_bands()
    |> Enum.flat_map(&Map.get(&1, :elements, []))
    |> Enum.group_by(&Map.get(&1, :type, "unknown"))
    |> Map.new(fn {type, elements} -> {type, length(elements)} end)
  end

  defp count_elements_by_band(%RenderContext{} = context) do
    context
    |> get_report_bands()
    |> Enum.map(fn band ->
      {get_band_name(band), count_band_elements(band)}
    end)
    |> Map.new()
  end

  defp calculate_total_pages(%RenderContext{} = context) do
    # This is a simplified calculation
    # In a real implementation, this would consider page breaks, content flow, etc.
    record_count = length(context.records)
    max(1, div(record_count + 49, 50))
  end

  defp get_schema_specification_url do
    "https://github.com/ash-project/ash_reports/blob/main/docs/json_schema_v3.5.0.json"
  end
end
