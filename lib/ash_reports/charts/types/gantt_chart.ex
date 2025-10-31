defmodule AshReports.Charts.Types.GanttChart do
  @moduledoc """
  Gantt chart implementation using Contex.

  Displays project timelines with task scheduling, showing task bars across time
  intervals. Supports task grouping by category with different background colors.

  ## Data Format

  Data must be a list of maps with category, task, start time, and end time:

      [
        %{
          category: "Phase 1",
          task: "Design",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-15 00:00:00]
        },
        %{
          category: "Phase 1",
          task: "Development",
          start_time: ~N[2024-01-10 00:00:00],
          end_time: ~N[2024-02-01 00:00:00]
        },
        %{
          category: "Phase 2",
          task: "Testing",
          start_time: ~N[2024-01-25 00:00:00],
          end_time: ~N[2024-02-10 00:00:00]
        }
      ]

  ## DateTime Requirements

  **IMPORTANT**: Start and end time columns **MUST** be `NaiveDateTime` or `DateTime` types.
  String dates will NOT be automatically converted. Use `NaiveDateTime.new!/2` or
  similar functions to create proper DateTime values.

  ## Configuration

  Standard chart configuration plus:
  - `padding` - Padding between task bars (default: 2)
  - `show_task_labels` - Display labels for each task (default: true)
  - `colors` - Color palette for categories

  ## Examples

      # Basic Gantt chart
      data = [
        %{
          category: "Development",
          task: "Feature A",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-15 00:00:00],
          task_id: "task_1"
        },
        %{
          category: "Development",
          task: "Feature B",
          start_time: ~N[2024-01-10 00:00:00],
          end_time: ~N[2024-01-25 00:00:00],
          task_id: "task_2"
        }
      ]
      config = %Config{
        title: "Project Timeline",
        width: 800,
        height: 400
      }
      chart = GanttChart.build(data, config)

      # With custom colors and options
      config = %Config{
        title: "Sprint Planning",
        colors: ["ff6384", "36a2eb", "ffce56"],
        options: %{
          padding: 3,
          show_task_labels: true
        }
      }
      chart = GanttChart.build(data, config)

  ## Use Cases

  - Project timeline visualization
  - Sprint planning and tracking
  - Resource allocation planning
  - Task dependency visualization
  - Milestone tracking
  """

  @behaviour AshReports.Charts.Types.Behavior

  alias AshReports.Charts.GanttChartConfig
  alias Contex.{Dataset, GanttChart}

  @impl true
  def build(data, %GanttChartConfig{} = config) do
    # Convert data to Contex Dataset
    dataset = Dataset.new(data)

    # Get column names from data
    column_mapping = get_column_mapping(data)

    # Get colors for the chart
    colors = get_colors(config)

    # Build options map
    options = build_options(config, colors, column_mapping)

    # Build Gantt chart
    GanttChart.new(dataset, options)
  end

  @impl true
  def validate(data) when is_list(data) and length(data) > 0 do
    # Check if all items have required fields with proper types
    validation_results =
      data
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} -> validate_data_point(item, index) end)
      |> Enum.reject(&(&1 == :ok))

    case validation_results do
      [] -> :ok
      [first_error | _] -> first_error
    end
  end

  def validate([]), do: {:error, "Data cannot be empty"}
  def validate(_), do: {:error, "Data must be a list"}

  # Private functions

  defp validate_data_point(item, index) do
    cond do
      not is_map(item) ->
        {:error, "Item #{index} must be a map"}

      not has_required_fields?(item) ->
        {:error,
         "Item #{index} must have category, task, start_time, and end_time fields (or string key variants)"}

      not valid_datetime_fields?(item) ->
        {:error,
         "Item #{index}: start_time and end_time must be NaiveDateTime or DateTime types, not strings"}

      not valid_time_order?(item) ->
        {:error, "Item #{index}: start_time must be before end_time"}

      true ->
        :ok
    end
  end

  defp has_required_fields?(item) do
    # Check for atom keys
    (Map.has_key?(item, :category) and Map.has_key?(item, :task) and
       Map.has_key?(item, :start_time) and Map.has_key?(item, :end_time)) or
      # Check for string keys
      (Map.has_key?(item, "category") and Map.has_key?(item, "task") and
         Map.has_key?(item, "start_time") and Map.has_key?(item, "end_time"))
  end

  defp valid_datetime_fields?(item) do
    start_time = Map.get(item, :start_time) || Map.get(item, "start_time")
    end_time = Map.get(item, :end_time) || Map.get(item, "end_time")

    is_datetime?(start_time) and is_datetime?(end_time)
  end

  defp is_datetime?(%NaiveDateTime{}), do: true
  defp is_datetime?(%DateTime{}), do: true
  defp is_datetime?(_), do: false

  defp valid_time_order?(item) do
    start_time = Map.get(item, :start_time) || Map.get(item, "start_time")
    end_time = Map.get(item, :end_time) || Map.get(item, "end_time")

    case {start_time, end_time} do
      {%NaiveDateTime{} = start_dt, %NaiveDateTime{} = end_dt} ->
        NaiveDateTime.compare(start_dt, end_dt) == :lt

      {%DateTime{} = start_dt, %DateTime{} = end_dt} ->
        DateTime.compare(start_dt, end_dt) == :lt

      # Mixed NaiveDateTime and DateTime
      {%NaiveDateTime{} = start_dt, %DateTime{} = end_dt} ->
        NaiveDateTime.compare(start_dt, DateTime.to_naive(end_dt)) == :lt

      {%DateTime{} = start_dt, %NaiveDateTime{} = end_dt} ->
        NaiveDateTime.compare(DateTime.to_naive(start_dt), end_dt) == :lt

      _ ->
        false
    end
  end

  defp get_column_mapping(data) do
    first = List.first(data)

    if Map.has_key?(first, :category) do
      # Atom keys
      %{
        category_col: :category,
        task_col: :task,
        start_col: :start_time,
        finish_col: :end_time,
        id_col: if(Map.has_key?(first, :task_id), do: :task_id, else: nil)
      }
    else
      # String keys
      %{
        category_col: "category",
        task_col: "task",
        start_col: "start_time",
        finish_col: "end_time",
        id_col: if(Map.has_key?(first, "task_id"), do: "task_id", else: nil)
      }
    end
  end

  defp build_options(%GanttChartConfig{} = config, colors, column_mapping) do
    base_options = [
      mapping: filter_nil_values(column_mapping),
      colour_palette: colors
    ]

    # Add width and height if specified
    base_options
    |> maybe_add_option(:width, config.width)
    |> maybe_add_option(:height, config.height)
    |> maybe_add_option(:padding, config.padding)
    |> maybe_add_option(:show_task_labels, config.show_task_labels)
  end

  defp filter_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp maybe_add_option(options, _key, nil), do: options

  defp maybe_add_option(options, key, value) do
    Keyword.put(options, key, value)
  end

  defp get_colors(%GanttChartConfig{colours: colours}) when is_list(colours) and length(colours) > 0 do
    # Contex expects hex colors without the # prefix
    Enum.map(colours, fn color ->
      String.trim_leading(color, "#")
    end)
  end

  defp get_colors(_config) do
    # Use default color palette
    :default
  end
end
