defmodule AshReports.Typst.ChartHelpers do
  @moduledoc """
  Shared utilities for chart processing and error handling.

  This module provides common functionality used across chart-related modules,
  including error placeholder generation and error formatting.

  ## Responsibilities

  - Generate standardized error placeholders for failed charts
  - Format error messages for display
  - Provide consistent Typst markup for chart errors

  ## Usage

      iex> ChartHelpers.generate_error_placeholder(:sales_chart, :missing_data)
      %{
        name: :sales_chart,
        chart_type: :bar,
        svg: nil,
        embedded_code: "...",
        error: :missing_data
      }
  """

  @doc """
  Generates an error placeholder for a failed chart.

  Creates a visual error block in Typst format to display when chart generation
  fails. The placeholder includes the chart name and a formatted error message.

  ## Parameters

    * `chart_name` - The name of the chart that failed
    * `error` - The error that occurred (atom or tuple)
    * `opts` - Optional configuration (currently unused, for future extensibility)

  ## Returns

    * Map with chart placeholder structure

  ## Examples

      iex> ChartHelpers.generate_error_placeholder(:revenue_chart, :missing_data)
      %{
        name: :revenue_chart,
        chart_type: :bar,
        svg: nil,
        embedded_code: "...",
        error: :missing_data
      }

      iex> ChartHelpers.generate_error_placeholder(:sales_chart, {:generation_failed, "Invalid config"})
      %{name: :sales_chart, ...}
  """
  @spec generate_error_placeholder(atom(), term(), keyword()) :: map()
  def generate_error_placeholder(chart_name, error, opts \\ []) do
    error_message = format_error_message(error)
    style = Keyword.get(opts, :style, :default)

    embedded_code = build_error_block(chart_name, error_message, style)

    %{
      name: chart_name,
      chart_type: :bar,
      svg: nil,
      embedded_code: embedded_code,
      error: error
    }
  end

  @doc """
  Generates just the Typst error block code without the full structure.

  Useful when you only need the embedded Typst markup without the surrounding
  chart metadata structure.

  ## Parameters

    * `chart_name` - The name of the chart
    * `error` - The error that occurred
    * `opts` - Optional configuration

  ## Returns

    * String containing Typst markup for error display
  """
  @spec generate_error_block(atom(), term(), keyword()) :: String.t()
  def generate_error_block(chart_name, error, opts \\ []) do
    error_message = format_error_message(error)
    style = Keyword.get(opts, :style, :default)
    build_error_block(chart_name, error_message, style)
  end

  # Private Functions

  # Build the Typst error block with specified style
  defp build_error_block(chart_name, error_message, :default) do
    """
    #block(
      width: 100%,
      height: 200pt,
      fill: rgb(255, 230, 230),
      stroke: 1pt + rgb(200, 0, 0),
      radius: 4pt,
      inset: 10pt
    )[
      #text(size: 12pt, weight: "bold", fill: rgb(150, 0, 0))[Chart Error: #{chart_name}]
      #v(0.5em)
      #text(size: 10pt, fill: rgb(100, 0, 0))[#{error_message}]
    ]
    """
  end

  defp build_error_block(chart_name, error_message, :compact) do
    """
    #block(
      width: 100%,
      fill: rgb(255, 240, 240),
      inset: 1em,
      stroke: 1pt + red
    )[
      #text(weight: "bold", fill: red)[Chart Error: #{chart_name}]
      #linebreak()
      #text(size: 10pt)[#{error_message}]
    ]
    """
  end

  # Format error into human-readable message
  defp format_error_message(:aggregation_not_found) do
    "Aggregation data not available for this chart"
  end

  defp format_error_message(:missing_data_source) do
    "No data source specified for this chart"
  end

  defp format_error_message(:config_must_be_map) do
    "Chart configuration must be a map"
  end

  defp format_error_message({:unsupported_expression, _expr}) do
    "Unsupported data source expression format"
  end

  defp format_error_message({:generation_failed, reason}) do
    "Chart generation failed: #{inspect(reason)}"
  end

  defp format_error_message({:unexpected_result, result}) do
    "Unexpected result during chart generation: #{inspect(result)}"
  end

  defp format_error_message(reason) when is_binary(reason) do
    reason
  end

  defp format_error_message(reason) do
    "Error: #{inspect(reason)}"
  end
end
