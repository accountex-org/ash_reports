defmodule AshReports.JsonRenderer.StructureBuilder do
  @moduledoc """
  Structure Builder for AshReports JSON Renderer.

  The StructureBuilder provides JSON assembly for report data output.
  It returns either flat records or hierarchical grouped structures depending
  on report configuration.

  ## Flat Output (No Grouping)

  When the report has no grouping, returns a simple flat array:

  ```json
  {
    "records": [
      {"customer": "ABC Corp", "region": "North", "amount": 100.00},
      {"customer": "XYZ Ltd", "region": "North", "amount": 200.00},
      {"customer": "DEF Inc", "region": "South", "amount": 150.00}
    ]
  }
  ```

  ## Hierarchical Output (With Grouping)

  When the report has grouping, returns nested structure with aggregates:

  ```json
  {
    "records": [
      {
        "group_value": "North",
        "group_level": 1,
        "aggregates": {"count": 2, "amount_sum": 300.00},
        "records": [
          {"customer": "ABC Corp", "amount": 100.00},
          {"customer": "XYZ Ltd", "amount": 200.00}
        ]
      },
      {
        "group_value": "South",
        "group_level": 1,
        "aggregates": {"count": 1, "amount_sum": 150.00},
        "records": [
          {"customer": "DEF Inc", "amount": 150.00}
        ]
      }
    ]
  }
  ```

  ## Multi-Level Grouping

  Supports nested grouping with multiple levels:

  ```json
  {
    "records": [
      {
        "group_value": "North",
        "group_level": 1,
        "aggregates": {"count": 3, "amount_sum": 600.00},
        "records": [
          {
            "group_value": "Electronics",
            "group_level": 2,
            "aggregates": {"count": 2, "amount_sum": 300.00},
            "records": [...]
          }
        ]
      }
    ]
  }
  ```

  ## Usage

      # Build JSON structure (returns records only)
      {:ok, json_structure} = StructureBuilder.build_report_structure(context, serialized_data)

  """

  alias AshReports.{JsonRenderer.DataSerializer, JsonRenderer.SchemaManager, RenderContext}

  @type build_options :: [
          include_navigation: boolean(),
          include_positions: boolean(),
          include_metadata: boolean(),
          group_by_bands: boolean()
        ]

  @type structure_result :: {:ok, map()} | {:error, term()}

  @doc """
  Builds a complete report JSON structure from context and serialized data.

  For JSON output, this returns records in either flat or hierarchical grouped structure.

  ## Examples

      {:ok, json_structure} = StructureBuilder.build_report_structure(context, serialized_data)

  """
  @spec build_report_structure(RenderContext.t(), map(), build_options()) :: structure_result()
  def build_report_structure(%RenderContext{} = context, serialized_data, _opts \\ []) do
    records = Map.get(serialized_data, :records, [])

    # Check if report has grouping configured
    if has_grouping?(context) do
      # Build hierarchical grouped structure
      grouped_records = build_grouped_structure(context, records)
      {:ok, %{"records" => grouped_records}}
    else
      # Return flat records
      {:ok, %{"records" => records}}
    end
  end

  @doc """
  Builds grouped structure from raw (unserialized) records.

  This function groups records BEFORE serialization, preserving relationship
  data needed for grouping by relationship fields.

  Returns {:ok, %{grouped: true, groups: grouped_records}} for grouped data
  or {:ok, %{grouped: false, records: records}} for ungrouped data.
  """
  @spec build_grouped_raw_records(RenderContext.t(), [map()]) :: {:ok, map()} | {:error, term()}
  def build_grouped_raw_records(%RenderContext{} = context, records) do
    try do
      groups = get_report_groups(context)
      sorted_groups = Enum.sort_by(groups, & &1.level)

      case sorted_groups do
        [] ->
          {:ok, %{grouped: false, records: records}}

        [first_group | _rest] ->
          grouped_records = build_raw_groups_at_level(records, sorted_groups, first_group.level, context)
          {:ok, %{grouped: true, groups: grouped_records}}
      end
    rescue
      error -> {:error, {:grouping_failed, error}}
    end
  end

  @doc """
  Checks if the report has grouping configured.
  """
  def has_grouping?(%RenderContext{} = context) do
    report_groups = get_report_groups(context)
    length(report_groups) > 0
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
  Builds the data section with records, variables, and groups.

  ## Examples

      {:ok, data_section} = StructureBuilder.build_data_section(context, serialized_data)

  """
  @spec build_data_section(RenderContext.t(), map(), build_options()) :: structure_result()
  def build_data_section(%RenderContext{} = _context, serialized_data, opts \\ []) do
    with {:ok, variables_section} <- build_variables_section(serialized_data, opts),
         {:ok, groups_section} <- build_groups_section(serialized_data, opts) do
      # Output only the actual data: records, variables, and groups
      # Do NOT include report structure (bands, elements, etc.)
      data_section = %{
        records: Map.get(serialized_data, :records, [])
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
  #
  # Note: build_bands_structure/3 was removed as part of JSON renderer simplification.
  # The function built detailed band/element structures but is no longer needed since
  # the JSON renderer now outputs only records. Can be restored from git history if needed.

  defp build_variables_section(serialized_data, _opts) do
    variables = Map.get(serialized_data, :variables, %{})
    {:ok, variables}
  end

  defp build_groups_section(serialized_data, _opts) do
    groups = Map.get(serialized_data, :groups, %{})
    {:ok, groups}
  end

  defp build_report_metadata(%RenderContext{} = context, opts) do
    # Serialize variables and groups to ensure JSON compatibility
    {:ok, serialized_variables} = DataSerializer.serialize_variables(context.variables)
    {:ok, serialized_groups} = DataSerializer.serialize_groups(context.groups)

    base_metadata = %{
      record_count: length(context.records),
      processing_time_ms: get_processing_time(context),
      variables: serialized_variables,
      groups: serialized_groups
    }

    if Keyword.get(opts, :include_metadata, true) do
      Map.merge(base_metadata, %{
        error_count: length(context.errors),
        warning_count: length(context.warnings),
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

  # Note: get_band_elements/3 was removed (unused after JSON renderer simplification)

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

  # Note: count_bands/1 was removed (unused after JSON renderer simplification)

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

  # Grouping support functions

  defp get_report_groups(%RenderContext{report: %{groups: groups}}) when is_list(groups),
    do: groups

  defp get_report_groups(_), do: []

  defp build_grouped_structure(%RenderContext{} = context, records) do
    groups = get_report_groups(context)
    sorted_groups = Enum.sort_by(groups, & &1.level)

    # Build hierarchical structure starting from level 1
    case sorted_groups do
      [] ->
        records

      [first_group | _rest] ->
        build_groups_at_level(records, sorted_groups, first_group.level, context)
    end
  end

  # Build groups from raw (unserialized) records
  defp build_raw_groups_at_level(records, groups, current_level, context) do
    # Validate that records is a list
    unless is_list(records) do
      raise "build_raw_groups_at_level expects a list of records, got: #{inspect(records.__struct__)}"
    end

    # Find the group configuration for this level
    group_config = Enum.find(groups, fn g -> g.level == current_level end)

    if group_config do
      # Group records by the group field
      grouped_records = group_records_by_field(records, group_config)

      # Build group structures (with atom keys for raw data)
      Enum.map(grouped_records, fn {group_value, group_records} ->
        # Calculate aggregates for this group
        aggregates = calculate_group_aggregates(group_records, context)

        # Check if there are more levels to nest
        next_level = current_level + 1
        next_group = Enum.find(groups, fn g -> g.level == next_level end)

        nested_records =
          if next_group do
            # Recursively build nested groups
            build_raw_groups_at_level(group_records, groups, next_level, context)
          else
            # No more nesting - return detail records (raw, unserialized)
            group_records
          end

        %{
          group_value: group_value,
          group_level: current_level,
          aggregates: aggregates,
          records: nested_records
        }
      end)
    else
      records
    end
  end

  # Build groups from serialized records (legacy path)
  defp build_groups_at_level(records, groups, current_level, context) do
    # Find the group configuration for this level
    group_config = Enum.find(groups, fn g -> g.level == current_level end)

    if group_config do
      # Group records by the group field
      grouped_records = group_records_by_field(records, group_config)

      # Build group structures
      Enum.map(grouped_records, fn {group_value, group_records} ->
        # Calculate aggregates for this group
        aggregates = calculate_group_aggregates(group_records, context)

        # Check if there are more levels to nest
        next_level = current_level + 1
        next_group = Enum.find(groups, fn g -> g.level == next_level end)

        nested_records =
          if next_group do
            # Recursively build nested groups
            build_groups_at_level(group_records, groups, next_level, context)
          else
            # No more nesting - return detail records
            group_records
          end

        %{
          "group_value" => group_value,
          "group_level" => current_level,
          "aggregates" => aggregates,
          "records" => nested_records
        }
      end)
    else
      records
    end
  end

  defp group_records_by_field(records, group_config) do
    # Validate input
    unless is_list(records) do
      raise "group_records_by_field expects a list, got: #{inspect(records.__struct__)}"
    end

    # Get the group field name from the expression
    field_name = extract_field_name_from_expression(group_config.expression)

    # Group records by the field value
    grouped = Enum.group_by(records, fn record ->
      get_field_value(record, field_name)
    end)

    # Sort the groups
    Enum.sort_by(grouped, fn {group_value, _} -> group_value end, group_config.sort || :asc)
  end

  defp extract_field_name_from_expression(expression) when is_atom(expression), do: expression

  defp extract_field_name_from_expression(%{__struct__: Ash.Query.Ref} = expression) do
    # Handle Ash.Query.Ref - return the full expression for later processing
    expression
  end

  defp extract_field_name_from_expression(%{__struct__: _} = expression) do
    # Handle Ash.Expr - try to extract field name
    # This is a simplified approach - may need enhancement
    case expression do
      %{arguments: [field]} when is_atom(field) -> field
      _ -> :unknown
    end
  end

  defp extract_field_name_from_expression(_), do: :unknown

  defp get_field_value(record, %{__struct__: Ash.Query.Ref, relationship_path: relationship_path, attribute: attribute}) do
    # Navigate through relationship path to get the value
    navigate_relationship_path(record, relationship_path, attribute)
  end

  defp get_field_value(record, field_name) when is_atom(field_name) do
    Map.get(record, field_name) || Map.get(record, to_string(field_name))
  end

  defp get_field_value(record, field_name) when is_binary(field_name) do
    Map.get(record, field_name) || Map.get(record, String.to_atom(field_name))
  end

  defp get_field_value(_, _), do: nil

  defp navigate_relationship_path(record, [], attribute) do
    # No relationship path, just get the attribute
    Map.get(record, attribute) || Map.get(record, to_string(attribute))
  end

  defp navigate_relationship_path(record, [rel | rest], attribute) do
    # Get the relationship data
    rel_data = Map.get(record, rel) || Map.get(record, to_string(rel))

    case rel_data do
      # Has-many relationship - get the first record
      [first | _] when is_map(first) ->
        if rest == [] do
          Map.get(first, attribute) || Map.get(first, to_string(attribute))
        else
          navigate_relationship_path(first, rest, attribute)
        end

      # Belongs-to or has-one relationship
      %{} = related_record ->
        if rest == [] do
          Map.get(related_record, attribute) || Map.get(related_record, to_string(attribute))
        else
          navigate_relationship_path(related_record, rest, attribute)
        end

      _ ->
        nil
    end
  end

  defp calculate_group_aggregates(group_records, context) do
    # Get group-level variables from the report
    group_variables =
      (context.report.variables || [])
      |> Enum.filter(fn var -> var.reset_on == :group end)

    if Enum.empty?(group_variables) do
      # Fallback: auto-calculate aggregates if no group variables defined
      count = length(group_records)
      sums = calculate_numeric_sums(group_records)
      Map.merge(%{"count" => count}, sums)
    else
      # Calculate defined group variables
      group_variables
      |> Enum.map(fn var ->
        value = calculate_variable_value(var, group_records)
        {to_string(var.name), value}
      end)
      |> Enum.into(%{})
    end
  end

  defp calculate_variable_value(%{type: :count}, group_records) do
    length(group_records)
  end

  defp calculate_variable_value(%{type: :sum, expression: expression}, group_records) do
    group_records
    |> Enum.map(fn record -> evaluate_expression(expression, record) end)
    |> Enum.reduce(0, fn
      %Decimal{} = val, %Decimal{} = acc -> Decimal.add(acc, val)
      %Decimal{} = val, acc when is_number(acc) -> Decimal.add(val, Decimal.new(acc))
      val, %Decimal{} = acc when is_number(val) -> Decimal.add(acc, Decimal.new(val))
      val, acc when is_number(val) and is_number(acc) -> val + acc
      _, acc -> acc
    end)
  end

  defp calculate_variable_value(%{type: :average, expression: expression}, group_records) do
    values = Enum.map(group_records, fn record -> evaluate_expression(expression, record) end)
    count = length(values)

    if count == 0 do
      0
    else
      sum =
        Enum.reduce(values, 0, fn
          %Decimal{} = val, %Decimal{} = acc -> Decimal.add(acc, val)
          %Decimal{} = val, acc when is_number(acc) -> Decimal.add(val, Decimal.new(acc))
          val, %Decimal{} = acc when is_number(val) -> Decimal.add(acc, Decimal.new(val))
          val, acc when is_number(val) and is_number(acc) -> val + acc
          _, acc -> acc
        end)

      case sum do
        %Decimal{} -> Decimal.div(sum, Decimal.new(count))
        _ when is_number(sum) -> sum / count
        _ -> 0
      end
    end
  end

  defp calculate_variable_value(_var, _group_records), do: nil

  defp evaluate_expression(expression, record) when is_function(expression) do
    expression.(record)
  end

  defp evaluate_expression(%{__struct__: Ash.Query.Ref, attribute: attribute}, record) do
    # Handle Ash.Query.Ref - get the attribute value from the record
    Map.get(record, attribute, 0)
  end

  defp evaluate_expression(%{__struct__: _} = expression, record) do
    # Handle other Ash.Expr structures - try to extract field name
    case expression do
      %{arguments: [field]} when is_atom(field) ->
        Map.get(record, field, 0)

      %{attribute: attribute} when is_atom(attribute) ->
        Map.get(record, attribute, 0)

      _ ->
        0
    end
  end

  defp evaluate_expression(field, record) when is_atom(field) do
    Map.get(record, field, 0)
  end

  defp evaluate_expression(_, _record), do: 0

  defp calculate_numeric_sums(records) when length(records) == 0, do: %{}

  defp calculate_numeric_sums([first_record | _rest] = records) do
    # Get numeric fields from the first record
    # Convert struct to map first if needed
    first_as_map =
      if is_struct(first_record) do
        Map.from_struct(first_record)
      else
        first_record
      end

    numeric_fields =
      first_as_map
      |> Enum.filter(fn {_key, value} -> is_number(value) || match?(%Decimal{}, value) end)
      |> Enum.map(fn {key, _value} -> key end)

    # Calculate sums for each numeric field
    numeric_fields
    |> Enum.map(fn field ->
      sum =
        records
        |> Enum.map(fn record -> Map.get(record, field, 0) end)
        |> Enum.reduce(0, fn
          %Decimal{} = val, %Decimal{} = acc -> Decimal.add(acc, val)
          %Decimal{} = val, acc when is_number(acc) -> Decimal.add(val, Decimal.new(acc))
          val, %Decimal{} = acc when is_number(val) -> Decimal.add(acc, Decimal.new(val))
          val, acc -> val + acc
        end)

      {"#{field}_sum", sum}
    end)
    |> Enum.into(%{})
  end
end
