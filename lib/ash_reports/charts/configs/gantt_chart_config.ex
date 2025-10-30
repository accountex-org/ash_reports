defmodule AshReports.Charts.GanttChartConfig do
  @moduledoc """
  Configuration struct for Gantt charts using Contex GanttChart.

  This module defines the configuration options for Gantt chart generation,
  mapping to Contex GanttChart options. Gantt charts are ideal for project
  timelines, task scheduling, and visualizing time-based workflows.

  ## Contex Mapping

  This struct maps to Contex.GanttChart options:
  - `show_task_labels` → `:show_task_labels` (boolean)
  - `padding` → `:padding` (integer between task bars)
  - `colours` → `:colour_palette` (list of hex colors without #)

  ## DSL Usage

      gantt_chart :project_timeline do
        data_source expr(project_tasks())
        config do
          width 1000
          height 600
          title "Sprint Planning"
          show_task_labels true
          padding 3
          colours ["E3F2FD", "BBDEFB", "90CAF9"]
        end
      end

  ## Fields

  - `width` - Chart width in pixels (default: 600)
  - `height` - Chart height in pixels (default: 400)
  - `title` - Chart title (optional)
  - `show_task_labels` - Display task names on bars (default: true)
  - `padding` - Padding between task bars in pixels (default: 2)
  - `colours` - List of hex color codes without # (default: [])

  ## Data Format

  **IMPORTANT**: Gantt charts require NaiveDateTime or DateTime types for
  start_time and end_time fields. String dates will NOT be automatically
  converted.

  Required fields:
  - `category` - Grouping for tasks (e.g., "Phase 1", "Development")
  - `task` - Task name/description
  - `start_time` - Must be NaiveDateTime or DateTime
  - `end_time` - Must be NaiveDateTime or DateTime

  Optional field:
  - `task_id` - Unique identifier for the task

  Example:

      [
        %{
          category: "Phase 1",
          task: "Design",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-15 00:00:00],
          task_id: "task_1"
        },
        %{
          category: "Phase 1",
          task: "Development",
          start_time: ~N[2024-01-10 00:00:00],
          end_time: ~N[2024-02-01 00:00:00],
          task_id: "task_2"
        }
      ]

  ## Validation

  The GanttChart type implementation performs strict validation:
  - start_time and end_time must be NaiveDateTime or DateTime types
  - start_time must be before end_time
  - All required fields must be present
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :width, :integer, default: 600
    field :height, :integer, default: 400
    field :title, :string
    field :show_task_labels, :boolean, default: true
    field :padding, :integer, default: 2
    field :colours, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          width: integer(),
          height: integer(),
          title: String.t() | nil,
          show_task_labels: boolean(),
          padding: integer(),
          colours: [String.t()]
        }

  @doc """
  Creates a changeset for Gantt chart configuration.

  ## Validations

  - `width` must be a positive integer
  - `height` must be a positive integer
  - `padding` must be non-negative
  - `colours` must be a list of strings (hex codes without #)
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [:width, :height, :title, :show_task_labels, :padding, :colours])
    |> validate_required([:width, :height])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:padding, greater_than_or_equal_to: 0)
  end
end
