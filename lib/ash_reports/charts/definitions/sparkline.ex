defmodule AshReports.Charts.Sparkline do
  @moduledoc """
  Definition struct for a sparkline chart.

  This module represents a standalone sparkline definition that can be
  referenced in report bands. Sparklines are compact, inline charts designed
  to show trends at a glance without detailed axes or labels. They are ideal
  for embedding in tables or showing multiple small trends side-by-side.

  ## DSL Usage

  Define a sparkline at the reports level:

      reports do
        sparkline :weekly_trend do
          data_source expr(get_last_7_days())
          config do
            width 100
            height 20
            spot_radius 2
            spot_colour "red"
            line_width 1
            line_colour "rgba(0, 200, 50, 0.7)"
            fill_colour "rgba(0, 200, 50, 0.2)"
          end
        end

        report :dashboard do
          bands do
            band :metrics do
              elements do
                sparkline :weekly_trend
              end
            end
          end
        end
      end

  ## Fields

  - `name` - Atom identifier for the sparkline (e.g., :weekly_trend)
  - `data_source` - Expression that evaluates to chart data at render time
  - `config` - SparklineConfig struct with chart configuration options

  ## Data Source

  The `data_source` field should be an expression that evaluates to a simple
  list of numeric values representing the trend. The expression is evaluated
  in the report's execution context with access to variables and the current
  record scope.

  ## Compact Design

  Sparklines use compact defaults (100x20 pixels) suitable for inline display.
  They show trend direction and patterns without detailed axes or labels.
  """

  alias AshReports.Charts.SparklineConfig

  @type t :: %__MODULE__{
          name: atom(),
          data_source: term(),
          config: SparklineConfig.t() | nil
        }

  defstruct [:name, :data_source, :config]

  @doc """
  Creates a new Sparkline definition.

  ## Parameters

  - `name` - Atom identifier for the sparkline
  - `opts` - Keyword list with optional :data_source and :config

  ## Examples

      iex> Sparkline.new(:my_sparkline, data_source: expr(get_data()), config: %SparklineConfig{})
      %Sparkline{name: :my_sparkline, data_source: {:expr, [get_data()]}, config: %SparklineConfig{}}
  """
  @spec new(atom(), keyword()) :: t()
  def new(name, opts \\ []) when is_atom(name) do
    %__MODULE__{
      name: name,
      data_source: Keyword.get(opts, :data_source),
      config: Keyword.get(opts, :config)
    }
  end
end
