defmodule AshReports.RenderConfig do
  @moduledoc """
  Configuration structure for report rendering operations.

  The RenderConfig defines all configuration options for rendering reports,
  including output format, page layout, styling, and performance options.
  This module provides a type-safe and validated configuration system for
  the Phase 3.1 Renderer Interface.

  ## Configuration Categories

  - **Output Format**: Target format (HTML, PDF, JSON, etc.)
  - **Page Layout**: Page size, margins, orientation
  - **Styling**: Fonts, colors, spacing
  - **Performance**: Streaming, caching, memory limits
  - **Debug**: Debug output, profiling, validation

  ## Usage Examples

  ### Basic Configuration

      config = RenderConfig.new(format: :html)

  ### Complete Configuration

      config = RenderConfig.new([
        format: :pdf,
        page_size: {8.5, 11},
        margins: {1.0, 1.0, 1.0, 1.0},
        orientation: :portrait,
        font_family: "Arial",
        font_size: 12,
        enable_streaming: true,
        debug_mode: false
      ])

  ### Validation

      case RenderConfig.validate(config) do
        {:ok, validated_config} -> proceed_with_rendering(validated_config)
        {:error, errors} -> handle_config_errors(errors)
      end

  """

  @type format :: :html | :pdf | :json | :csv | :heex | :xml
  @type units :: :inches | :cm | :mm | :points
  @type orientation :: :portrait | :landscape
  @type page_size :: {number(), number()} | :letter | :a4 | :legal | :tabloid

  @type t :: %__MODULE__{
          # Output format
          format: format(),

          # Page layout
          page_size: page_size(),
          margins: {number(), number(), number(), number()},
          orientation: orientation(),
          units: units(),

          # Typography
          font_family: String.t(),
          font_size: number(),
          line_height: number(),

          # Colors and styling
          default_text_color: String.t(),
          default_background_color: String.t(),
          border_color: String.t(),
          grid_color: String.t(),

          # Performance
          enable_streaming: boolean(),
          enable_caching: boolean(),
          chunk_size: pos_integer(),
          memory_limit_mb: pos_integer(),

          # Debug and validation
          debug_mode: boolean(),
          validate_layout: boolean(),
          include_metadata: boolean(),
          profiling_enabled: boolean(),

          # Format-specific options
          html_options: map(),
          pdf_options: map(),
          json_options: map(),

          # Internal
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    # Output format
    format: :html,

    # Page layout
    page_size: {8.5, 11},
    margins: {0.5, 0.5, 0.5, 0.5},
    orientation: :portrait,
    units: :inches,

    # Typography
    font_family: "Arial",
    font_size: 12,
    line_height: 1.2,

    # Colors and styling
    default_text_color: "#000000",
    default_background_color: "#FFFFFF",
    border_color: "#000000",
    grid_color: "#CCCCCC",

    # Performance
    enable_streaming: false,
    enable_caching: true,
    chunk_size: 1000,
    memory_limit_mb: 256,

    # Debug and validation
    debug_mode: false,
    validate_layout: true,
    include_metadata: false,
    profiling_enabled: false,

    # Format-specific options
    html_options: %{},
    pdf_options: %{},
    json_options: %{},

    # Internal
    created_at: nil,
    updated_at: nil
  ]

  @doc """
  Creates a new RenderConfig with the given options.

  ## Examples

      config = RenderConfig.new()
      config = RenderConfig.new(format: :pdf, debug_mode: true)

  """
  @spec new(Keyword.t()) :: t()
  def new(options \\ []) do
    now = DateTime.utc_now()

    options
    |> Enum.into(%{})
    |> Map.put(:created_at, now)
    |> Map.put(:updated_at, now)
    |> then(&struct(__MODULE__, &1))
  end

  @doc """
  Validates a RenderConfig for correctness and completeness.

  ## Examples

      case RenderConfig.validate(config) do
        {:ok, config} -> proceed_with_rendering(config)
        {:error, errors} -> handle_validation_errors(errors)
      end

  """
  @spec validate(t()) :: {:ok, t()} | {:error, [map()]}
  def validate(%__MODULE__{} = config) do
    errors =
      []
      |> validate_format(config)
      |> validate_page_layout(config)
      |> validate_typography(config)
      |> validate_colors(config)
      |> validate_performance(config)

    if errors == [] do
      {:ok, config}
    else
      {:error, errors}
    end
  end

  @doc """
  Updates a RenderConfig with new options.

  ## Examples

      updated_config = RenderConfig.update(config, format: :pdf, debug_mode: true)

  """
  @spec update(t(), Keyword.t()) :: t()
  def update(%__MODULE__{} = config, options) do
    options
    |> Enum.into(%{})
    |> Map.put(:updated_at, DateTime.utc_now())
    |> then(&struct(config, &1))
  end

  @doc """
  Gets the page dimensions in the specified units.

  ## Examples

      {width, height} = RenderConfig.get_page_dimensions(config)

  """
  @spec get_page_dimensions(t()) :: {number(), number()}
  def get_page_dimensions(%__MODULE__{} = config) do
    case config.page_size do
      {width, height} -> {width, height}
      :letter -> {8.5, 11}
      :a4 -> {8.27, 11.69}
      :legal -> {8.5, 14}
      :tabloid -> {11, 17}
    end
  end

  @doc """
  Gets the content area dimensions after accounting for margins.

  ## Examples

      {content_width, content_height} = RenderConfig.get_content_dimensions(config)

  """
  @spec get_content_dimensions(t()) :: {number(), number()}
  def get_content_dimensions(%__MODULE__{} = config) do
    {page_width, page_height} = get_page_dimensions(config)
    {left_margin, top_margin, right_margin, bottom_margin} = config.margins

    content_width = page_width - left_margin - right_margin
    content_height = page_height - top_margin - bottom_margin

    {content_width, content_height}
  end

  @doc """
  Checks if the configuration supports streaming output.

  ## Examples

      if RenderConfig.supports_streaming?(config) do
        use_streaming_renderer(config)
      end

  """
  @spec supports_streaming?(t()) :: boolean()
  def supports_streaming?(%__MODULE__{format: format, enable_streaming: streaming}) do
    streaming and format_supports_streaming?(format)
  end

  @doc """
  Gets format-specific options for the configured format.

  ## Examples

      pdf_opts = RenderConfig.get_format_options(config)

  """
  @spec get_format_options(t()) :: map()
  def get_format_options(%__MODULE__{format: :html, html_options: options}), do: options
  def get_format_options(%__MODULE__{format: :pdf, pdf_options: options}), do: options
  def get_format_options(%__MODULE__{format: :json, json_options: options}), do: options
  def get_format_options(%__MODULE__{}), do: %{}

  @doc """
  Creates a configuration optimized for large datasets.

  ## Examples

      config = RenderConfig.for_large_dataset(format: :html)

  """
  @spec for_large_dataset(Keyword.t()) :: t()
  def for_large_dataset(options \\ []) do
    large_dataset_defaults = [
      enable_streaming: true,
      chunk_size: 500,
      memory_limit_mb: 128,
      validate_layout: false,
      include_metadata: false
    ]

    combined_options = Keyword.merge(large_dataset_defaults, options)
    new(combined_options)
  end

  @doc """
  Creates a configuration optimized for debugging.

  ## Examples

      config = RenderConfig.for_debugging(format: :html)

  """
  @spec for_debugging(Keyword.t()) :: t()
  def for_debugging(options \\ []) do
    debug_defaults = [
      debug_mode: true,
      validate_layout: true,
      include_metadata: true,
      profiling_enabled: true,
      enable_caching: false
    ]

    combined_options = Keyword.merge(debug_defaults, options)
    new(combined_options)
  end

  @doc """
  Creates a production-optimized configuration.

  ## Examples

      config = RenderConfig.for_production(format: :pdf)

  """
  @spec for_production(Keyword.t()) :: t()
  def for_production(options \\ []) do
    production_defaults = [
      enable_caching: true,
      debug_mode: false,
      validate_layout: false,
      include_metadata: false,
      profiling_enabled: false,
      memory_limit_mb: 512
    ]

    combined_options = Keyword.merge(production_defaults, options)
    new(combined_options)
  end

  # Private validation functions

  defp validate_format(errors, %{format: format}) do
    valid_formats = [:html, :pdf, :json, :csv, :heex, :xml]

    if format in valid_formats do
      errors
    else
      error = %{
        type: :invalid_format,
        message: "Format must be one of: #{inspect(valid_formats)}",
        value: format
      }

      [error | errors]
    end
  end

  defp validate_page_layout(errors, config) do
    errors
    |> validate_page_size(config)
    |> validate_margins(config)
    |> validate_orientation(config)
  end

  defp validate_page_size(errors, %{page_size: {width, height}})
       when is_number(width) and is_number(height) and width > 0 and height > 0 do
    errors
  end

  defp validate_page_size(errors, %{page_size: size})
       when size in [:letter, :a4, :legal, :tabloid] do
    errors
  end

  defp validate_page_size(errors, %{page_size: size}) do
    error = %{
      type: :invalid_page_size,
      message: "Page size must be {width, height} or :letter, :a4, :legal, :tabloid",
      value: size
    }

    [error | errors]
  end

  defp validate_margins(errors, %{margins: {top, right, bottom, left}})
       when is_number(top) and is_number(right) and is_number(bottom) and is_number(left) and
              top >= 0 and right >= 0 and bottom >= 0 and left >= 0 do
    errors
  end

  defp validate_margins(errors, %{margins: margins}) do
    error = %{
      type: :invalid_margins,
      message: "Margins must be {top, right, bottom, left} with non-negative numbers",
      value: margins
    }

    [error | errors]
  end

  defp validate_orientation(errors, %{orientation: orientation})
       when orientation in [:portrait, :landscape] do
    errors
  end

  defp validate_orientation(errors, %{orientation: orientation}) do
    error = %{
      type: :invalid_orientation,
      message: "Orientation must be :portrait or :landscape",
      value: orientation
    }

    [error | errors]
  end

  defp validate_typography(errors, config) do
    errors
    |> validate_font_family(config)
    |> validate_font_size(config)
    |> validate_line_height(config)
  end

  defp validate_font_family(errors, %{font_family: family})
       when is_binary(family) and family != "" do
    errors
  end

  defp validate_font_family(errors, %{font_family: family}) do
    error = %{
      type: :invalid_font_family,
      message: "Font family must be a non-empty string",
      value: family
    }

    [error | errors]
  end

  defp validate_font_size(errors, %{font_size: size}) when is_number(size) and size > 0 do
    errors
  end

  defp validate_font_size(errors, %{font_size: size}) do
    error = %{
      type: :invalid_font_size,
      message: "Font size must be a positive number",
      value: size
    }

    [error | errors]
  end

  defp validate_line_height(errors, %{line_height: height})
       when is_number(height) and height > 0 do
    errors
  end

  defp validate_line_height(errors, %{line_height: height}) do
    error = %{
      type: :invalid_line_height,
      message: "Line height must be a positive number",
      value: height
    }

    [error | errors]
  end

  defp validate_colors(errors, config) do
    errors
    |> validate_color(:default_text_color, config.default_text_color)
    |> validate_color(:default_background_color, config.default_background_color)
    |> validate_color(:border_color, config.border_color)
    |> validate_color(:grid_color, config.grid_color)
  end

  defp validate_color(errors, _field, color) when is_binary(color) do
    # Basic color validation - could be enhanced with regex for hex codes
    if String.starts_with?(color, "#") and String.length(color) in [4, 7] do
      errors
    else
      error = %{
        type: :invalid_color,
        message: "Color must be a valid hex color (e.g., #000000 or #000)",
        value: color
      }

      [error | errors]
    end
  end

  defp validate_color(errors, field, color) do
    error = %{
      type: :invalid_color_type,
      message: "Color must be a string",
      field: field,
      value: color
    }

    [error | errors]
  end

  defp validate_performance(errors, config) do
    errors
    |> validate_chunk_size(config)
    |> validate_memory_limit(config)
  end

  defp validate_chunk_size(errors, %{chunk_size: size}) when is_integer(size) and size > 0 do
    errors
  end

  defp validate_chunk_size(errors, %{chunk_size: size}) do
    error = %{
      type: :invalid_chunk_size,
      message: "Chunk size must be a positive integer",
      value: size
    }

    [error | errors]
  end

  defp validate_memory_limit(errors, %{memory_limit_mb: limit})
       when is_integer(limit) and limit > 0 do
    errors
  end

  defp validate_memory_limit(errors, %{memory_limit_mb: limit}) do
    error = %{
      type: :invalid_memory_limit,
      message: "Memory limit must be a positive integer (MB)",
      value: limit
    }

    [error | errors]
  end

  defp format_supports_streaming?(:html), do: true
  defp format_supports_streaming?(:json), do: true
  defp format_supports_streaming?(:csv), do: true
  defp format_supports_streaming?(:xml), do: true
  defp format_supports_streaming?(_format), do: false
end
