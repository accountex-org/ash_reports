defmodule AshReports.Typst.TemplateManager do
  @moduledoc """
  GenServer for managing Typst templates with caching and hot-reloading.

  Provides file-based template loading, ETS caching, and development-time
  hot-reloading for improved developer experience.
  """

  use GenServer
  require Logger

  alias AshReports.Typst.{BinaryWrapper, DSLGenerator}

  @table_name :typst_template_cache
  @default_cache_ttl :timer.minutes(15)

  # Client API

  @doc """
  Starts the template manager GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Loads a template by name, using cache if available.

  ## Parameters

    * `template_name` - Name of the template (without extension)
    * `opts` - Options:
      * `:force_reload` - Bypass cache and reload from disk
      * `:theme` - Theme to apply to the template

  ## Returns

    * `{:ok, template_content}` - Template content as string
    * `{:error, reason}` - Loading failure
  """
  @spec load_template(String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def load_template(template_name, opts \\ []) do
    GenServer.call(__MODULE__, {:load_template, template_name, opts})
  end

  @doc """
  Compiles a template with the given data.

  ## Parameters

    * `template_name` - Name of the template
    * `data` - Data to pass to the template
    * `opts` - Compilation options

  ## Returns

    * `{:ok, compiled_document}` - Compiled document as binary
    * `{:error, reason}` - Compilation failure
  """
  @spec compile_template(String.t(), map(), Keyword.t()) :: {:ok, binary()} | {:error, term()}
  def compile_template(template_name, data, opts \\ []) do
    GenServer.call(__MODULE__, {:compile_template, template_name, data, opts}, :timer.seconds(60))
  end

  @doc """
  Clears the template cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @doc """
  Lists all available templates.
  """
  @spec list_templates() :: {:ok, [String.t()]}
  def list_templates do
    GenServer.call(__MODULE__, :list_templates)
  end

  @doc """
  Generates a Typst template from an AshReports DSL definition and compiles it with data.

  This function creates a dynamic template from the report's DSL structure,
  bypassing the file-based template system entirely.

  ## Parameters

    * `report` - AshReports.Report struct containing the DSL definition
    * `data` - Data to pass to the generated template
    * `opts` - Generation and compilation options:
      * `:format` - Output format (:pdf, :png, :svg)
      * `:theme` - Theme name for styling
      * `:debug` - Include debug comments in template

  ## Returns

    * `{:ok, compiled_document}` - Compiled document as binary
    * `{:error, reason}` - Generation or compilation failure

  ## Example

      report = AshReports.Info.report(MyDomain, :sales_report)
      data = %{records: [%{customer: "Acme Corp", amount: 1500}]}
      {:ok, pdf} = TemplateManager.compile_dsl_template(report, data)
  """
  @spec compile_dsl_template(AshReports.Report.t(), map(), Keyword.t()) ::
          {:ok, binary()} | {:error, term()}
  def compile_dsl_template(report, data, opts \\ []) do
    GenServer.call(__MODULE__, {:compile_dsl_template, report, data, opts}, :timer.seconds(60))
  end

  @doc """
  Generates a Typst template from an AshReports DSL definition without compiling.

  Useful for debugging, template inspection, or custom compilation workflows.

  ## Parameters

    * `report` - AshReports.Report struct containing the DSL definition
    * `opts` - Generation options:
      * `:theme` - Theme name for styling
      * `:debug` - Include debug comments in template

  ## Returns

    * `{:ok, template_string}` - Generated Typst template as string
    * `{:error, reason}` - Generation failure
  """
  @spec generate_dsl_template(AshReports.Report.t(), Keyword.t()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_dsl_template(report, opts \\ []) do
    GenServer.call(__MODULE__, {:generate_dsl_template, report, opts})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Create ETS table for caching
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])

    template_dir = get_template_dir()

    # Set up file watcher for development
    if should_enable_hot_reload?() do
      setup_file_watcher(template_dir)
    end

    state = %{
      template_dir: template_dir,
      cache_ttl: Keyword.get(opts, :cache_ttl, @default_cache_ttl),
      hot_reload: should_enable_hot_reload?(),
      watcher_pid: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:load_template, template_name, opts}, _from, state) do
    force_reload = Keyword.get(opts, :force_reload, false)

    result =
      if force_reload do
        load_template_from_disk(template_name, state)
      else
        load_template_with_cache(template_name, state)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:compile_template, template_name, data, opts}, _from, state) do
    with {:ok, template} <- load_template_with_cache(template_name, state),
         {:ok, rendered} <- render_template_with_data(template, data),
         {:ok, compiled} <- BinaryWrapper.compile(rendered, opts) do
      {:reply, {:ok, compiled}, state}
    else
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(@table_name)
    Logger.info("Typst template cache cleared")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:list_templates, _from, state) do
    templates = list_template_files(state.template_dir)
    {:reply, {:ok, templates}, state}
  end

  @impl true
  def handle_call({:compile_dsl_template, report, data, opts}, _from, state) do
    with {:ok, template} <- DSLGenerator.generate_template(report, opts),
         {:ok, rendered} <- render_template_with_data(template, data),
         {:ok, compiled} <- BinaryWrapper.compile(rendered, opts) do
      {:reply, {:ok, compiled}, state}
    else
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:generate_dsl_template, report, opts}, _from, state) do
    result = DSLGenerator.generate_template(report, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_info({:file_event, _watcher, {path, events}}, state) do
    if :modified in events or :created in events do
      handle_template_change(path, state)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp get_template_dir do
    config = Application.get_env(:ash_reports, :typst, [])
    Keyword.get(config, :template_dir, "priv/typst_templates")
  end

  defp should_enable_hot_reload? do
    if Mix.env() == :dev do
      config = Application.get_env(:ash_reports, :typst, [])
      Keyword.get(config, :hot_reload, false)
    else
      false
    end
  end

  defp setup_file_watcher(template_dir) do
    case Code.ensure_loaded?(FileSystem) do
      true ->
        {:ok, watcher} = FileSystem.start_link(dirs: [template_dir])
        FileSystem.subscribe(watcher)
        Logger.info("Typst template hot-reloading enabled for #{template_dir}")
        watcher

      false ->
        Logger.warning("FileSystem not available, hot-reloading disabled")
        nil
    end
  end

  defp load_template_with_cache(template_name, state) do
    current_time = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, template_name) do
      [{^template_name, content, expiry}] when expiry > current_time ->
        {:ok, content}

      _ ->
        # Cache miss or expired, load from disk
        case load_template_from_disk(template_name, state) do
          {:ok, content} = result ->
            cache_template(template_name, content, state.cache_ttl)
            result

          error ->
            error
        end
    end
  end

  defp load_template_from_disk(template_name, state) do
    template_path = build_template_path(template_name, state.template_dir)

    case File.read(template_path) do
      {:ok, content} ->
        Logger.debug("Loaded template #{template_name} from disk")
        {:ok, content}

      {:error, :enoent} ->
        {:error, {:template_not_found, template_name}}

      {:error, reason} ->
        {:error, {:template_read_error, reason}}
    end
  end

  defp build_template_path(template_name, template_dir) do
    # Support nested templates
    safe_name =
      template_name
      # Prevent directory traversal
      |> String.replace("..", "")
      |> String.trim_leading("/")

    Path.join(template_dir, "#{safe_name}.typ")
  end

  defp cache_template(template_name, content, ttl) do
    expiry = System.monotonic_time(:millisecond) + ttl
    :ets.insert(@table_name, {template_name, content, expiry})
  end

  defp handle_template_change(path, _state) do
    # Extract template name from path
    template_name = Path.basename(path, ".typ")

    # Invalidate cache for this template
    :ets.delete(@table_name, template_name)

    Logger.info("Template #{template_name} changed, cache invalidated")
  end

  defp render_template_with_data(template, data) do
    # For now, simple string replacement
    # In the future, this could use a more sophisticated templating engine
    rendered =
      template
      |> String.replace("{{data}}", inspect(data))

    {:ok, rendered}
  end

  defp list_template_files(template_dir) do
    case File.ls(template_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".typ"))
        |> Enum.map(&Path.basename(&1, ".typ"))

      {:error, _} ->
        []
    end
  end
end
