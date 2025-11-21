defmodule AshReports.Layout.Transformer.Stack do
  @moduledoc """
  Transforms Stack DSL entities to StackIR.

  Handles transformation of direction, spacing, and child elements.
  """

  alias AshReports.Layout.{Stack, IR}

  @doc """
  Transforms a Stack DSL entity to a LayoutIR.

  ## Examples

      iex> stack = %AshReports.Layout.Stack{name: :my_stack, dir: :ttb}
      iex> {:ok, ir} = AshReports.Layout.Transformer.Stack.transform(stack)
      iex> ir.type
      :stack
  """
  @spec transform(Stack.t()) :: {:ok, IR.t()} | {:error, term()}
  def transform(%Stack{} = stack) do
    with {:ok, children} <- transform_children(stack),
         {:ok, properties} <- build_properties(stack) do
      ir = IR.new(:stack,
        properties: properties,
        children: children
      )

      {:ok, ir}
    end
  end

  defp transform_children(%Stack{elements: elements}) do
    children =
      Enum.map(elements, fn element ->
        case transform_element(element) do
          {:ok, content_ir} ->
            # Wrap content in a cell for consistency
            IR.Cell.new(content: [content_ir])
          {:error, _} = err -> throw(err)
        end
      end)

    {:ok, children}
  catch
    {:error, _} = err -> err
  end

  defp transform_element(element) do
    cond do
      # Check for nested layout
      is_struct(element, AshReports.Layout.Grid) ->
        alias AshReports.Layout.Transformer.Grid
        case Grid.transform(element) do
          {:ok, ir} -> {:ok, IR.Content.nested_layout(ir)}
          err -> err
        end

      is_struct(element, AshReports.Layout.Table) ->
        alias AshReports.Layout.Transformer.Table
        case Table.transform(element) do
          {:ok, ir} -> {:ok, IR.Content.nested_layout(ir)}
          err -> err
        end

      is_struct(element, AshReports.Layout.Stack) ->
        case transform(element) do
          {:ok, ir} -> {:ok, IR.Content.nested_layout(ir)}
          err -> err
        end

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

  defp build_properties(%Stack{} = stack) do
    properties = %{
      dir: stack.dir,
      spacing: stack.spacing
    }

    # Remove nil values
    properties =
      properties
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {:ok, properties}
  end
end
