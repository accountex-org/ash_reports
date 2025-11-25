defmodule AshReports.Renderer.Html.Behaviour do
  @moduledoc """
  Behaviour for HTML layout renderers.

  This behaviour defines the contract that all layout-specific renderers
  (Grid, Table, Stack) must implement. It ensures a consistent API across
  all renderer types and enables compile-time checks.

  ## Implementing a Renderer

  To implement a new layout renderer:

      defmodule AshReports.Renderer.Html.MyLayout do
        @behaviour AshReports.Renderer.Html.Behaviour

        alias AshReports.Layout.IR

        @impl true
        def render(%IR{type: :my_layout} = ir, opts \\\\ []) do
          # Render implementation
          "<div>...</div>"
        end

        @impl true
        def build_styles(properties) do
          # Style building implementation
          "display: block"
        end
      end

  ## Callbacks

  - `render/2` - Main rendering function that converts IR to HTML string
  - `build_styles/1` - Builds CSS style string from properties map
  """

  alias AshReports.Layout.IR

  @doc """
  Renders an IR layout to an HTML string.

  ## Parameters

  - `ir` - The LayoutIR struct to render
  - `opts` - Keyword list of rendering options

  ## Options

  Common options supported by renderers:
  - `:data` - Map of data for field interpolation
  - `:context` - Rendering context (e.g., `:grid`, `:table_header`)
  - `:parent_properties` - Properties inherited from parent layout

  ## Returns

  String containing the HTML markup for the layout.
  """
  @callback render(ir :: IR.t(), opts :: keyword()) :: String.t()

  @doc """
  Builds a CSS style string from layout properties.

  ## Parameters

  - `properties` - Map of layout properties

  ## Returns

  String containing semicolon-separated CSS properties,
  or empty string if no styles apply.

  ## Example

      build_styles(%{columns: ["1fr", "2fr"], gap: "10px"})
      #=> "display: grid; grid-template-columns: 1fr 2fr; gap: 10px"
  """
  @callback build_styles(properties :: map()) :: String.t()
end
