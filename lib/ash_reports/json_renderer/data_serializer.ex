defmodule AshReports.JsonRenderer.DataSerializer do
  @moduledoc """
  Data Serializer for AshReports JSON Renderer.

  The DataSerializer provides comprehensive data serialization capabilities,
  converting processed report data into JSON-serializable formats. It handles
  complex data types, custom encoders, and ensures proper format consistency
  for JSON output.

  ## Serialization Features

  - **Type-Safe Conversion**: Handles all common Elixir types safely
  - **Custom Encoders**: Supports Jason.Encoder protocols for complex types
  - **Date/Time Formatting**: Flexible date/time format options
  - **Number Formatting**: Precision control and locale-aware formatting
  - **Null Handling**: Configurable null value processing

  ## Data Types Supported

  - Basic types: String, Number, Boolean, Null
  - Collection types: List, Map, Tuple
  - Date/Time types: DateTime, NaiveDateTime, Date, Time
  - Custom structs with Jason.Encoder implementation
  - Ash resource structs with field extraction

  ## Usage

      # Serialize complete render context
      {:ok, serialized_data} = DataSerializer.serialize_context(context)

      # Serialize specific data elements
      {:ok, records} = DataSerializer.serialize_records(context.records)
      {:ok, variables} = DataSerializer.serialize_variables(context.variables)

      # Custom serialization options
      opts = [date_format: :iso8601, number_precision: 2, include_nulls: false]
      {:ok, data} = DataSerializer.serialize_with_options(data, opts)

  """

  alias AshReports.RenderContext

  @type serialization_options :: [
          date_format: :iso8601 | :rfc3339 | :unix | :custom,
          number_precision: non_neg_integer() | nil,
          include_nulls: boolean(),
          custom_encoders: map(),
          field_mapping: map()
        ]

  @type serialization_result :: {:ok, term()} | {:error, term()}

  @doc """
  Serializes a complete RenderContext into JSON-serializable data.

  ## Examples

      {:ok, serialized_data} = DataSerializer.serialize_context(context)

  """
  @spec serialize_context(RenderContext.t(), serialization_options()) :: serialization_result()
  def serialize_context(%RenderContext{} = context, opts \\ []) do
    with {:ok, records} <- serialize_records(context.records, opts),
         {:ok, variables} <- serialize_variables(context.variables, opts),
         {:ok, groups} <- serialize_groups(context.groups, opts),
         {:ok, metadata} <- serialize_metadata(context.metadata, opts),
         {:ok, report_info} <- serialize_report_info(context.report, opts) do
      serialized = %{
        records: records,
        variables: variables,
        groups: groups,
        metadata: metadata,
        report_info: report_info,
        processing_state: serialize_processing_state(context, opts)
      }

      {:ok, serialized}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Serializes a list of records into JSON-serializable format.

  ## Examples

      {:ok, serialized_records} = DataSerializer.serialize_records(records)

  """
  @spec serialize_records([map()], serialization_options()) :: serialization_result()
  def serialize_records(records, opts \\ []) when is_list(records) do
    records
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {record, index}, {:ok, acc} ->
      case serialize_record(record, opts) do
        {:ok, serialized_record} ->
          serialized_with_index = Map.put(serialized_record, :_index, index)
          {:cont, {:ok, [serialized_with_index | acc]}}

        {:error, reason} ->
          {:halt, {:error, {:record, index, reason}}}
      end
    end)
    |> case do
      {:ok, reversed_records} -> {:ok, Enum.reverse(reversed_records)}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Serializes a single record into JSON-serializable format.

  ## Examples

      {:ok, serialized_record} = DataSerializer.serialize_record(record)

  """
  @spec serialize_record(map(), serialization_options()) :: serialization_result()
  def serialize_record(record, opts \\ []) when is_map(record) do
    serialized =
      record
      |> Enum.into(%{}, fn {key, value} ->
        serialized_key = serialize_key(key, opts)
        serialized_value = serialize_value(value, opts)
        {serialized_key, serialized_value}
      end)

    {:ok, serialized}
  rescue
    error -> {:error, {:record_serialization_failed, error}}
  end

  @doc """
  Serializes variables into JSON-serializable format.

  ## Examples

      {:ok, serialized_vars} = DataSerializer.serialize_variables(variables)

  """
  @spec serialize_variables(map(), serialization_options()) :: serialization_result()
  def serialize_variables(variables, opts \\ []) when is_map(variables) do
    serialized =
      variables
      |> Enum.into(%{}, fn {key, value} ->
        serialized_key = serialize_key(key, opts)
        serialized_value = serialize_value(value, opts)
        {serialized_key, serialized_value}
      end)

    {:ok, serialized}
  rescue
    error -> {:error, {:variable_serialization_failed, error}}
  end

  @doc """
  Serializes groups into JSON-serializable format.

  ## Examples

      {:ok, serialized_groups} = DataSerializer.serialize_groups(groups)

  """
  @spec serialize_groups(map(), serialization_options()) :: serialization_result()
  def serialize_groups(groups, opts \\ []) when is_map(groups) do
    serialized =
      groups
      |> Enum.into(%{}, fn {key, group_data} ->
        serialized_key = serialize_key(key, opts)
        serialized_group = serialize_group_data(group_data, opts)
        {serialized_key, serialized_group}
      end)

    {:ok, serialized}
  rescue
    error -> {:error, {:group_serialization_failed, error}}
  end

  @doc """
  Serializes metadata into JSON-serializable format.

  ## Examples

      {:ok, serialized_metadata} = DataSerializer.serialize_metadata(metadata)

  """
  @spec serialize_metadata(map(), serialization_options()) :: serialization_result()
  def serialize_metadata(metadata, opts \\ []) when is_map(metadata) do
    serialized =
      metadata
      |> Enum.into(%{}, fn {key, value} ->
        serialized_key = serialize_key(key, opts)
        serialized_value = serialize_value(value, opts)
        {serialized_key, serialized_value}
      end)

    {:ok, serialized}
  rescue
    error -> {:error, {:metadata_serialization_failed, error}}
  end

  @doc """
  Serializes data with custom options and encoders.

  ## Examples

      opts = [date_format: :iso8601, number_precision: 2]
      {:ok, data} = DataSerializer.serialize_with_options(data, opts)

  """
  @spec serialize_with_options(term(), serialization_options()) :: serialization_result()
  def serialize_with_options(data, opts) do
    serialized = serialize_value(data, opts)
    {:ok, serialized}
  rescue
    error -> {:error, {:custom_serialization_failed, error}}
  end

  @doc """
  Registers custom encoders for specific data types.

  ## Examples

      encoders = %{MyStruct => &my_struct_encoder/1}
      DataSerializer.register_encoders(encoders)

  """
  @spec register_encoders(map()) :: :ok
  def register_encoders(encoders) when is_map(encoders) do
    # Store custom encoders in process dictionary for this session
    existing_encoders = Process.get(:ash_reports_custom_encoders, %{})
    updated_encoders = Map.merge(existing_encoders, encoders)
    Process.put(:ash_reports_custom_encoders, updated_encoders)
    :ok
  end

  @doc """
  Cleans up temporary encoders and serialization resources.
  """
  @spec cleanup_temporary_encoders() :: :ok
  def cleanup_temporary_encoders do
    Process.delete(:ash_reports_custom_encoders)
    :ok
  end

  # Private implementation functions

  defp serialize_value(value, opts) do
    cond do
      is_nil(value) ->
        serialize_nil_value(opts)

      is_binary(value) or is_number(value) or is_boolean(value) ->
        serialize_primitive_value(value, opts)

      is_atom(value) ->
        to_string(value)

      datetime_type?(value) ->
        serialize_datetime_value(value, opts)

      collection_type?(value) ->
        serialize_collection_value(value, opts)

      true ->
        serialize_custom_type(value, opts)
    end
  end

  defp serialize_nil_value(opts) do
    if Keyword.get(opts, :include_nulls, true), do: nil, else: :skip_field
  end

  defp serialize_primitive_value(value, opts) when is_number(value) do
    format_number(value, opts)
  end

  defp serialize_primitive_value(value, _opts), do: value

  defp datetime_type?(%DateTime{}), do: true
  defp datetime_type?(%NaiveDateTime{}), do: true
  defp datetime_type?(%Date{}), do: true
  defp datetime_type?(%Time{}), do: true
  defp datetime_type?(_), do: false

  defp collection_type?(value) when is_list(value), do: true
  defp collection_type?(value) when is_map(value), do: true
  defp collection_type?(value) when is_tuple(value), do: true
  defp collection_type?(_), do: false

  defp serialize_datetime_value(%DateTime{} = dt, opts), do: format_datetime(dt, opts)

  defp serialize_datetime_value(%NaiveDateTime{} = ndt, opts),
    do: format_naive_datetime(ndt, opts)

  defp serialize_datetime_value(%Date{} = date, opts), do: format_date(date, opts)
  defp serialize_datetime_value(%Time{} = time, opts), do: format_time(time, opts)

  defp serialize_collection_value(value, opts) when is_list(value),
    do: serialize_list(value, opts)

  defp serialize_collection_value(value, opts) when is_map(value), do: serialize_map(value, opts)

  defp serialize_collection_value(value, opts) when is_tuple(value),
    do: serialize_tuple(value, opts)

  defp serialize_key(key, _opts) when is_atom(key), do: to_string(key)
  defp serialize_key(key, _opts) when is_binary(key), do: key
  defp serialize_key(key, _opts), do: to_string(key)

  defp serialize_list(list, opts) do
    list
    |> Enum.map(fn item -> serialize_value(item, opts) end)
    |> Enum.reject(&(&1 == :skip_field))
  end

  defp serialize_map(map, opts) do
    map
    |> Enum.into(%{}, fn {key, value} ->
      serialized_value = serialize_value(value, opts)

      if serialized_value == :skip_field do
        :skip_field
      else
        {serialize_key(key, opts), serialized_value}
      end
    end)
    |> Map.reject(fn {_, value} -> value == :skip_field end)
  end

  defp serialize_tuple(tuple, opts) do
    tuple
    |> Tuple.to_list()
    |> serialize_list(opts)
  end

  defp serialize_custom_type(value, opts) do
    custom_encoders = Process.get(:ash_reports_custom_encoders, %{})
    value_module = value.__struct__

    cond do
      Map.has_key?(custom_encoders, value_module) ->
        encoder = Map.get(custom_encoders, value_module)
        encoder.(value)

      implements_jason_encoder?(value_module) ->
        Jason.Encoder.encode(value, %{})

      ash_resource?(value) ->
        serialize_ash_resource(value, opts)

      true ->
        # Fallback: convert struct to map
        value
        |> Map.from_struct()
        |> serialize_map(opts)
    end
  end

  defp format_number(number, opts) do
    case Keyword.get(opts, :number_precision) do
      nil -> number
      precision -> Float.round(number / 1, precision)
    end
  end

  defp format_datetime(datetime, opts) do
    case Keyword.get(opts, :date_format, :iso8601) do
      :iso8601 -> DateTime.to_iso8601(datetime)
      :rfc3339 -> DateTime.to_iso8601(datetime)
      :unix -> DateTime.to_unix(datetime)
      :custom -> datetime
    end
  end

  defp format_naive_datetime(naive_datetime, opts) do
    case Keyword.get(opts, :date_format, :iso8601) do
      :iso8601 -> NaiveDateTime.to_iso8601(naive_datetime)
      :rfc3339 -> NaiveDateTime.to_iso8601(naive_datetime)
      :unix -> naive_datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
      :custom -> naive_datetime
    end
  end

  defp format_date(date, opts) do
    case Keyword.get(opts, :date_format, :iso8601) do
      :iso8601 -> Date.to_iso8601(date)
      :rfc3339 -> Date.to_iso8601(date)
      :unix -> date |> DateTime.new!(~T[00:00:00], "Etc/UTC") |> DateTime.to_unix()
      :custom -> date
    end
  end

  defp format_time(time, _opts) do
    Time.to_iso8601(time)
  end

  defp serialize_report_info(report, opts) when is_map(report) do
    {:ok, serialize_map(report, opts)}
  end

  defp serialize_report_info(report, _opts) when is_atom(report) do
    {:ok, %{name: to_string(report), type: "module"}}
  end

  defp serialize_report_info(report, _opts) do
    {:ok, %{name: to_string(report), type: "unknown"}}
  end

  defp serialize_processing_state(context, opts) do
    %{
      current_record_index: context.current_record_index,
      current_position: serialize_value(context.current_position, opts),
      rendered_elements_count: length(context.rendered_elements),
      pending_elements_count: length(context.pending_elements),
      errors_count: length(context.errors),
      warnings_count: length(context.warnings)
    }
  end

  defp serialize_group_data(group_data, opts) when is_map(group_data) do
    serialize_map(group_data, opts)
  end

  defp serialize_group_data(group_data, opts) do
    serialize_value(group_data, opts)
  end

  defp implements_jason_encoder?(module) do
    Code.ensure_loaded(module)

    function_exported?(module, :__impl__, 1) and
      Jason.Encoder in module.__impl__(:protocols)
  rescue
    _ -> false
  end

  defp ash_resource?(value) do
    # Check if it's an Ash resource by looking for the __resource__ function
    value.__struct__.__resource__ != nil
  rescue
    _ -> false
  end

  defp serialize_ash_resource(resource, opts) do
    # For Ash resources, extract the data as a map and serialize
    resource
    |> Map.from_struct()
    |> Map.drop([:__struct__, :__meta__, :aggregates, :calculations])
    |> serialize_map(opts)
  end
end
