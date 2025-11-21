defmodule AshReports.Layout.Transformer.Cell do
  @moduledoc """
  Transforms Cell DSL entities to CellIR.

  Handles transformation of cell properties and content to the normalized IR format.
  """

  alias AshReports.Layout.{GridCell, TableCell, IR}

  @doc """
  Transforms a Cell DSL entity to a CellIR.

  Accepts both GridCell and TableCell structs.
  """
  @spec transform(GridCell.t() | TableCell.t() | map()) :: {:ok, IR.Cell.t()} | {:error, term()}
  def transform(%GridCell{} = cell) do
    do_transform(cell)
  end

  def transform(%TableCell{} = cell) do
    do_transform(cell)
  end

  def transform(%{} = cell) do
    # Handle generic cell maps
    do_transform(cell)
  end

  defp do_transform(cell) do
    with {:ok, content} <- transform_content(cell),
         {:ok, properties} <- build_properties(cell) do
      position = get_position(cell)
      span = get_span(cell)

      cell_ir = IR.Cell.new(
        position: position,
        span: span,
        properties: properties,
        content: content
      )

      {:ok, cell_ir}
    end
  end

  defp get_position(cell) do
    x = Map.get(cell, :x, 0)
    y = Map.get(cell, :y, 0)
    {x, y}
  end

  defp get_span(cell) do
    colspan = Map.get(cell, :colspan, 1)
    rowspan = Map.get(cell, :rowspan, 1)
    {colspan, rowspan}
  end

  defp transform_content(cell) do
    elements = Map.get(cell, :elements, [])

    content =
      Enum.map(elements, fn element ->
        case transform_element(element) do
          {:ok, content_ir} -> content_ir
          {:error, _} = err -> throw(err)
        end
      end)

    {:ok, content}
  catch
    {:error, _} = err -> err
  end

  defp transform_element(element) do
    cond do
      # Check for Label struct
      is_struct(element, AshReports.Element.Label) ->
        transform_label(element)

      # Check for Field struct
      is_struct(element, AshReports.Element.Field) ->
        transform_field(element)

      # Check for map with text (label)
      Map.has_key?(element, :text) ->
        transform_label_map(element)

      # Check for map with source (field)
      Map.has_key?(element, :source) ->
        transform_field_map(element)

      # Check for nested layout
      Map.has_key?(element, :type) and element.type in [:grid, :table, :stack] ->
        transform_nested_layout(element)

      true ->
        {:error, {:unknown_element_type, element}}
    end
  end

  defp transform_label(%AshReports.Element.Label{} = label) do
    style = build_label_style(label)
    {:ok, IR.Content.label(label.text || "", style: style)}
  end

  defp transform_label_map(element) do
    style = build_element_style(element)
    text = Map.get(element, :text, "")
    {:ok, IR.Content.label(text, style: style)}
  end

  defp transform_field(%AshReports.Element.Field{} = field) do
    style = build_field_style(field)
    {:ok, IR.Content.field(field.source,
      format: field.format,
      decimal_places: Map.get(field, :decimal_places),
      style: style
    )}
  end

  defp transform_field_map(element) do
    style = build_element_style(element)
    {:ok, IR.Content.field(element.source,
      format: Map.get(element, :format),
      decimal_places: Map.get(element, :decimal_places),
      style: style
    )}
  end

  defp transform_nested_layout(element) do
    # Recursively transform nested layouts
    alias AshReports.Layout.Transformer

    case Transformer.transform(element) do
      {:ok, layout_ir} ->
        {:ok, IR.Content.nested_layout(layout_ir)}
      {:error, _} = err ->
        err
    end
  end

  defp build_label_style(%AshReports.Element.Label{} = label) do
    style_map = Map.get(label, :style, %{}) || %{}

    style_props = [
      font_size: Map.get(style_map, :font_size),
      font_weight: Map.get(style_map, :font_weight) || Map.get(label, :font_weight),
      font_style: Map.get(style_map, :font_style) || Map.get(label, :font_style),
      color: Map.get(style_map, :color) || Map.get(label, :color),
      font_family: Map.get(style_map, :font_family) || Map.get(label, :font_family),
      text_align: Map.get(style_map, :text_align) || Map.get(label, :align)
    ]

    if Enum.all?(style_props, fn {_k, v} -> is_nil(v) end) do
      nil
    else
      IR.Style.new(style_props)
    end
  end

  defp build_field_style(%AshReports.Element.Field{} = field) do
    style_map = Map.get(field, :style, %{}) || %{}

    style_props = [
      font_size: Map.get(style_map, :font_size),
      font_weight: Map.get(style_map, :font_weight),
      color: Map.get(style_map, :color),
      font_family: Map.get(style_map, :font_family),
      text_align: Map.get(style_map, :text_align) || Map.get(field, :align)
    ]

    if Enum.all?(style_props, fn {_k, v} -> is_nil(v) end) do
      nil
    else
      IR.Style.new(style_props)
    end
  end

  defp build_element_style(element) do
    style_props = [
      font_size: Map.get(element, :font_size),
      font_weight: Map.get(element, :font_weight),
      font_style: Map.get(element, :font_style),
      color: Map.get(element, :color),
      font_family: Map.get(element, :font_family),
      text_align: Map.get(element, :text_align)
    ]

    if Enum.all?(style_props, fn {_k, v} -> is_nil(v) end) do
      nil
    else
      IR.Style.new(style_props)
    end
  end

  defp build_properties(cell) do
    properties = %{
      align: Map.get(cell, :align),
      inset: Map.get(cell, :inset),
      fill: Map.get(cell, :fill),
      stroke: Map.get(cell, :stroke)
    }

    # Remove nil values
    properties =
      properties
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {:ok, properties}
  end
end
