defmodule AshReports.RenderCommand do
  @moduledoc """
  Command pattern implementation for render operations.

  This module provides a command pattern for encapsulating render operations,
  enabling features like queuing, logging, undo operations, and batch processing.

  ## Design Benefits

  - **Command Pattern**: Encapsulate render operations as objects
  - **Queueing**: Support for deferred execution and batch processing
  - **Logging**: Built-in operation tracking and audit trails
  - **Undo/Redo**: Potential for reversible operations
  - **Composition**: Combine multiple commands into complex workflows

  ## Usage

      # Create and execute a simple render command
      command = RenderCommand.new(:render_report, %{
        domain: MyDomain,
        report: :sales_report,
        format: :pdf,
        params: %{year: 2024}
      })

      {:ok, result} = RenderCommand.execute(command)

      # Create a batch of commands
      commands = [
        RenderCommand.new(:render_report, %{report: :sales, format: :pdf}),
        RenderCommand.new(:render_report, %{report: :sales, format: :html}),
        RenderCommand.new(:render_report, %{report: :inventory, format: :json})
      ]

      {:ok, results} = RenderCommand.execute_batch(commands)

  """

  alias AshReports.Renderer

  @typedoc "Command type"
  @type command_type ::
          :render_report
          | :format_data
          | :generate_pdf
          | :export_json
          | :validate_report

  @typedoc "Command parameters"
  @type command_params :: map()

  @typedoc "Command execution result"
  @type command_result :: {:ok, term()} | {:error, term()}

  @typedoc "Command state"
  @type command_state :: %{
          id: String.t(),
          type: command_type(),
          params: command_params(),
          status: command_status(),
          created_at: DateTime.t(),
          executed_at: DateTime.t() | nil,
          result: term() | nil,
          metadata: map()
        }

  @typedoc "Command execution status"
  @type command_status :: :pending | :executing | :completed | :failed | :cancelled

  defstruct [
    :id,
    :type,
    :params,
    :created_at,
    status: :pending,
    executed_at: nil,
    result: nil,
    metadata: %{}
  ]

  @doc """
  Creates a new render command.

  ## Parameters

  - `type` - The type of command to create
  - `params` - Parameters for the command execution

  ## Examples

      iex> command = AshReports.RenderCommand.new(:render_report, %{
      ...>   domain: MyDomain,
      ...>   report: :sales_report,
      ...>   format: :pdf
      ...> })
      iex> command.type
      :render_report

  """
  @spec new(command_type(), command_params()) :: command_state()
  def new(type, params) when is_atom(type) and is_map(params) do
    %__MODULE__{
      id: generate_command_id(),
      type: type,
      params: params,
      status: :pending,
      created_at: DateTime.utc_now(),
      metadata: %{
        version: "1.0",
        priority: :normal
      }
    }
  end

  @doc """
  Executes a render command.

  ## Parameters

  - `command` - The command to execute

  ## Examples

      command = RenderCommand.new(:render_report, %{...})
      {:ok, result} = RenderCommand.execute(command)

  """
  @spec execute(command_state()) :: command_result()
  def execute(%__MODULE__{status: :pending} = command) do
    updated_command = %{command | status: :executing, executed_at: DateTime.utc_now()}

    try do
      result = execute_command_by_type(updated_command)
      final_command = %{updated_command | status: :completed, result: result}
      log_command_execution(final_command)
      {:ok, result}
    rescue
      error ->
        failed_command = %{updated_command | status: :failed, result: {:error, error}}
        log_command_execution(failed_command)
        {:error, "Command execution failed: #{Exception.message(error)}"}
    end
  end

  def execute(%__MODULE__{status: status}) do
    {:error, "Command cannot be executed in status: #{status}"}
  end

  @doc """
  Executes multiple commands in batch.

  ## Parameters

  - `commands` - List of commands to execute
  - `options` - Batch execution options

  ## Options

  - `:parallel` - Execute commands in parallel (default: false)
  - `:continue_on_error` - Continue batch even if individual commands fail (default: true)
  - `:max_concurrency` - Maximum concurrent executions for parallel mode (default: 4)

  ## Examples

      commands = [command1, command2, command3]
      {:ok, results} = RenderCommand.execute_batch(commands, parallel: true)

  """
  @spec execute_batch([command_state()], keyword()) ::
          {:ok, [command_result()]} | {:error, term()}
  def execute_batch(commands, options \\ []) when is_list(commands) do
    parallel = Keyword.get(options, :parallel, false)
    continue_on_error = Keyword.get(options, :continue_on_error, true)

    if parallel do
      execute_batch_parallel(commands, options)
    else
      execute_batch_sequential(commands, continue_on_error)
    end
  end

  @doc """
  Validates a command before execution.

  ## Parameters

  - `command` - The command to validate

  ## Examples

      command = RenderCommand.new(:render_report, %{...})
      :ok = RenderCommand.validate(command)

  """
  @spec validate(command_state()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = command) do
    with :ok <- validate_command_type(command.type),
         :ok <- validate_command_params(command.params, command.type) do
      :ok
    else
      {:error, reason} -> {:error, "Command validation failed: #{reason}"}
    end
  end

  @doc """
  Gets the status of a command.

  ## Examples

      status = RenderCommand.status(command)

  """
  @spec status(command_state()) :: command_status()
  def status(%__MODULE__{} = command), do: command.status

  @doc """
  Cancels a pending command.

  ## Examples

      {:ok, cancelled_command} = RenderCommand.cancel(command)

  """
  @spec cancel(command_state()) :: {:ok, command_state()} | {:error, term()}
  def cancel(%__MODULE__{status: :pending} = command) do
    cancelled_command = %{command | status: :cancelled}
    log_command_execution(cancelled_command)
    {:ok, cancelled_command}
  end

  def cancel(%__MODULE__{status: status}) do
    {:error, "Cannot cancel command in status: #{status}"}
  end

  # Private implementation functions

  defp generate_command_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp execute_command_by_type(%{type: :render_report} = command) do
    %{domain: domain, report: report_name, format: format} = command.params
    params = Map.get(command.params, :params, %{})

    # This would integrate with the actual rendering system
    case Renderer.render(domain, report_name, params, format: format) do
      {:ok, result} -> result
      {:error, reason} -> raise "Render failed: #{inspect(reason)}"
    end
  end

  defp execute_command_by_type(%{type: :format_data} = command) do
    %{data: data, format_specs: specs} = command.params
    locale = Map.get(command.params, :locale, "en")

    # This would use the formatter system
    case AshReports.Formatter.format_data(data, specs, locale: locale) do
      {:ok, result} -> result
      {:error, reason} -> raise "Format failed: #{inspect(reason)}"
    end
  end

  defp execute_command_by_type(%{type: :validate_report} = command) do
    %{domain: domain, report: report_name} = command.params

    # This would use the validation system
    case AshReports.Info.report(domain, report_name) do
      nil -> raise "Report not found: #{report_name}"
      report -> %{valid: true, report: report}
    end
  end

  defp execute_command_by_type(%{type: type}) do
    raise "Unsupported command type: #{type}"
  end

  defp execute_batch_sequential(commands, continue_on_error) do
    results =
      Enum.reduce_while(commands, [], fn command, acc ->
        result = execute(command)
        handle_batch_command_result(result, continue_on_error, acc)
      end)

    case results do
      {:error, _reason} = error -> error
      results_list -> {:ok, Enum.reverse(results_list)}
    end
  end

  defp execute_batch_parallel(commands, options) do
    max_concurrency = Keyword.get(options, :max_concurrency, 4)

    tasks =
      commands
      |> Enum.chunk_every(max_concurrency)
      |> Enum.flat_map(fn chunk ->
        Enum.map(chunk, &Task.async(fn -> execute(&1) end))
      end)

    results = Task.await_many(tasks, 30_000)
    {:ok, results}
  rescue
    error -> {:error, "Parallel execution failed: #{Exception.message(error)}"}
  end

  defp validate_command_type(type)
       when type in [:render_report, :format_data, :generate_pdf, :export_json, :validate_report] do
    :ok
  end

  defp validate_command_type(type) do
    {:error, "Invalid command type: #{type}"}
  end

  defp validate_command_params(params, :render_report) do
    required_keys = [:domain, :report, :format]

    case Enum.find(required_keys, &(not Map.has_key?(params, &1))) do
      nil -> :ok
      missing_key -> {:error, "Missing required parameter: #{missing_key}"}
    end
  end

  defp validate_command_params(params, :format_data) do
    required_keys = [:data, :format_specs]

    case Enum.find(required_keys, &(not Map.has_key?(params, &1))) do
      nil -> :ok
      missing_key -> {:error, "Missing required parameter: #{missing_key}"}
    end
  end

  defp validate_command_params(_params, _type), do: :ok

  defp log_command_execution(%__MODULE__{} = command) do
    # In a real implementation, this would log to a proper logging system
    # For now, we'll use a simple process-based log
    log_entry = %{
      command_id: command.id,
      type: command.type,
      status: command.status,
      executed_at: command.executed_at,
      duration: calculate_duration(command)
    }

    put_command_log(command.id, log_entry)
  end

  defp calculate_duration(%{created_at: _created, executed_at: nil}), do: nil

  defp calculate_duration(%{created_at: created, executed_at: executed}) do
    DateTime.diff(executed, created, :millisecond)
  end

  defp handle_batch_command_result({:ok, result}, _continue_on_error, acc) do
    {:cont, [{:ok, result} | acc]}
  end

  defp handle_batch_command_result({:error, reason} = error, continue_on_error, acc) do
    if continue_on_error do
      {:cont, [error | acc]}
    else
      {:halt, {:error, "Batch execution stopped: #{reason}"}}
    end
  end

  defp put_command_log(command_id, log_entry) do
    # Simple process-based logging for demonstration
    current_logs = Process.get(:command_logs, [])
    Process.put(:command_logs, [{command_id, log_entry} | current_logs])
  end
end
