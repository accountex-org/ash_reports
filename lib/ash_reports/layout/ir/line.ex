defmodule AshReports.Layout.IR.Line do
  @moduledoc """
  Intermediate Representation for horizontal and vertical lines.

  Lines are used for visual separators in grids and tables (hline/vline).

  ## Orientation

  - `:horizontal` - Spans across columns (hline)
  - `:vertical` - Spans across rows (vline)

  ## Position

  For horizontal lines, position is the row index (y).
  For vertical lines, position is the column index (x).

  ## Examples

      # Horizontal line at row 2, spanning columns 0-3
      hline = AshReports.Layout.IR.Line.new(
        orientation: :horizontal,
        position: 2,
        start: 0,
        end: 3,
        stroke: "1pt"
      )

      # Vertical line at column 1
      vline = AshReports.Layout.IR.Line.new(
        orientation: :vertical,
        position: 1,
        stroke: "2pt solid red"
      )
  """

  @type orientation :: :horizontal | :vertical

  @type t :: %__MODULE__{
          orientation: orientation(),
          position: non_neg_integer(),
          start: non_neg_integer() | nil,
          end: non_neg_integer() | nil,
          stroke: String.t() | nil
        }

  defstruct [
    :orientation,
    :position,
    :start,
    :end,
    :stroke
  ]

  @doc """
  Creates a new LineIR struct with the given options.

  ## Options

  - `:orientation` - `:horizontal` or `:vertical` (required)
  - `:position` - Row index for hline, column index for vline (required)
  - `:start` - Start position for the line (optional)
  - `:end` - End position for the line (optional)
  - `:stroke` - Stroke specification (e.g., "1pt", "2pt solid red")

  ## Examples

      iex> AshReports.Layout.IR.Line.new(orientation: :horizontal, position: 1)
      %AshReports.Layout.IR.Line{orientation: :horizontal, position: 1, ...}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    %__MODULE__{
      orientation: Keyword.fetch!(opts, :orientation),
      position: Keyword.fetch!(opts, :position),
      start: Keyword.get(opts, :start),
      end: Keyword.get(opts, :end),
      stroke: Keyword.get(opts, :stroke)
    }
  end

  @doc """
  Creates a horizontal line (hline) at the given row.
  """
  @spec hline(non_neg_integer(), Keyword.t()) :: t()
  def hline(row, opts \\ []) do
    opts
    |> Keyword.put(:orientation, :horizontal)
    |> Keyword.put(:position, row)
    |> new()
  end

  @doc """
  Creates a vertical line (vline) at the given column.
  """
  @spec vline(non_neg_integer(), Keyword.t()) :: t()
  def vline(column, opts \\ []) do
    opts
    |> Keyword.put(:orientation, :vertical)
    |> Keyword.put(:position, column)
    |> new()
  end

  @doc """
  Returns true if the line is horizontal.
  """
  @spec horizontal?(t()) :: boolean()
  def horizontal?(%__MODULE__{orientation: :horizontal}), do: true
  def horizontal?(_), do: false

  @doc """
  Returns true if the line is vertical.
  """
  @spec vertical?(t()) :: boolean()
  def vertical?(%__MODULE__{orientation: :vertical}), do: true
  def vertical?(_), do: false
end
