defmodule AshReports.HeexRenderer.TemplateBuilder do
  @moduledoc """
  Utilities for building HEEX template strings.

  This module provides helper functions for constructing proper HEEX template
  syntax including for comprehensions, assigns, components, and expressions.

  ## Usage

      # Build a for comprehension
      TemplateBuilder.for_comprehension("band", "@bands", fn ->
        "<div><%= @band.name %></div>"
      end)
      # => "<div :for={band <- @bands}><%= band.name %></div>"

      # Build an assign reference
      TemplateBuilder.assign("report.title")
      # => "<%= @report.title %>"

      # Build a component call
      TemplateBuilder.component("report_header", %{title: "@report.title"})
      # => "<.report_header title={@report.title} />"

  """

  @doc """
  Generates a HEEX for comprehension attribute.

  ## Examples

      iex> for_attr("band", "@bands")
      ":for={band <- @bands}"

  """
  @spec for_attr(String.t(), String.t()) :: String.t()
  def for_attr(item_name, collection) do
    ":for={#{item_name} <- #{collection}}"
  end

  @doc """
  Wraps content in a div with a for comprehension.

  ## Examples

      iex> for_div("band", "@bands", "class=\"band\"", "<span>content</span>")
      "<div :for={band <- @bands} class=\\"band\\"><span>content</span></div>"

  """
  @spec for_div(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def for_div(item_name, collection, attrs \\ "", content) do
    for_attr = for_attr(item_name, collection)
    attrs_str = if attrs != "", do: " #{attrs}", else: ""
    "<div #{for_attr}#{attrs_str}>#{content}</div>"
  end

  @doc """
  Generates an assign reference for use in HEEX templates.

  ## Examples

      iex> assign("report.title")
      "<%= @report.title %>"

      iex> assign("band", raw: true)
      "@band"

  """
  @spec assign(String.t(), keyword()) :: String.t()
  def assign(path, opts \\ []) do
    raw = Keyword.get(opts, :raw, false)

    if raw do
      "@#{path}"
    else
      "<%= @#{path} %>"
    end
  end

  @doc """
  Generates a Phoenix component call.

  ## Examples

      iex> component("report_header", %{title: "@report.title"})
      "<.report_header title={@report.title} />"

      iex> component("band", %{type: "@band.type"}, "<span>content</span>")
      "<.band type={@band.type}><span>content</span></.band>"

  """
  @spec component(String.t(), map(), String.t() | nil) :: String.t()
  def component(name, attrs \\ %{}, content \\ nil) do
    attrs_str = build_component_attrs(attrs)

    if content do
      "<.#{name}#{attrs_str}>#{content}</.#{name}>"
    else
      "<.#{name}#{attrs_str} />"
    end
  end

  @doc """
  Wraps content in an if condition.

  ## Examples

      iex> if_condition("@show_header", "<div>Header</div>")
      "<%= if @show_header do %><div>Header</div><% end %>"

  """
  @spec if_condition(String.t(), String.t()) :: String.t()
  def if_condition(condition, content) do
    "<%= if #{condition} do %>#{content}<% end %>"
  end

  @doc """
  Wraps content in an if-else condition.

  ## Examples

      iex> if_else("@has_data", "<div>Data</div>", "<div>No data</div>")
      "<%= if @has_data do %><div>Data</div><% else %><div>No data</div><% end %>"

  """
  @spec if_else(String.t(), String.t(), String.t()) :: String.t()
  def if_else(condition, true_content, false_content) do
    "<%= if #{condition} do %>#{true_content}<% else %>#{false_content}<% end %>"
  end

  @doc """
  Generates a case statement.

  ## Examples

      iex> case_statement("@band.type", [
      ...>   {:title, "<div>Title</div>"},
      ...>   {:detail, "<div>Detail</div>"}
      ...> ])
      "<%= case @band.type do %><% :title -> %><div>Title</div><% :detail -> %><div>Detail</div><% end %>"

  """
  @spec case_statement(String.t(), [{atom(), String.t()}]) :: String.t()
  def case_statement(expression, clauses) do
    clauses_str =
      clauses
      |> Enum.map(fn {pattern, content} ->
        "<% #{inspect(pattern)} -> %>#{content}"
      end)
      |> Enum.join("")

    "<%= case #{expression} do %>#{clauses_str}<% end %>"
  end

  @doc """
  Escapes a string for safe inclusion in HEEX templates.

  ## Examples

      iex> escape("<script>alert('xss')</script>")
      "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"

  """
  @spec escape(String.t()) :: String.t()
  def escape(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  def escape(value), do: to_string(value)

  @doc """
  Wraps content in a container div with optional class.

  ## Examples

      iex> container("<span>content</span>", "ash-report")
      "<div class=\\"ash-report\\"><span>content</span></div>"

  """
  @spec container(String.t(), String.t() | nil) :: String.t()
  def container(content, class \\ nil) do
    class_attr = if class, do: " class=\"#{class}\"", else: ""
    "<div#{class_attr}>#{content}</div>"
  end

  @doc """
  Builds a comment in HEEX format.

  ## Examples

      iex> comment("This is a band")
      "<%!-- This is a band --%>"

  """
  @spec comment(String.t()) :: String.t()
  def comment(text) do
    "<%!-- #{text} --%>"
  end

  @doc """
  Joins multiple template fragments.

  ## Examples

      iex> join(["<div>1</div>", "<div>2</div>"], "\\n")
      "<div>1</div>\\n<div>2</div>"

  """
  @spec join([String.t()], String.t()) :: String.t()
  def join(fragments, separator \\ "\n") do
    Enum.join(fragments, separator)
  end

  @doc """
  Builds an HTML tag with attributes and content.

  ## Examples

      iex> tag("span", [class: "label"], "Hello")
      "<span class=\\"label\\">Hello</span>"

      iex> tag("img", [src: "/logo.png", alt: "Logo"])
      "<img src=\\"/logo.png\\" alt=\\"Logo\\" />"

  """
  @spec tag(String.t(), keyword(), String.t() | nil) :: String.t()
  def tag(name, attrs \\ [], content \\ nil) do
    attrs_str = build_html_attrs(attrs)

    if content do
      "<#{name}#{attrs_str}>#{content}</#{name}>"
    else
      "<#{name}#{attrs_str} />"
    end
  end

  # Private Helpers

  defp build_component_attrs(attrs) when map_size(attrs) == 0, do: ""

  defp build_component_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      " #{key}={#{value}}"
    end)
    |> Enum.join("")
  end

  defp build_html_attrs([]), do: ""

  defp build_html_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value} ->
      " #{key}=\"#{escape(value)}\""
    end)
    |> Enum.join("")
  end
end
