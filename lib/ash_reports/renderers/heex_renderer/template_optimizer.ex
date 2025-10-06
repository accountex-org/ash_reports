defmodule AshReports.HeexRenderer.TemplateOptimizer do
  @moduledoc """
  Template optimization and compilation system for AshReports Phase 6.2.

  Provides HEEX template optimization, compilation caching, and performance
  enhancements for LiveView chart components with intelligent template
  analysis and runtime optimization.
  """

  @template_cache_name :ash_reports_template_cache

  @doc """
  Optimize a HEEX template for performance.
  """
  @spec optimize_template(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def optimize_template(template_string, opts \\ %{}) do
    optimized =
      template_string
      |> remove_unnecessary_whitespace()
      |> optimize_static_sections(opts)
      |> compress_template_size()

    {:ok, optimized}
  rescue
    error -> {:error, "Template optimization failed: #{Exception.message(error)}"}
  end

  @doc """
  Compile and cache HEEX template for reuse.
  """
  @spec compile_and_cache(String.t(), String.t(), map()) :: :ok | {:error, String.t()}
  def compile_and_cache(template_name, template_string, opts \\ %{}) do
    case optimize_template(template_string, opts) do
      {:ok, optimized_template} ->
        cache_key = generate_cache_key(template_name)
        :ok = store_in_cache(cache_key, optimized_template)
        :ok

      {:error, reason} ->
        {:error, "Template compilation failed: #{reason}"}
    end
  end

  @doc """
  Clear template cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    try do
      :ets.delete_all_objects(@template_cache_name)
    rescue
      _ -> :ok
    end

    :ok
  end

  # Private functions

  defp remove_unnecessary_whitespace(template) do
    template
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/>\s+</, "><")
    |> String.trim()
  end

  defp optimize_static_sections(template, opts) do
    if opts[:cache_static_sections] do
      template
      |> String.replace(~r/<div class="static">(.*?)<\/div>/s, "<%= cached_static(\"\\1\") %>")
    else
      template
    end
  end

  defp compress_template_size(template) do
    template
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.replace(~r/\s+class=""/, "")
    |> String.replace(~r/\s+style=""/, "")
  end

  defp generate_cache_key(template_name) do
    timestamp = System.system_time(:millisecond)

    hash =
      :crypto.hash(:md5, "#{template_name}_#{timestamp}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 8)

    "template_#{hash}"
  end

  defp store_in_cache(cache_key, optimized_template) do
    # Ensure cache table exists
    try do
      :ets.new(@template_cache_name, [:set, :public, :named_table])
    rescue
      # Table already exists
      ArgumentError -> :ok
    end

    :ets.insert(@template_cache_name, {cache_key, optimized_template})
    :ok
  end
end
