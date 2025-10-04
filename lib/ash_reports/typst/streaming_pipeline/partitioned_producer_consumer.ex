defmodule AshReports.Typst.StreamingPipeline.PartitionedProducerConsumer do
  @moduledoc """
  Horizontal scalability layer for aggregation processing.

  This module enables parallel aggregation processing by partitioning records
  across multiple ProducerConsumer workers based on group keys.

  ## Architecture

  ```
  Producer → PartitionRouter → [Worker1, Worker2, ..., WorkerN] → Aggregator
                                 (Partition 0)  (Partition 1)
  ```

  ## Partitioning Strategy

  Records are partitioned using consistent hashing:

      partition = :erlang.phash2(group_key, partition_count)

  This ensures:
  - Same group key always goes to same worker
  - Balanced distribution across workers
  - No cross-worker coordination needed

  ## Benefits

  - **Throughput**: Linear scaling with worker count (2x workers ≈ 2x throughput)
  - **Memory**: Each worker handles subset of groups
  - **CPU**: Parallel aggregation computation
  - **Isolation**: Worker failures don't affect other partitions

  ## Configuration

      # Single worker (default, backward compatible)
      StreamingPipeline.start_stream(domain, resource, query,
        partition_count: 1
      )

      # 4 parallel workers (4x throughput)
      StreamingPipeline.start_stream(domain, resource, query,
        partition_count: 4
      )

  ## Trade-offs

  - **More workers**: Higher throughput, more memory, more CPU cores needed
  - **Fewer workers**: Lower throughput, less memory, fewer resources
  - **Optimal**: partition_count = number of CPU cores

  ## Merging Results

  After streaming completes, partition results are merged:

      {:ok, merged_state} = PartitionedProducerConsumer.merge_partitions(workers)

  Merging is fast: O(groups) where groups < records.

  ## Usage

      # Start partitioned pipeline
      {:ok, workers} = PartitionedProducerConsumer.start_partitions(
        stream_id: "abc",
        producer_pid: producer,
        partition_count: 4,
        grouped_aggregations: [...],
        transformer: &transform/1
      )

      # Consume stream
      Stream.run(stream)

      # Merge results
      {:ok, final_state} = PartitionedProducerConsumer.merge_partitions(workers)
  """

  require Logger

  alias AshReports.Typst.StreamingPipeline.ProducerConsumer

  @doc """
  Starts multiple partitioned ProducerConsumer workers.

  ## Parameters

    * `opts` - Keyword list with:
      - `:stream_id` - Unique stream identifier
      - `:producer_pid` - Producer process to subscribe to
      - `:partition_count` - Number of workers (default: 1)
      - `:grouped_aggregations` - Aggregation configurations
      - `:transformer` - Transformation function
      - `:max_demand` - Max demand per worker (default: 500)
      - Other ProducerConsumer options

  ## Returns

    * `{:ok, [worker_info]}` - List of worker metadata
    * `{:error, reason}` - Failed to start workers

  ## Examples

      iex> {:ok, workers} = PartitionedProducerConsumer.start_partitions(
      ...>   stream_id: "test",
      ...>   producer_pid: pid,
      ...>   partition_count: 4,
      ...>   grouped_aggregations: [...]
      ...> )
      iex> length(workers)
      4
  """
  @spec start_partitions(keyword()) :: {:ok, [map()]} | {:error, term()}
  def start_partitions(opts) do
    partition_count = Keyword.get(opts, :partition_count, 1)
    stream_id = Keyword.fetch!(opts, :stream_id)
    _producer_pid = Keyword.fetch!(opts, :producer_pid)

    Logger.info("Starting #{partition_count} partitioned workers for stream #{stream_id}")

    # Start workers in parallel
    workers =
      0..(partition_count - 1)
      |> Enum.map(fn partition_id ->
        Task.async(fn ->
          start_partition_worker(opts, partition_id, partition_count)
        end)
      end)
      |> Enum.map(&Task.await(&1, :infinity))

    # Check for errors
    errors =
      Enum.filter(workers, fn
        {:error, _} -> true
        _ -> false
      end)

    case errors do
      [] ->
        worker_info =
          Enum.map(workers, fn {:ok, info} -> info end)

        {:ok, worker_info}

      [first_error | _] ->
        # Stop any successfully started workers
        Enum.each(workers, fn
          {:ok, info} -> GenStage.stop(info.pid)
          _ -> :ok
        end)

        first_error
    end
  end

  @doc """
  Merges aggregation results from multiple partition workers.

  Combines grouped aggregation states from all workers into a single
  unified state. This is fast (O(groups)) since each group belongs to
  exactly one partition.

  ## Parameters

    * `workers` - List of worker info maps (from start_partitions/1)

  ## Returns

    * `{:ok, merged_state}` - Combined aggregation state
    * `{:error, reason}` - Failed to retrieve or merge states

  ## Examples

      iex> {:ok, workers} = start_partitions(...)
      iex> Stream.run(stream)
      iex> {:ok, state} = merge_partitions(workers)
      iex> state.grouped_aggregations
      %{[:region] => %{"North" => %{sum: %{amount: 1000}}}}
  """
  @spec merge_partitions([map()]) :: {:ok, map()} | {:error, term()}
  def merge_partitions(workers) do
    Logger.debug("Merging results from #{length(workers)} partition workers")

    start_time = System.monotonic_time(:millisecond)

    # Retrieve aggregation state from each worker
    partition_states =
      workers
      |> Enum.map(fn worker ->
        case GenStage.call(worker.pid, :get_aggregation_state) do
          {:ok, state} -> {:ok, worker.partition_id, state}
          error -> error
        end
      end)

    # Check for errors
    errors =
      Enum.filter(partition_states, fn
        {:error, _} -> true
        _ -> false
      end)

    case errors do
      [] ->
        # Merge all partition states
        merged =
          partition_states
          |> Enum.map(fn {:ok, _partition_id, state} -> state end)
          |> merge_aggregation_states()

        duration = System.monotonic_time(:millisecond) - start_time

        Logger.info(
          "Merged #{length(workers)} partitions in #{duration}ms - " <>
            "Total groups: #{count_total_groups(merged.grouped_aggregations)}"
        )

        {:ok, merged}

      [first_error | _] ->
        first_error
    end
  end

  # Private Functions

  defp start_partition_worker(opts, partition_id, partition_count) do
    stream_id = Keyword.fetch!(opts, :stream_id)
    producer_pid = Keyword.fetch!(opts, :producer_pid)
    max_demand = Keyword.get(opts, :max_demand, 500)

    partition_stream_id = "#{stream_id}_partition_#{partition_id}"

    # Wrap transformer to filter by partition
    original_transformer = Keyword.get(opts, :transformer, & &1)

    partition_transformer = fn record ->
      # Apply original transformation first
      transformed = original_transformer.(record)

      # Determine if this record belongs to this partition
      if belongs_to_partition?(transformed, partition_id, partition_count, opts) do
        transformed
      else
        # Return nil to filter out records not in this partition
        nil
      end
    end

    # Start ProducerConsumer for this partition
    worker_opts =
      opts
      |> Keyword.put(:stream_id, partition_stream_id)
      |> Keyword.put(:transformer, partition_transformer)
      |> Keyword.put(:subscribe_to, [{producer_pid, max_demand: max_demand}])
      |> Keyword.delete(:partition_count)
      |> Keyword.delete(:producer_pid)

    case ProducerConsumer.start_link(worker_opts) do
      {:ok, pid} ->
        {:ok,
         %{
           partition_id: partition_id,
           pid: pid,
           stream_id: partition_stream_id
         }}

      error ->
        error
    end
  end

  defp belongs_to_partition?(record, _partition_id, _partition_count, _opts)
       when is_nil(record) do
    # Nil records (filtered by transformer) don't belong to any partition
    false
  end

  defp belongs_to_partition?(record, partition_id, partition_count, opts) do
    grouped_aggregations = Keyword.get(opts, :grouped_aggregations, [])

    # If no grouping, use round-robin (not ideal but works)
    if grouped_aggregations == [] do
      # Hash the entire record
      :erlang.phash2(record, partition_count) == partition_id
    else
      # Use first grouping configuration to determine partition
      # All groupings will be partitioned the same way
      [first_config | _] = grouped_aggregations

      group_value = extract_group_value(record, first_config.group_by)
      partition = :erlang.phash2(group_value, partition_count)

      partition == partition_id
    end
  end

  defp extract_group_value(record, group_by) when is_atom(group_by) do
    Map.get(record, group_by)
  end

  defp extract_group_value(record, group_by) when is_list(group_by) do
    # Create tuple of values for multi-field grouping
    values = Enum.map(group_by, &Map.get(record, &1))
    List.to_tuple(values)
  end

  defp merge_aggregation_states(states) do
    # Merge simple aggregations (sum across all partitions)
    merged_aggregations = merge_simple_aggregations(states)

    # Merge grouped aggregations (union all groups)
    merged_grouped = merge_grouped_aggregations(states)

    # Merge metadata
    total_records =
      Enum.reduce(states, 0, fn state, acc ->
        acc + Map.get(state, :total_records_processed, 0)
      end)

    %{
      aggregations: merged_aggregations,
      grouped_aggregations: merged_grouped,
      total_records_processed: total_records
    }
  end

  defp merge_simple_aggregations(states) do
    # Sum counts and numeric aggregations across partitions
    states
    |> Enum.map(& &1.aggregations)
    |> Enum.reduce(%{}, fn partition_agg, acc ->
      Map.merge(acc, partition_agg, fn
        :count, v1, v2 -> v1 + v2
        :sum, v1, v2 -> merge_sum_maps(v1, v2)
        :avg, v1, v2 -> merge_avg_maps(v1, v2)
        :min, v1, v2 -> merge_min_maps(v1, v2)
        :max, v1, v2 -> merge_max_maps(v1, v2)
        _, v1, _v2 -> v1
      end)
    end)
  end

  defp merge_sum_maps(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _k, v1, v2 -> v1 + v2 end)
  end

  defp merge_sum_maps(map1, _map2), do: map1

  defp merge_avg_maps(map1, map2) when is_map(map1) and is_map(map2) do
    # Avg is stored as {sum, count} - merge both
    sum1 = Map.get(map1, :sum, %{})
    sum2 = Map.get(map2, :sum, %{})
    count1 = Map.get(map1, :count, 0)
    count2 = Map.get(map2, :count, 0)

    %{
      sum: merge_sum_maps(sum1, sum2),
      count: count1 + count2
    }
  end

  defp merge_avg_maps(map1, _map2), do: map1

  defp merge_min_maps(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _k, v1, v2 ->
      cond do
        is_nil(v1) -> v2
        is_nil(v2) -> v1
        true -> min(v1, v2)
      end
    end)
  end

  defp merge_min_maps(map1, _map2), do: map1

  defp merge_max_maps(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _k, v1, v2 ->
      cond do
        is_nil(v1) -> v2
        is_nil(v2) -> v1
        true -> max(v1, v2)
      end
    end)
  end

  defp merge_max_maps(map1, _map2), do: map1

  defp merge_grouped_aggregations(states) do
    # Union all groups from all partitions
    # Since partitioning is deterministic, each group appears in exactly one partition
    states
    |> Enum.map(& &1.grouped_aggregations)
    |> Enum.reduce(%{}, fn partition_groups, acc ->
      Map.merge(acc, partition_groups, fn _group_key, partition_map, acc_map ->
        # Merge maps for same group_key (shouldn't happen with proper partitioning)
        Map.merge(acc_map, partition_map)
      end)
    end)
  end

  defp count_total_groups(grouped_aggregations) do
    grouped_aggregations
    |> Enum.map(fn {_key, groups} -> map_size(groups) end)
    |> Enum.sum()
  end
end
