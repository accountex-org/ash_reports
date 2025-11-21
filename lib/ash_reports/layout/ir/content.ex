defmodule AshReports.Layout.IR.Content do
  @moduledoc """
  Intermediate Representation for content elements.

  This module defines IR types for content that can appear within cells:
  - `LabelIR` - Static text content
  - `FieldIR` - Dynamic field values with formatting
  - `NestedLayoutIR` - Nested layout containers

  ## Content Union Type

  The `t()` type is a union of all content types, making content polymorphic
  within cells.

  ## Examples

      # Label content
      label = AshReports.Layout.IR.Content.label("Total:", style: %{font_weight: :bold})

      # Field content
      field = AshReports.Layout.IR.Content.field(:amount,
        format: :currency,
        decimal_places: 2
      )

      # Nested layout
      nested = AshReports.Layout.IR.Content.nested_layout(grid_ir)
  """

  alias AshReports.Layout.IR.Style

  # Label IR

  @type label_ir :: %{
          __struct__: __MODULE__.Label,
          text: String.t(),
          style: Style.t() | nil
        }

  defmodule Label do
    @moduledoc """
    IR for static text labels.
    """

    @type t :: %__MODULE__{
            text: String.t(),
            style: AshReports.Layout.IR.Style.t() | nil
          }

    defstruct [:text, :style]

    @doc """
    Creates a new LabelIR.
    """
    @spec new(String.t(), Keyword.t()) :: t()
    def new(text, opts \\ []) do
      %__MODULE__{
        text: text,
        style: Keyword.get(opts, :style)
      }
    end
  end

  # Field IR

  @type field_ir :: %{
          __struct__: __MODULE__.Field,
          source: atom() | list(atom()),
          format: atom() | nil,
          decimal_places: non_neg_integer() | nil,
          style: Style.t() | nil
        }

  defmodule Field do
    @moduledoc """
    IR for dynamic field values.
    """

    @type t :: %__MODULE__{
            source: atom() | list(atom()),
            format: atom() | nil,
            decimal_places: non_neg_integer() | nil,
            style: AshReports.Layout.IR.Style.t() | nil
          }

    defstruct [:source, :format, :decimal_places, :style]

    @doc """
    Creates a new FieldIR.
    """
    @spec new(atom() | list(atom()), Keyword.t()) :: t()
    def new(source, opts \\ []) do
      %__MODULE__{
        source: source,
        format: Keyword.get(opts, :format),
        decimal_places: Keyword.get(opts, :decimal_places),
        style: Keyword.get(opts, :style)
      }
    end
  end

  # Nested Layout IR

  @type nested_layout_ir :: %{
          __struct__: __MODULE__.NestedLayout,
          layout: AshReports.Layout.IR.t()
        }

  defmodule NestedLayout do
    @moduledoc """
    IR for nested layout containers within cells.
    """

    @type t :: %__MODULE__{
            layout: AshReports.Layout.IR.t()
          }

    defstruct [:layout]

    @doc """
    Creates a new NestedLayoutIR.
    """
    @spec new(AshReports.Layout.IR.t()) :: t()
    def new(layout) do
      %__MODULE__{layout: layout}
    end
  end

  # Union type for all content
  @type t :: Label.t() | Field.t() | NestedLayout.t()

  # Convenience constructors

  @doc """
  Creates a label content IR.

  ## Options

  - `:style` - StyleIR for text styling

  ## Examples

      iex> AshReports.Layout.IR.Content.label("Hello")
      %AshReports.Layout.IR.Content.Label{text: "Hello", style: nil}
  """
  @spec label(String.t(), Keyword.t()) :: Label.t()
  def label(text, opts \\ []) do
    Label.new(text, opts)
  end

  @doc """
  Creates a field content IR.

  ## Options

  - `:format` - Format type (:number, :currency, :date, etc.)
  - `:decimal_places` - Number of decimal places for numeric formats
  - `:style` - StyleIR for field styling

  ## Examples

      iex> AshReports.Layout.IR.Content.field(:amount, format: :currency)
      %AshReports.Layout.IR.Content.Field{source: :amount, format: :currency, ...}
  """
  @spec field(atom() | list(atom()), Keyword.t()) :: Field.t()
  def field(source, opts \\ []) do
    Field.new(source, opts)
  end

  @doc """
  Creates a nested layout content IR.

  ## Examples

      iex> grid_ir = AshReports.Layout.IR.grid()
      iex> AshReports.Layout.IR.Content.nested_layout(grid_ir)
      %AshReports.Layout.IR.Content.NestedLayout{layout: %AshReports.Layout.IR{...}}
  """
  @spec nested_layout(AshReports.Layout.IR.t()) :: NestedLayout.t()
  def nested_layout(layout) do
    NestedLayout.new(layout)
  end

  @doc """
  Returns the type of content IR.

  ## Examples

      iex> AshReports.Layout.IR.Content.content_type(%AshReports.Layout.IR.Content.Label{})
      :label
  """
  @spec content_type(t()) :: :label | :field | :nested_layout
  def content_type(%Label{}), do: :label
  def content_type(%Field{}), do: :field
  def content_type(%NestedLayout{}), do: :nested_layout
end
