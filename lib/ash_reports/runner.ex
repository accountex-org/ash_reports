defmodule AshReports.Runner do
  @moduledoc """
  Executes reports by fetching data and processing it through the band hierarchy.

  This module will be fully implemented in Phase 2 with the query system.

  ## Telemetry Events

  This module emits the following telemetry events:

  - `[:ash_reports, :runner, :run_report, :start]` - Report execution started
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{domain: module(), report_name: atom(), format: atom()}`

  - `[:ash_reports, :runner, :run_report, :stop]` - Report execution completed
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{domain: module(), report_name: atom(), format: atom(), record_count: integer()}`

  - `[:ash_reports, :runner, :run_report, :exception]` - Report execution failed
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{domain: module(), report_name: atom(), format: atom(), error: term(), stage: atom()}`

  ### Pipeline Stage Events

  - `[:ash_reports, :runner, :data_loading, :start]` / `:stop` / `:exception`
  - `[:ash_reports, :runner, :context_building, :start]` / `:stop` / `:exception`
  - `[:ash_reports, :runner, :rendering, :start]` / `:stop` / `:exception`

  ## Example Telemetry Handler

      :telemetry.attach(
        "report-timing",
        [:ash_reports, :runner, :run_report, :stop],
        fn _event, measurements, metadata, _config ->
          IO.puts("Report \#{metadata.report_name} completed in \#{measurements.duration}ms")
        end,
        nil
      )
  """

  @doc """
  Runs a report with the given parameters and options.

  This is a placeholder that will be implemented in Phase 2.
  """
  @spec run(module(), map(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def run(report_module, params \\ %{}, opts \\ []) do
    # Placeholder implementation
    # In Phase 2, this will:
    # 1. Validate parameters
    # 2. Build and execute Ash queries
    # 3. Process data through bands
    # 4. Calculate variables and aggregates
    # 5. Return structured report data

    report = report_module.definition()

    {:ok,
     %{
       report: report,
       params: params,
       data: [],
       metadata: %{
         generated_at: DateTime.utc_now(),
         format: opts[:format] || :html
       }
     }}
  end

  @doc """
  Runs a complete report with real data processing and rendering.

  ## Parameters
  - domain: The Ash domain containing the report definition
  - report_name: The name of the report to run (atom)
  - params: Parameters to pass to the report (map)
  - opts: Options including :format, :streaming, :performance (keyword list)

  ## Returns
  {:ok, %{content: binary(), metadata: map(), format: atom()}} | {:error, reason}

  ## Examples

      # Run customer summary report in HTML format
      {:ok, result} = AshReports.Runner.run_report(
        MyApp.Domain, 
        :customer_summary, 
        %{region: "CA"}, 
        format: :html
      )
      
      # Run financial report with streaming for large datasets
      {:ok, result} = AshReports.Runner.run_report(
        MyApp.Domain,
        :financial_summary,
        %{period_type: "monthly"},
        format: :json,
        streaming: true
      )
  """
  @spec run_report(module(), atom(), map(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def run_report(domain, report_name, params \\ %{}, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)
    format = Keyword.get(opts, :format, :html)

    # Emit telemetry start event
    :telemetry.execute(
      [:ash_reports, :runner, :run_report, :start],
      %{system_time: System.system_time()},
      %{domain: domain, report_name: report_name, format: format}
    )

    result =
      with {:ok, data_result} <- load_report_data(domain, report_name, params, opts),
           {:ok, render_context} <- build_render_context(data_result, opts),
           {:ok, rendered_result} <- render_report(render_context, format, opts) do
        end_time = System.monotonic_time(:microsecond)
        execution_time_ms = div(end_time - start_time, 1000)

        {:ok,
         %{
           content: rendered_result.content,
           metadata:
             build_pipeline_metadata(
               data_result.metadata,
               rendered_result.metadata,
               execution_time_ms,
               format
             ),
           format: format,
           # Include data for debugging (can be disabled in production)
           data: if(Keyword.get(opts, :include_debug_data, true), do: data_result, else: nil),
           record_count: Map.get(data_result.metadata, :record_count, 0)
         }}
      else
        {:error, {stage, reason}} ->
          handle_pipeline_error(stage, reason, opts)

        {:error, reason} ->
          handle_pipeline_error(:unknown, reason, opts)
      end

    # Emit telemetry stop or exception event
    case result do
      {:ok, report_result} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :run_report, :stop],
          %{duration: duration},
          %{
            domain: domain,
            report_name: report_name,
            format: format,
            record_count: report_result.record_count
          }
        )

        result

      {:error, error_details} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :run_report, :exception],
          %{duration: duration},
          %{
            domain: domain,
            report_name: report_name,
            format: format,
            error: error_details.reason,
            stage: error_details.stage
          }
        )

        result
    end
  end

  # Enhanced helper functions for the pipeline

  defp load_report_data(domain, report_name, params, _opts) do
    start_time = System.monotonic_time(:microsecond)

    :telemetry.execute(
      [:ash_reports, :runner, :data_loading, :start],
      %{system_time: System.system_time()},
      %{domain: domain, report_name: report_name}
    )

    result =
      case AshReports.DataLoader.load_report(domain, report_name, params) do
        {:ok, data_result} -> {:ok, data_result}
        {:error, reason} -> {:error, {:data_loading, reason}}
      end

    case result do
      {:ok, data_result} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :data_loading, :stop],
          %{duration: duration},
          %{
            domain: domain,
            report_name: report_name,
            record_count: Map.get(data_result.metadata, :record_count, 0)
          }
        )

        result

      {:error, {_stage, reason}} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :data_loading, :exception],
          %{duration: duration},
          %{domain: domain, report_name: report_name, error: reason}
        )

        result
    end
  end

  defp build_render_context(data_result, opts) do
    start_time = System.monotonic_time(:microsecond)

    :telemetry.execute(
      [:ash_reports, :runner, :context_building, :start],
      %{system_time: System.system_time()},
      %{}
    )

    result =
      try do
        config = extract_render_config(opts)

        context =
          AshReports.RenderContext.new(
            data_result.report || %{},
            data_result,
            config
          )

        {:ok, context}
      rescue
        error -> {:error, {:context_building, Exception.message(error)}}
      end

    case result do
      {:ok, _context} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :context_building, :stop],
          %{duration: duration},
          %{}
        )

        result

      {:error, {_stage, reason}} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :context_building, :exception],
          %{duration: duration},
          %{error: reason}
        )

        result
    end
  end

  defp render_report(context, format, opts) do
    start_time = System.monotonic_time(:microsecond)

    :telemetry.execute(
      [:ash_reports, :runner, :rendering, :start],
      %{system_time: System.system_time()},
      %{format: format}
    )

    result =
      case get_renderer_for_format(format) do
        {:ok, renderer} ->
          case renderer.render_with_context(context, opts) do
            {:ok, result} -> {:ok, result}
            {:error, reason} -> {:error, {:rendering, reason}}
          end

        {:error, reason} ->
          {:error, {:renderer_selection, reason}}
      end

    case result do
      {:ok, rendered_result} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :rendering, :stop],
          %{duration: duration},
          %{
            format: format,
            content_size: byte_size(rendered_result.content || "")
          }
        )

        result

      {:error, {stage, reason}} ->
        duration = div(System.monotonic_time(:microsecond) - start_time, 1000)

        :telemetry.execute(
          [:ash_reports, :runner, :rendering, :exception],
          %{duration: duration},
          %{format: format, error: reason, stage: stage}
        )

        result
    end
  end

  defp extract_render_config(opts) do
    %{
      format: Keyword.get(opts, :format, :html),
      locale: Keyword.get(opts, :locale, "en"),
      timezone: Keyword.get(opts, :timezone, "UTC"),
      page_size: Keyword.get(opts, :page_size, {8.5, 11}),
      margins: Keyword.get(opts, :margins, {0.5, 0.5, 0.5, 0.5}),
      streaming: Keyword.get(opts, :streaming, false)
    }
  end

  defp build_pipeline_metadata(data_metadata, render_metadata, execution_time_ms, format) do
    base_metadata = %{
      pipeline_completed_at: DateTime.utc_now(),
      execution_time_ms: execution_time_ms,
      format: format,
      record_count: Map.get(data_metadata, :record_count, 0),
      pipeline_version: "8.3"
    }

    merged_metadata =
      data_metadata
      |> Map.merge(render_metadata || %{})
      |> Map.merge(base_metadata)

    merged_metadata
  end

  defp handle_pipeline_error(stage, reason, _opts) do
    error_details = %{
      stage: stage,
      reason: reason,
      timestamp: DateTime.utc_now(),
      suggested_action: suggest_action_for_error(stage, reason),
      pipeline_version: "8.3"
    }

    {:error, error_details}
  end

  defp suggest_action_for_error(:data_loading, _reason) do
    "Check report definition exists and domain configuration. Verify data exists and parameters are valid."
  end

  defp suggest_action_for_error(:context_building, _reason) do
    "Check render context configuration and data structure integrity."
  end

  defp suggest_action_for_error(:renderer_selection, _reason) do
    "Verify format is supported. Valid formats: :html, :pdf, :heex, :json"
  end

  defp suggest_action_for_error(:rendering, _reason) do
    "Check renderer configuration and template validity. Verify data structure matches renderer expectations."
  end

  defp suggest_action_for_error(_, _) do
    "Review error details and check system configuration. Ensure all dependencies are properly configured."
  end

  defp get_renderer_for_format(:html), do: {:ok, AshReports.HtmlRenderer}
  defp get_renderer_for_format(:pdf), do: {:ok, AshReports.PdfRenderer}
  defp get_renderer_for_format(:heex), do: {:ok, AshReports.HeexRenderer}
  defp get_renderer_for_format(:json), do: {:ok, AshReports.JsonRenderer}
  defp get_renderer_for_format(format), do: {:error, "Unknown format: #{format}"}
end
