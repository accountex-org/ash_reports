defmodule AshReportsDemo do
  @moduledoc """
  Public API for AshReports Demo application.

  Provides convenient functions for working with the demonstration
  invoicing system, including data generation, report execution,
  and interactive demo capabilities.

  ## Quick Start

  Generate sample data and run reports:

      # Generate realistic business data
      AshReportsDemo.generate_sample_data(:medium)
      
      # Run customer summary report
      AshReportsDemo.run_report(:customer_summary, %{}, format: :html)
      
      # Run financial summary with date range
      AshReportsDemo.run_report(:financial_summary, %{
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-12-31]
      }, format: :pdf)

  ## Interactive Demo

      # Start interactive demonstration
      AshReportsDemo.start_demo()
      
      # Run performance benchmarks
      AshReportsDemo.benchmark_reports()

  """

  alias AshReportsDemo.{DataGenerator, Domain}

  @doc """
  Generate sample business data for demonstration.

  ## Options

  - `:small` - 10 customers, 50 products, 25 invoices
  - `:medium` - 100 customers, 200 products, 500 invoices  
  - `:large` - 1000 customers, 2000 products, 10000 invoices

  ## Examples

      AshReportsDemo.generate_sample_data(:medium)
      AshReportsDemo.generate_sample_data(:large)

  """
  @spec generate_sample_data(atom()) :: :ok | {:error, String.t()}
  def generate_sample_data(volume \\ :medium) do
    case DataGenerator.generate_sample_data(volume) do
      :ok -> :ok
      {:error, reason} -> {:error, "Data generation failed: #{reason}"}
    end
  end

  @doc """
  Run a report with specified parameters and format.

  ## Examples

      # Customer summary in HTML
      AshReportsDemo.run_report(:customer_summary, %{}, format: :html)
      
      # Financial summary with date range in PDF  
      AshReportsDemo.run_report(:financial_summary, %{
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-12-31]
      }, format: :pdf)

  """
  @spec run_report(atom(), map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def run_report(report_name, parameters \\ %{}, opts \\ []) do
    format = Keyword.get(opts, :format, :html)

    case AshReports.Runner.run_report(Domain, report_name, parameters, format: format) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        error_message =
          case reason do
            %{stage: stage, reason: inner_reason} ->
              "Report execution failed at #{stage}: #{inspect(inner_reason)}"

            _ ->
              "Report execution failed: #{inspect(reason)}"
          end

        {:error, error_message}
    end
  end

  @doc """
  List all available reports in the demo.
  """
  @spec list_reports() :: [atom()]
  def list_reports do
    AshReports.Info.reports(Domain)
    |> Enum.map(& &1.name)
  end

  @doc """
  Get information about the current demo data.
  """
  @spec data_summary() :: map()
  def data_summary do
    %{
      customers: count_records_by_table(:demo_customers),
      products: count_records_by_table(:demo_products),
      invoices: count_records_by_table(:demo_invoices),
      generated_at: DateTime.utc_now()
    }
  end

  @doc """
  Reset all demo data.
  """
  @spec reset_data() :: :ok
  def reset_data do
    DataGenerator.reset_data()
  end

  @doc """
  Start interactive demo session.
  """
  @spec start_demo() :: :ok
  def start_demo do
    AshReportsDemo.InteractiveDemo.start()
  end

  @doc """
  Run performance benchmarks on report generation.
  """
  @spec benchmark_reports(keyword()) :: :ok
  def benchmark_reports(opts \\ []) do
    data_size = Keyword.get(opts, :data_size, :medium)

    # Generate fresh data for benchmarking
    generate_sample_data(data_size)

    # Run benchmarks on available reports
    reports = list_reports()
    formats = [:html, :pdf, :json]

    IO.puts("Running performance benchmarks...")
    IO.puts("Data size: #{data_size}")
    IO.puts("Reports: #{Enum.join(reports, ", ")}")
    IO.puts("Formats: #{Enum.join(formats, ", ")}")

    benchmark_results =
      for report <- reports, format <- formats do
        {time, result} =
          :timer.tc(fn ->
            run_report(report, %{}, format: format)
          end)

        case result do
          {:ok, report_result} ->
            {report, format, :success, time, byte_size(report_result.content)}

          {:error, _reason} ->
            {report, format, :error, time, 0}
        end
      end

    # Display results
    IO.puts("\nBenchmark Results:")

    Enum.each(benchmark_results, fn {report, format, status, time, size} ->
      time_ms = time / 1000
      size_kb = size / 1024

      IO.puts(
        "  #{report} (#{format}): #{status} - #{Float.round(time_ms, 2)}ms - #{Float.round(size_kb, 2)}KB"
      )
    end)

    :ok
  end

  # Private helper functions

  defp count_records_by_table(table_name) do
    :ets.info(table_name, :size) || 0
  rescue
    _ -> 0
  end
end
