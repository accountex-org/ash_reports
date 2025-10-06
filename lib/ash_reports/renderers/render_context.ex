defmodule AshReports.RenderContext do
  @moduledoc """
  Immutable context structure for managing render state and data transformation.

  The RenderContext serves as the central data structure for the Phase 3.1 Renderer
  Interface, providing a comprehensive context for rendering operations that includes
  report metadata, processed data, variable values, layout information, and
  rendering configuration.

  ## Key Features

  - **Immutable State**: All context operations return new context instances
  - **Data Integration**: Seamless integration with Phase 2 DataLoader results
  - **Layout Management**: Support for band-based layout calculations
  - **Variable Resolution**: Access to resolved variable values from VariableState
  - **Error Context**: Comprehensive error tracking and recovery
  - **Type Safety**: Strict type definitions for reliable rendering

  ## Context Structure

  The RenderContext contains:

  - **Report Definition**: The report struct with bands, elements, and metadata
  - **Processed Data**: Records from DataLoader with group and variable processing
  - **Internationalization**: Locale information, text direction, and formatting metadata
  - **Layout State**: Current layout calculations and positioning information
  - **Render Configuration**: Output format, styling, and rendering options
  - **Variable Values**: Resolved variable values from Phase 2 processing
  - **Group State**: Current group processing state and break information
  - **Error State**: Any errors encountered during rendering

  ## Usage Patterns

  ### Basic Context Creation

      context = RenderContext.new(report, data_result)

  ### With Custom Configuration

      config = %RenderConfig{
        format: :html,
        page_size: {8.5, 11},
        margins: {0.5, 0.5, 0.5, 0.5}
      }

      context = RenderContext.new(report, data_result, config)

  ### Context Transformation

      context
      |> RenderContext.set_current_band(band)
      |> RenderContext.add_layout_info(layout_data)
      |> RenderContext.update_variable_context(new_values)

  ### Locale Management

      # Create context with specific locale
      config = %{locale: "fr", format: :html}
      context = RenderContext.new(report, data_result, config)

      # Change locale during rendering
      context = RenderContext.set_locale(context, "de")

      # Get locale information
      locale = RenderContext.get_locale(context)
      direction = RenderContext.get_text_direction(context)
      is_rtl = RenderContext.rtl?(context)

  ### Error Handling

      case RenderContext.validate(context) do
        {:ok, validated_context} -> proceed_with_rendering(validated_context)
        {:error, validation_errors} -> handle_errors(validation_errors)
      end

  ## Integration with Phase 2

  RenderContext seamlessly integrates with DataLoader results:

      {:ok, data_result} = DataLoader.load_report(domain, :sales_report, params)
      context = RenderContext.from_data_result(report, data_result)

  """

  alias AshReports.{Band, Cldr, Element, Group, Report}

  @type t :: %__MODULE__{
          # Core context
          report: Report.t(),
          data_result: map(),
          config: RenderConfig.t(),

          # Processing state
          current_record: map() | nil,
          current_record_index: non_neg_integer(),
          current_band: Band.t() | nil,
          current_group: Group.t() | nil,

          # Data context
          records: [map()],
          variables: %{atom() => term()},
          groups: %{term() => map()},
          metadata: map(),

          # Internationalization context
          locale: String.t(),
          text_direction: String.t(),
          locale_metadata: map(),

          # Layout context
          layout_state: map(),
          current_position: %{x: number(), y: number()},
          page_dimensions: %{width: number(), height: number()},

          # Rendering state
          rendered_elements: [map()],
          pending_elements: [Element.t()],

          # Error tracking
          errors: [map()],
          warnings: [map()],

          # Internal state
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    # Core context
    report: nil,
    data_result: %{},
    config: %{},

    # Processing state
    current_record: nil,
    current_record_index: 0,
    current_band: nil,
    current_group: nil,

    # Data context
    records: [],
    variables: %{},
    groups: %{},
    metadata: %{},

    # Internationalization context
    locale: "en",
    text_direction: "ltr",
    locale_metadata: %{},

    # Layout context
    layout_state: %{},
    current_position: %{x: 0, y: 0},
    page_dimensions: %{width: 8.5, height: 11},

    # Rendering state
    rendered_elements: [],
    pending_elements: [],

    # Error tracking
    errors: [],
    warnings: [],

    # Internal state
    created_at: nil,
    updated_at: nil
  ]

  @doc """
  Creates a new RenderContext from a report and data result.

  ## Examples

      context = RenderContext.new(report, data_result)
      context = RenderContext.new(report, data_result, config)

  """
  @spec new(Report.t(), map(), map()) :: t()
  def new(report, data_result, config \\ %{}) do
    now = DateTime.utc_now()
    locale = determine_locale(config, data_result)

    %__MODULE__{
      report: report,
      data_result: data_result,
      config: merge_default_config(config),
      records: Map.get(data_result, :records, []),
      variables: Map.get(data_result, :variables, %{}),
      groups: Map.get(data_result, :groups, %{}),
      metadata: Map.get(data_result, :metadata, %{}),
      locale: locale,
      text_direction: Cldr.text_direction(locale),
      locale_metadata: build_locale_metadata(locale),
      layout_state: initialize_layout_state(report, config),
      page_dimensions: get_page_dimensions(config),
      created_at: now,
      updated_at: now
    }
  end

  @doc """
  Creates a RenderContext from a DataLoader result.

  Convenience function for creating context from Phase 2 DataLoader output.

  ## Examples

      {:ok, data_result} = DataLoader.load_report(domain, :report_name, params)
      context = RenderContext.from_data_result(report, data_result)

  """
  @spec from_data_result(Report.t(), map(), map()) :: t()
  def from_data_result(report, data_result, config \\ %{}) do
    new(report, data_result, config)
  end

  @doc """
  Validates the context for rendering operations.

  Checks that all required data is present and valid for rendering.

  ## Examples

      case RenderContext.validate(context) do
        {:ok, context} -> proceed_with_rendering(context)
        {:error, errors} -> handle_validation_errors(errors)
      end

  """
  @spec validate(t()) :: {:ok, t()} | {:error, [map()]}
  def validate(%__MODULE__{} = context) do
    errors =
      []
      |> validate_report(context)
      |> validate_data(context)
      |> validate_config(context)

    if errors == [] do
      {:ok, context}
    else
      {:error, errors}
    end
  end

  @doc """
  Sets the current record being processed.

  ## Examples

      context = RenderContext.set_current_record(context, record, index)

  """
  @spec set_current_record(t(), map(), non_neg_integer()) :: t()
  def set_current_record(%__MODULE__{} = context, record, index) do
    %{
      context
      | current_record: record,
        current_record_index: index,
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Sets the current band being rendered.

  ## Examples

      context = RenderContext.set_current_band(context, band)

  """
  @spec set_current_band(t(), Band.t()) :: t()
  def set_current_band(%__MODULE__{} = context, band) do
    %{
      context
      | current_band: band,
        pending_elements: band.elements || [],
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Sets the current group being processed.

  ## Examples

      context = RenderContext.set_current_group(context, group)

  """
  @spec set_current_group(t(), Group.t()) :: t()
  def set_current_group(%__MODULE__{} = context, group) do
    %{context | current_group: group, updated_at: DateTime.utc_now()}
  end

  @doc """
  Updates the layout state with new layout information.

  ## Examples

      layout_info = %{band_height: 50, element_positions: positions}
      context = RenderContext.update_layout_state(context, layout_info)

  """
  @spec update_layout_state(t(), map()) :: t()
  def update_layout_state(%__MODULE__{} = context, layout_info) do
    new_layout_state = Map.merge(context.layout_state, layout_info)
    %{context | layout_state: new_layout_state, updated_at: DateTime.utc_now()}
  end

  @doc """
  Updates the current rendering position.

  ## Examples

      context = RenderContext.update_position(context, %{x: 100, y: 200})

  """
  @spec update_position(t(), %{x: number(), y: number()}) :: t()
  def update_position(%__MODULE__{} = context, position) do
    %{context | current_position: position, updated_at: DateTime.utc_now()}
  end

  @doc """
  Adds a rendered element to the context.

  ## Examples

      rendered_element = %{type: :label, content: "Total", position: {100, 50}}
      context = RenderContext.add_rendered_element(context, rendered_element)

  """
  @spec add_rendered_element(t(), map()) :: t()
  def add_rendered_element(%__MODULE__{} = context, rendered_element) do
    %{
      context
      | rendered_elements: [rendered_element | context.rendered_elements],
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Removes an element from the pending elements list.

  ## Examples

      context = RenderContext.remove_pending_element(context, element)

  """
  @spec remove_pending_element(t(), Element.t()) :: t()
  def remove_pending_element(%__MODULE__{} = context, element) do
    new_pending = List.delete(context.pending_elements, element)
    %{context | pending_elements: new_pending, updated_at: DateTime.utc_now()}
  end

  @doc """
  Adds an error to the context.

  ## Examples

      error = %{type: :layout_error, message: "Element overflow", element: element}
      context = RenderContext.add_error(context, error)

  """
  @spec add_error(t(), map()) :: t()
  def add_error(%__MODULE__{} = context, error) do
    error_with_timestamp = Map.put(error, :timestamp, DateTime.utc_now())
    %{context | errors: [error_with_timestamp | context.errors], updated_at: DateTime.utc_now()}
  end

  @doc """
  Adds a warning to the context.

  ## Examples

      warning = %{type: :performance_warning, message: "Large dataset detected"}
      context = RenderContext.add_warning(context, warning)

  """
  @spec add_warning(t(), map()) :: t()
  def add_warning(%__MODULE__{} = context, warning) do
    warning_with_timestamp = Map.put(warning, :timestamp, DateTime.utc_now())

    %{
      context
      | warnings: [warning_with_timestamp | context.warnings],
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Gets a variable value from the context.

  ## Examples

      total = RenderContext.get_variable(context, :total_amount)
      count = RenderContext.get_variable(context, :record_count, 0)

  """
  @spec get_variable(t(), atom(), term()) :: term()
  def get_variable(%__MODULE__{} = context, variable_name, default \\ nil) do
    Map.get(context.variables, variable_name, default)
  end

  @doc """
  Gets the current record or a field from the current record.

  ## Examples

      record = RenderContext.get_current_record(context)
      name = RenderContext.get_current_record(context, :customer_name)

  """
  @spec get_current_record(t(), atom() | nil, term()) :: term()
  def get_current_record(%__MODULE__{} = context, field \\ nil, default \\ nil) do
    get_current_record_impl(context, field, default)
  end

  defp get_current_record_impl(%__MODULE__{current_record: record}, nil, _default) do
    record
  end

  defp get_current_record_impl(%__MODULE__{current_record: nil}, _field, default) do
    default
  end

  defp get_current_record_impl(%__MODULE__{current_record: record}, field, default) do
    case record do
      nil -> default
      # Handle case where current_record is set to empty list
      [] -> default
      record when is_map(record) -> Map.get(record, field, default)
      _ -> default
    end
  end

  @doc """
  Checks if there are more records to process.

  ## Examples

      if RenderContext.has_more_records?(context) do
        process_next_record(context)
      end

  """
  @spec has_more_records?(t()) :: boolean()
  def has_more_records?(%__MODULE__{} = context) do
    context.current_record_index < length(context.records) - 1
  end

  @doc """
  Gets the next record in the sequence.

  ## Examples

      case RenderContext.get_next_record(context) do
        {:ok, next_record, new_context} -> process_record(next_record, new_context)
        {:error, :no_more_records} -> finish_rendering()
      end

  """
  @spec get_next_record(t()) :: {:ok, map(), t()} | {:error, :no_more_records}
  def get_next_record(%__MODULE__{} = context) do
    next_index = context.current_record_index + 1

    if next_index < length(context.records) do
      next_record = Enum.at(context.records, next_index)
      new_context = set_current_record(context, next_record, next_index)
      {:ok, next_record, new_context}
    else
      {:error, :no_more_records}
    end
  end

  @doc """
  Resets the context for a new rendering pass.

  ## Examples

      fresh_context = RenderContext.reset_for_new_pass(context)

  """
  @spec reset_for_new_pass(t()) :: t()
  def reset_for_new_pass(%__MODULE__{} = context) do
    %{
      context
      | current_record: nil,
        current_record_index: 0,
        current_band: nil,
        current_position: %{x: 0, y: 0},
        rendered_elements: [],
        pending_elements: [],
        updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Sets the locale for the context and updates related locale metadata.

  ## Examples

      context = RenderContext.set_locale(context, "fr")

  """
  @spec set_locale(t(), String.t()) :: t()
  def set_locale(%__MODULE__{} = context, locale) do
    if Cldr.locale_supported?(locale) do
      %{
        context
        | locale: locale,
          text_direction: Cldr.text_direction(locale),
          locale_metadata: build_locale_metadata(locale),
          updated_at: DateTime.utc_now()
      }
    else
      add_warning(context, %{
        type: :unsupported_locale,
        message: "Locale '#{locale}' is not supported, keeping current locale '#{context.locale}'"
      })
    end
  end

  @doc """
  Gets the current locale for the context.

  ## Examples

      locale = RenderContext.get_locale(context)

  """
  @spec get_locale(t()) :: String.t()
  def get_locale(%__MODULE__{locale: locale}), do: locale

  @doc """
  Gets the text direction for the current locale.

  ## Examples

      direction = RenderContext.get_text_direction(context)
      # => "ltr" or "rtl"

  """
  @spec get_text_direction(t()) :: String.t()
  def get_text_direction(%__MODULE__{text_direction: direction}), do: direction

  @doc """
  Gets locale-specific metadata for formatting.

  ## Examples

      metadata = RenderContext.get_locale_metadata(context)
      # => %{decimal_separator: ".", thousands_separator: ",", ...}

  """
  @spec get_locale_metadata(t()) :: map()
  def get_locale_metadata(%__MODULE__{locale_metadata: metadata}), do: metadata

  @doc """
  Updates the locale metadata in the context.

  ## Examples

      metadata = %{custom_format: "yyyy-MM-dd"}
      context = RenderContext.update_locale_metadata(context, metadata)

  """
  @spec update_locale_metadata(t(), map()) :: t()
  def update_locale_metadata(%__MODULE__{} = context, new_metadata) do
    merged_metadata = Map.merge(context.locale_metadata, new_metadata)
    %{context | locale_metadata: merged_metadata, updated_at: DateTime.utc_now()}
  end

  @doc """
  Determines if the context uses a right-to-left locale.

  ## Examples

      RenderContext.rtl?(context)
      # => true or false

  """
  @spec rtl?(t()) :: boolean()
  def rtl?(%__MODULE__{text_direction: "rtl"}), do: true
  def rtl?(%__MODULE__{}), do: false

  @doc """
  Gets CSS classes appropriate for the current locale.

  ## Examples

      classes = RenderContext.locale_css_classes(context)
      # => ["dir-ltr", "locale-en"]

  """
  @spec locale_css_classes(t()) :: [String.t()]
  def locale_css_classes(%__MODULE__{} = context) do
    [
      "dir-#{context.text_direction}",
      "locale-#{String.replace(context.locale, "-", "_")}"
    ]
  end

  # Private helper functions

  defp merge_default_config(config) do
    defaults = %{
      format: :html,
      page_size: {8.5, 11},
      margins: {0.5, 0.5, 0.5, 0.5},
      units: :inches,
      orientation: :portrait
    }

    Map.merge(defaults, config)
  end

  defp initialize_layout_state(report, config) do
    %{
      bands: initialize_band_layout(report.bands),
      page_breaks: [],
      current_page: 1,
      total_height: 0,
      config: config
    }
  end

  defp initialize_band_layout(bands) when is_list(bands) do
    Enum.into(bands, %{}, fn band ->
      {band.name,
       %{
         height: band.height || 0,
         position: %{x: 0, y: 0},
         elements: [],
         rendered: false
       }}
    end)
  end

  defp initialize_band_layout(_), do: %{}

  defp get_page_dimensions(config) do
    case Map.get(config, :page_size, {8.5, 11}) do
      {width, height} -> %{width: width, height: height}
      %{width: width, height: height} -> %{width: width, height: height}
      _ -> %{width: 8.5, height: 11}
    end
  end

  defp validate_report(errors, %{report: nil}) do
    [%{type: :missing_report, message: "Report is required"} | errors]
  end

  defp validate_report(errors, %{report: %Report{}}), do: errors

  defp validate_report(errors, _context) do
    [%{type: :invalid_report, message: "Report must be a Report struct"} | errors]
  end

  defp validate_data(errors, %{data_result: data}) when map_size(data) == 0 do
    [%{type: :empty_data, message: "Data result is empty"} | errors]
  end

  defp validate_data(errors, %{records: []}) do
    [%{type: :no_records, message: "No records to render"} | errors]
  end

  defp validate_data(errors, _context), do: errors

  defp validate_config(errors, %{config: config}) when map_size(config) == 0 do
    [%{type: :missing_config, message: "Render configuration is required"} | errors]
  end

  defp validate_config(errors, _context), do: errors

  # Locale-related helper functions

  @spec determine_locale(map(), map()) :: String.t()
  defp determine_locale(config, data_result) do
    # Priority order for locale determination:
    # 1. Explicit locale in config
    # 2. Locale from data_result metadata
    # 3. Current process locale
    # 4. Application default
    # 5. System default

    sources = %{
      locale: Map.get(config, :locale),
      data_locale: get_in(data_result, [:metadata, :locale]),
      process_locale: Process.get(:ash_reports_locale),
      accept_language: Map.get(config, :accept_language)
    }

    case Cldr.detect_locale(sources) do
      {:ok, locale} -> locale
      _error -> Cldr.default_locale() |> to_string()
    end
  end

  @spec build_locale_metadata(String.t()) :: map()
  defp build_locale_metadata(locale) do
    %{
      decimal_separator: Cldr.decimal_separator(locale),
      thousands_separator: Cldr.thousands_separator(locale),
      text_direction: Cldr.text_direction(locale),
      locale_name: locale,
      supported: Cldr.locale_supported?(locale)
    }
  end
end
