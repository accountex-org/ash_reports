defmodule AshReports.Charts.Config do
  @moduledoc """
  Chart configuration schema using Ecto embedded schema.

  This module defines the configuration options for chart generation, including
  dimensions, styling, labels, and display options.

  ## Fields

    - `title` - Chart title (optional)
    - `width` - Chart width in pixels (default: 600)
    - `height` - Chart height in pixels (default: 400)
    - `colors` - List of color hex codes for chart series (optional)
    - `show_legend` - Whether to display legend (default: true)
    - `legend_position` - Legend position: :top, :bottom, :left, :right (default: :right)
    - `x_axis_label` - X-axis label (optional)
    - `y_axis_label` - Y-axis label (optional)
    - `show_grid` - Whether to show grid lines (default: true)
    - `font_family` - Font family for text (default: "sans-serif")
    - `font_size` - Base font size in pixels (default: 12)

  ## Usage

      config = %AshReports.Charts.Config{
        title: "Monthly Sales",
        width: 800,
        height: 600,
        colors: ["#FF6B6B", "#4ECDC4", "#45B7D1"],
        show_legend: true,
        x_axis_label: "Month",
        y_axis_label: "Sales ($)"
      }

      # Or use defaults
      config = %AshReports.Charts.Config{}
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :title, :string
    field :width, :integer, default: 600
    field :height, :integer, default: 400
    field :colors, {:array, :string}, default: []
    field :show_legend, :boolean, default: true
    field :legend_position, Ecto.Enum, values: [:top, :bottom, :left, :right], default: :right
    field :x_axis_label, :string
    field :y_axis_label, :string
    field :show_grid, :boolean, default: true
    field :font_family, :string, default: "sans-serif"
    field :font_size, :integer, default: 12
  end

  @doc """
  Creates a changeset for chart configuration.

  ## Parameters

    - `config` - Chart config struct
    - `attrs` - Map of attributes to change

  ## Returns

  Ecto.Changeset
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [
      :title,
      :width,
      :height,
      :colors,
      :show_legend,
      :legend_position,
      :x_axis_label,
      :y_axis_label,
      :show_grid,
      :font_family,
      :font_size
    ])
    |> validate_required([:width, :height])
    |> validate_number(:width, greater_than: 0, less_than_or_equal_to: 5000)
    |> validate_number(:height, greater_than: 0, less_than_or_equal_to: 5000)
    |> validate_number(:font_size, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_colors()
  end

  @doc """
  Validates and creates a config struct from a map.

  ## Parameters

    - `attrs` - Map of configuration attributes

  ## Returns

    - `{:ok, config}` - Valid configuration
    - `{:error, changeset}` - Invalid configuration

  ## Examples

      AshReports.Charts.Config.new(%{width: 800, height: 600})
      # => {:ok, %Config{width: 800, height: 600}}

      AshReports.Charts.Config.new(%{width: -100})
      # => {:error, %Ecto.Changeset{}}
  """
  def new(attrs \\ %{}) do
    changeset = changeset(attrs)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  @doc """
  Gets default color palette.

  Returns a list of visually distinct colors suitable for charts.

  ## Returns

  List of hex color strings.

  ## Examples

      Config.default_colors()
      # => ["#FF6B6B", "#4ECDC4", "#45B7D1", ...]
  """
  def default_colors do
    [
      "#FF6B6B",
      "#4ECDC4",
      "#45B7D1",
      "#96CEB4",
      "#FFEAA7",
      "#DFE6E9",
      "#74B9FF",
      "#A29BFE",
      "#FD79A8",
      "#FDCB6E"
    ]
  end

  # Private functions

  defp validate_colors(changeset) do
    colors = get_field(changeset, :colors, [])

    if Enum.all?(colors, &valid_color?/1) do
      changeset
    else
      add_error(changeset, :colors, "must be valid hex color codes (e.g., #FF6B6B)")
    end
  end

  defp valid_color?(color) when is_binary(color) do
    Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color)
  end

  defp valid_color?(_), do: false
end
