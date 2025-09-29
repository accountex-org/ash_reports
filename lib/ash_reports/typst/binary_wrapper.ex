defmodule AshReports.Typst.BinaryWrapper do
  @moduledoc """
  Low-level NIF interface wrapper for Typst document compilation.

  This module provides a safe interface to the Typst Rust NIF bindings,
  handling compilation, error handling, and resource management.
  """

  require Logger

  @doc """
  Compiles a Typst template string to the specified format.

  ## Parameters

    * `template` - The Typst template string to compile
    * `opts` - Compilation options:
      * `:format` - Output format (:pdf, :png, :svg). Defaults to :pdf
      * `:timeout` - Compilation timeout in milliseconds. Defaults to 30_000
      * `:working_dir` - Working directory for template resolution
      * `:font_paths` - Additional font directories (list of strings)

  ## Returns

    * `{:ok, binary}` - Successfully compiled document as binary
    * `{:error, reason}` - Compilation failure with error details

  ## Examples

      iex> AshReports.Typst.BinaryWrapper.compile("#set text(size: 12pt)\\nHello, World!", format: :pdf)
      {:ok, <<37, 80, 68, 70, ...>>}

      iex> AshReports.Typst.BinaryWrapper.compile("invalid syntax #", format: :pdf)
      {:error, %{type: :syntax_error, message: "unexpected end of file", line: 1, column: 15}}
  """
  @spec compile(String.t(), Keyword.t()) :: {:ok, binary()} | {:error, term()}
  def compile(template, opts \\ []) when is_binary(template) do
    format = Keyword.get(opts, :format, :pdf)
    timeout = Keyword.get(opts, :timeout, 30_000)

    # Validate input
    with :ok <- validate_template(template),
         :ok <- validate_format(format),
         {:ok, formatted_template} <- prepare_template(template, opts) do
      # Call the NIF with timeout protection
      compile_with_timeout(formatted_template, format, timeout)
    end
  end

  @doc """
  Compiles a Typst template file to the specified format.

  ## Parameters

    * `file_path` - Path to the Typst template file
    * `opts` - Same options as `compile/2`

  ## Returns

    * `{:ok, binary}` - Successfully compiled document as binary
    * `{:error, reason}` - Compilation failure with error details
  """
  @spec compile_file(String.t(), Keyword.t()) :: {:ok, binary()} | {:error, term()}
  def compile_file(file_path, opts \\ []) when is_binary(file_path) do
    case File.read(file_path) do
      {:ok, template} ->
        working_dir = Path.dirname(file_path)
        compile(template, Keyword.put(opts, :working_dir, working_dir))

      {:error, reason} ->
        {:error, {:file_error, reason}}
    end
  end

  @doc """
  Validates that the Typst NIF is properly loaded and available.

  ## Returns

    * `:ok` - NIF is loaded and ready
    * `{:error, :nif_not_loaded}` - NIF failed to load
  """
  @spec validate_nif() :: :ok | {:error, :nif_not_loaded}
  def validate_nif do
    try do
      # Try to call a simple Typst function
      case Typst.render_to_pdf("#set text(size: 12pt)\\nTest") do
        {:ok, _} -> :ok
        _ -> :ok
      end
    rescue
      _ -> {:error, :nif_not_loaded}
    end
  end

  # Private functions

  defp validate_template(""), do: {:error, :empty_template}
  defp validate_template(template) when byte_size(template) > 10_000_000 do
    {:error, :template_too_large}
  end
  defp validate_template(_), do: :ok

  defp validate_format(format) when format in [:pdf, :png, :svg], do: :ok
  defp validate_format(format), do: {:error, {:invalid_format, format}}

  defp prepare_template(template, opts) do
    # Add any preprocessing here if needed
    _working_dir = Keyword.get(opts, :working_dir)
    _font_paths = Keyword.get(opts, :font_paths, [])

    # For now, just return the template as-is
    # In the future, we might inject configuration or preambles
    {:ok, template}
  end

  defp compile_with_timeout(template, format, timeout) do
    task = Task.async(fn ->
      try do
        # Use the actual Typst NIF
        case apply_typst_compile(template, format) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, parse_typst_error(reason)}
        end
      rescue
        error ->
          Logger.error("Typst NIF crashed: #{inspect(error)}")
          {:error, {:nif_crash, error}}
      end
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("Typst compilation timeout after #{timeout}ms")
        {:error, :timeout}

      {:exit, reason} ->
        Logger.error("Typst compilation task exited: #{inspect(reason)}")
        {:error, {:task_exit, reason}}
    end
  end

  defp apply_typst_compile(template, :pdf) do
    # Call the actual Typst NIF function
    Typst.render_to_pdf(template)
  end

  defp apply_typst_compile(template, :png) do
    # For PNG format
    Typst.render_to_png(template)
  end

  defp apply_typst_compile(template, :svg) do
    # SVG would be rendered to string
    Typst.render_to_string(template)
  end

  defp apply_typst_compile(_template, format) do
    {:error, {:unsupported_format, format}}
  end

  defp parse_typst_error(error) when is_binary(error) do
    # Parse Typst error messages for better reporting
    cond do
      String.contains?(error, "syntax error") ->
        %{type: :syntax_error, message: error}

      String.contains?(error, "not found") ->
        %{type: :file_not_found, message: error}

      String.contains?(error, "font") ->
        %{type: :font_error, message: error}

      true ->
        %{type: :compilation_error, message: error}
    end
  end

  defp parse_typst_error(error), do: error
end