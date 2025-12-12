defmodule AshReports.Renderer.Html.AssetManager do
  @moduledoc """
  Asset management for HTML rendering.

  Provides CSS links and asset management for HTML report rendering.
  This module replaces the legacy `AshReports.HtmlRenderer.AssetManager`.
  """

  alias AshReports.RenderContext

  @doc """
  Generates CSS link tags for HTML reports.

  Returns an empty string as modern reports use inline CSS.
  """
  @spec generate_css_links(RenderContext.t()) :: String.t()
  def generate_css_links(%RenderContext{} = _context) do
    # Modern reports use inline CSS, so no external links are needed
    ""
  end

  def generate_css_links(_), do: ""
end
