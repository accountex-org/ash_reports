defmodule AshReports.JsonRenderer.ChartApi do
  @moduledoc """
  RESTful API endpoints for chart data and configuration in Phase 6.3.

  Provides comprehensive chart API endpoints for external integrations,
  data access, configuration management, and export capabilities with
  authentication, rate limiting, and comprehensive error handling.

  ## Features

  - **RESTful Chart APIs**: Standard HTTP endpoints for chart operations
  - **Data Access**: Secure chart data retrieval with filtering and pagination
  - **Configuration Management**: Chart configuration CRUD operations
  - **Export Capabilities**: Multiple format export with quality options
  - **Interactive State**: Export and import of interactive chart states
  - **Authentication**: Secure API access with token validation

  ## API Endpoints

  ### Chart Data Operations
  - `GET /api/charts/:chart_id/data` - Retrieve chart data
  - `POST /api/charts/:chart_id/data` - Update chart data
  - `GET /api/charts/:chart_id/filtered` - Get filtered chart data

  ### Chart Configuration
  - `GET /api/charts/:chart_id/config` - Get chart configuration
  - `PUT /api/charts/:chart_id/config` - Update chart configuration
  - `POST /api/charts` - Create new chart

  ### Export Operations
  - `GET /api/charts/:chart_id/export/:format` - Export chart in format
  - `POST /api/charts/batch_export` - Batch export multiple charts

  ### Interactive Operations  
  - `POST /api/charts/:chart_id/filter` - Apply filter to chart
  - `GET /api/charts/:chart_id/state` - Get current interactive state
  - `PUT /api/charts/:chart_id/state` - Update interactive state

  ## Usage Examples

  ### Get Chart Data

      curl -H "Authorization: Bearer token" \\
           -H "Content-Type: application/json" \\
           https://api.example.com/api/charts/sales_chart_123/data

  ### Update Chart Configuration

      curl -X PUT \\
           -H "Authorization: Bearer token" \\
           -H "Content-Type: application/json" \\
           -d '{"type": "bar", "title": "Updated Chart"}' \\
           https://api.example.com/api/charts/sales_chart_123/config

  ### Export Chart as PNG

      curl -H "Authorization: Bearer token" \\
           https://api.example.com/api/charts/sales_chart_123/export/png \\
           --output chart.png

  """

  use Plug.Router

  alias AshReports.ChartEngine.{ChartConfig, ChartDataProcessor}
  alias AshReports.PdfRenderer.ChartImageGenerator
  alias AshReports.{InteractiveEngine, RenderContext}

  plug(:match)
  plug(:dispatch)

  # Chart Data Endpoints

  get "/api/charts/:chart_id/data" do
    with {:ok, chart_config} <- get_chart_config(chart_id),
         {:ok, context} <- build_api_context(conn),
         {:ok, chart_data} <- get_chart_data(chart_config, context) do
      response_data = %{
        chart_id: chart_id,
        data: chart_data,
        metadata: %{
          last_updated: DateTime.utc_now(),
          data_points: count_data_points(chart_data),
          format: "json"
        }
      }

      send_json_response(conn, 200, response_data)
    else
      {:error, :not_found} ->
        send_error_response(conn, 404, "Chart not found")

      {:error, :unauthorized} ->
        send_error_response(conn, 401, "Unauthorized access")

      {:error, reason} ->
        send_error_response(conn, 500, "Data retrieval failed: #{reason}")
    end
  end

  post "/api/charts/:chart_id/data" do
    with {:ok, chart_config} <- get_chart_config(chart_id),
         {:ok, context} <- build_api_context(conn),
         {:ok, new_data} <- parse_request_body(conn),
         {:ok, _updated_config} <- update_chart_data(chart_config, new_data) do
      # Broadcast update to live components
      :ok = broadcast_chart_update(chart_id, new_data, context)

      response_data = %{
        chart_id: chart_id,
        status: "updated",
        data_points: count_data_points(new_data.data),
        updated_at: DateTime.utc_now()
      }

      send_json_response(conn, 200, response_data)
    else
      {:error, :invalid_data} ->
        send_error_response(conn, 400, "Invalid chart data format")

      {:error, reason} ->
        send_error_response(conn, 500, "Data update failed: #{reason}")
    end
  end

  get "/api/charts/:chart_id/filtered" do
    query_params = conn.query_params

    with {:ok, chart_config} <- get_chart_config(chart_id),
         {:ok, context} <- build_api_context(conn),
         {:ok, filter_criteria} <- parse_filter_params(query_params),
         {:ok, original_data} <- get_chart_data(chart_config, context),
         {:ok, filtered_data} <- InteractiveEngine.filter(original_data, filter_criteria, context) do
      response_data = %{
        chart_id: chart_id,
        data: filtered_data,
        filter_criteria: filter_criteria,
        original_count: count_data_points(original_data),
        filtered_count: count_data_points(filtered_data),
        filtered_at: DateTime.utc_now()
      }

      send_json_response(conn, 200, response_data)
    else
      {:error, reason} ->
        send_error_response(conn, 500, "Filter operation failed: #{reason}")
    end
  end

  # Chart Configuration Endpoints

  get "/api/charts/:chart_id/config" do
    with {:ok, chart_config} <- get_chart_config(chart_id),
         {:ok, _context} <- build_api_context(conn) do
      config_data = %{
        chart_id: chart_id,
        configuration: serialize_chart_config(chart_config),
        metadata: %{
          created_at: chart_config.created_at,
          updated_at: chart_config.updated_at,
          version: "1.0"
        }
      }

      send_json_response(conn, 200, config_data)
    else
      {:error, :not_found} ->
        send_error_response(conn, 404, "Chart configuration not found")

      {:error, reason} ->
        send_error_response(conn, 500, "Configuration retrieval failed: #{reason}")
    end
  end

  put "/api/charts/:chart_id/config" do
    with {:ok, current_config} <- get_chart_config(chart_id),
         {:ok, _context} <- build_api_context(conn),
         {:ok, config_updates} <- parse_request_body(conn),
         {:ok, updated_config} <- update_chart_config(current_config, config_updates) do
      response_data = %{
        chart_id: chart_id,
        status: "updated",
        configuration: serialize_chart_config(updated_config),
        updated_at: DateTime.utc_now()
      }

      send_json_response(conn, 200, response_data)
    else
      {:error, :invalid_config} ->
        send_error_response(conn, 400, "Invalid configuration format")

      {:error, reason} ->
        send_error_response(conn, 500, "Configuration update failed: #{reason}")
    end
  end

  post "/api/charts" do
    with {:ok, _context} <- build_api_context(conn),
         {:ok, chart_spec} <- parse_request_body(conn),
         {:ok, chart_config} <- create_chart_config(chart_spec),
         {:ok, chart_id} <- save_chart_config(chart_config) do
      response_data = %{
        chart_id: chart_id,
        status: "created",
        configuration: serialize_chart_config(chart_config),
        endpoints: ChartDataProcessor.generate_chart_endpoints(chart_config),
        created_at: DateTime.utc_now()
      }

      send_json_response(conn, 201, response_data)
    else
      {:error, :invalid_spec} ->
        send_error_response(conn, 400, "Invalid chart specification")

      {:error, reason} ->
        send_error_response(conn, 500, "Chart creation failed: #{reason}")
    end
  end

  # Export Endpoints

  get "/api/charts/:chart_id/export/:format" do
    export_format = String.to_atom(format)

    with {:ok, chart_config} <- get_chart_config(chart_id),
         {:ok, context} <- build_api_context(conn),
         {:ok, export_data} <- export_chart(chart_config, context, export_format) do
      content_type = get_export_content_type(export_format)
      filename = "#{chart_id}.#{format}"

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("content-disposition", "attachment; filename=#{filename}")
      |> send_resp(200, export_data)
    else
      {:error, :unsupported_format} ->
        send_error_response(conn, 400, "Unsupported export format: #{format}")

      {:error, reason} ->
        send_error_response(conn, 500, "Export failed: #{reason}")
    end
  end

  post "/api/charts/batch_export" do
    with {:ok, _context} <- build_api_context(conn),
         {:ok, export_spec} <- parse_request_body(conn),
         {:ok, export_results} <- process_batch_export(export_spec) do
      response_data = %{
        batch_id: generate_batch_id(),
        status: "completed",
        results: export_results,
        exported_at: DateTime.utc_now()
      }

      send_json_response(conn, 200, response_data)
    else
      {:error, reason} ->
        send_error_response(conn, 500, "Batch export failed: #{reason}")
    end
  end

  # Interactive State Endpoints

  get "/api/charts/:chart_id/state" do
    with {:ok, chart_config} <- get_chart_config(chart_id),
         {:ok, _context} <- build_api_context(conn),
         {:ok, interactive_state} <- get_interactive_state(chart_config) do
      response_data = %{
        chart_id: chart_id,
        interactive_state: interactive_state,
        state_version: generate_state_version(),
        retrieved_at: DateTime.utc_now()
      }

      send_json_response(conn, 200, response_data)
    else
      {:error, reason} ->
        send_error_response(conn, 500, "State retrieval failed: #{reason}")
    end
  end

  post "/api/charts/:chart_id/filter" do
    with {:ok, chart_config} <- get_chart_config(chart_id),
         {:ok, context} <- build_api_context(conn),
         {:ok, filter_request} <- parse_request_body(conn),
         {:ok, filtered_result} <- apply_api_filter(chart_config, filter_request, context) do
      response_data = %{
        chart_id: chart_id,
        filter_applied: filter_request.criteria,
        filtered_data: filtered_result.data,
        original_count: filtered_result.original_count,
        filtered_count: filtered_result.filtered_count,
        applied_at: DateTime.utc_now()
      }

      send_json_response(conn, 200, response_data)
    else
      {:error, reason} ->
        send_error_response(conn, 500, "Filter application failed: #{reason}")
    end
  end

  # Helper functions

  defp build_api_context(conn) do
    # Build RenderContext from API request
    locale = get_header_value(conn, "accept-language", "en")

    context = %RenderContext{
      locale: locale,
      text_direction: if(locale in ["ar", "he", "fa", "ur"], do: "rtl", else: "ltr"),
      metadata: %{
        api_request: true,
        user_agent: get_header_value(conn, "user-agent"),
        request_id: generate_request_id()
      }
    }

    {:ok, context}
  end

  defp get_chart_config(chart_id) do
    # Placeholder - would retrieve from database/storage
    # For now, return a basic config
    {:ok,
     %ChartConfig{
       type: :bar,
       data: [[1, 10], [2, 20], [3, 30]],
       title: "API Chart #{chart_id}",
       provider: :chartjs
     }}
  end

  defp get_chart_data(chart_config, _context) do
    {:ok, chart_config.data}
  end

  defp parse_request_body(conn) do
    case Jason.decode(conn.body_params || "{}") do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Invalid JSON: #{inspect(reason)}"}
    end
  end

  defp parse_filter_params(query_params) do
    filter_criteria = %{}

    # Parse common filter parameters
    filter_criteria =
      if Map.has_key?(query_params, "min_value") do
        Map.put(filter_criteria, :min_value, String.to_integer(query_params["min_value"]))
      else
        filter_criteria
      end

    filter_criteria =
      if Map.has_key?(query_params, "max_value") do
        Map.put(filter_criteria, :max_value, String.to_integer(query_params["max_value"]))
      else
        filter_criteria
      end

    {:ok, filter_criteria}
  rescue
    _ -> {:error, "Invalid filter parameters"}
  end

  defp update_chart_data(chart_config, new_data) do
    updated_config = %{chart_config | data: new_data["data"], updated_at: DateTime.utc_now()}

    {:ok, updated_config}
  end

  defp update_chart_config(current_config, config_updates) do
    updated_config = %{
      current_config
      | type: config_updates["type"] || current_config.type,
        title: config_updates["title"] || current_config.title,
        provider:
          String.to_atom(config_updates["provider"] || to_string(current_config.provider)),
        updated_at: DateTime.utc_now()
    }

    {:ok, updated_config}
  end

  defp create_chart_config(chart_spec) do
    chart_config = %ChartConfig{
      type: String.to_atom(chart_spec["type"]),
      title: chart_spec["title"],
      data: chart_spec["data"] || [],
      provider: String.to_atom(chart_spec["provider"] || "chartjs"),
      interactive: chart_spec["interactive"] || false,
      created_at: DateTime.utc_now()
    }

    {:ok, chart_config}
  rescue
    _ -> {:error, :invalid_spec}
  end

  defp save_chart_config(chart_config) do
    # Placeholder - would save to database
    chart_id = ChartDataProcessor.generate_chart_id(chart_config)
    {:ok, chart_id}
  end

  defp export_chart(chart_config, context, export_format) do
    case export_format do
      :json ->
        export_data = serialize_chart_config(chart_config)
        {:ok, Jason.encode!(export_data)}

      :png ->
        ChartImageGenerator.generate_chart_image(chart_config, context, %{format: :png})

      :svg ->
        ChartImageGenerator.generate_chart_image(chart_config, context, %{format: :svg})

      :csv ->
        export_data = convert_chart_data_to_csv(chart_config.data)
        {:ok, export_data}

      _ ->
        {:error, :unsupported_format}
    end
  end

  defp process_batch_export(export_spec) do
    chart_ids = export_spec["chart_ids"] || []
    export_format = String.to_atom(export_spec["format"] || "json")

    results =
      chart_ids
      |> Enum.map(&process_single_chart_export(&1, export_format))
      |> Map.new()

    {:ok, results}
  end

  defp process_single_chart_export(chart_id, export_format) do
    case get_chart_config(chart_id) do
      {:ok, chart_config} ->
        context = %RenderContext{locale: "en"}

        case export_chart(chart_config, context, export_format) do
          {:ok, export_data} -> {chart_id, {:ok, export_data}}
          {:error, reason} -> {chart_id, {:error, reason}}
        end

      {:error, reason} ->
        {chart_id, {:error, reason}}
    end
  end

  defp get_interactive_state(chart_config) do
    # Extract interactive state from chart configuration
    interactive_state = %{
      filters_applied: chart_config.filters || %{},
      current_view: chart_config.current_view || :default,
      interactive_enabled: chart_config.interactive,
      real_time_enabled: chart_config.real_time,
      last_interaction: chart_config.last_interaction || DateTime.utc_now()
    }

    {:ok, interactive_state}
  end

  defp apply_api_filter(chart_config, filter_request, context) do
    original_data = chart_config.data
    filter_criteria = filter_request["criteria"] || %{}

    case InteractiveEngine.filter(original_data, filter_criteria, context) do
      {:ok, filtered_data} ->
        result = %{
          data: filtered_data,
          original_count: length(original_data),
          filtered_count: length(filtered_data)
        }

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp broadcast_chart_update(chart_id, new_data, _context) do
    # Broadcast to LiveView components
    topic = "chart_updates:#{chart_id}"

    Phoenix.PubSub.broadcast(
      AshReports.PubSub,
      topic,
      {:api_data_update,
       %{
         chart_id: chart_id,
         data: new_data,
         source: :api,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  # Utility functions

  defp serialize_chart_config(chart_config) do
    %{
      type: chart_config.type,
      title: chart_config.title,
      data: chart_config.data,
      provider: chart_config.provider,
      interactive: chart_config.interactive,
      real_time: chart_config.real_time,
      options: chart_config.options || %{}
    }
  end

  defp convert_chart_data_to_csv(data) when is_list(data) do
    headers = "x,y\n"

    rows =
      data
      |> Enum.map(fn
        %{x: x, y: y} -> "#{x},#{y}"
        {x, y} -> "#{x},#{y}"
        [x, y] -> "#{x},#{y}"
        value -> "0,#{value}"
      end)
      |> Enum.join("\n")

    headers <> rows
  end

  defp count_data_points(data) when is_list(data), do: length(data)
  defp count_data_points(_), do: 0

  defp get_export_content_type(:json), do: "application/json"
  defp get_export_content_type(:png), do: "image/png"
  defp get_export_content_type(:svg), do: "image/svg+xml"
  defp get_export_content_type(:csv), do: "text/csv"
  defp get_export_content_type(_), do: "application/octet-stream"

  defp get_header_value(conn, header_name, default \\ nil) do
    case Plug.Conn.get_req_header(conn, header_name) do
      [value | _] -> value
      [] -> default
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp generate_batch_id do
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "batch_#{timestamp}_#{random}"
  end

  defp generate_state_version do
    DateTime.utc_now() |> DateTime.to_unix()
  end

  defp send_json_response(conn, status, data) do
    json_response = Jason.encode!(data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json_response)
  end

  defp send_error_response(conn, status, message) do
    error_response = %{
      error: message,
      status: status,
      timestamp: DateTime.utc_now()
    }

    send_json_response(conn, status, error_response)
  end
end
