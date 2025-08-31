defmodule Mix.Tasks.Check do
  @moduledoc """
  Runs all code quality checks.

  ## Usage

      mix check

  This task runs:
  - Code formatting check
  - Credo static analysis
  - All tests

  ## Options

    * `--fix` - automatically fix formatting issues
    * `--skip-tests` - skip running tests
    * `--skip-credo` - skip running credo
    * `--skip-format` - skip formatting check

  ## Examples

      mix check
      mix check --fix
      mix check --skip-tests
  """

  use Mix.Task

  @shortdoc "Runs all code quality checks"

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        switches: [
          fix: :boolean,
          skip_tests: :boolean,
          skip_credo: :boolean,
          skip_format: :boolean
        ]
      )

    tasks = [
      {"Checking code formatting", &check_formatting/1},
      {"Running Credo analysis", &check_credo/1},
      {"Running tests", &check_tests/1}
    ]

    results =
      tasks
      |> Enum.filter(&should_run_task?(&1, opts))
      |> Enum.map(fn {description, task_fn} ->
        Mix.shell().info("==> #{description}")
        task_fn.(opts)
      end)

    if Enum.any?(results, &(&1 != :ok)) do
      Mix.shell().error("\n❌ Some checks failed!")
      System.halt(1)
    else
      Mix.shell().info("\n✅ All checks passed!")
    end
  end

  defp should_run_task?({"Checking code formatting", _}, opts) do
    !opts[:skip_format]
  end

  defp should_run_task?({"Running Credo analysis", _}, opts) do
    !opts[:skip_credo]
  end

  defp should_run_task?({"Running tests", _}, opts) do
    !opts[:skip_tests]
  end

  defp check_formatting(opts) do
    args = if opts[:fix], do: [], else: ["--check-formatted"]

    case Mix.Task.run("format", args) do
      :ok -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp check_credo(_opts) do
    case Mix.Task.run("credo", ["--strict"]) do
      :ok -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp check_tests(_opts) do
    case Mix.Task.run("test", []) do
      :ok -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end
end
