defmodule AshReports.Layout.Positioning do
  @moduledoc """
  Cell positioning engine for layout containers.

  This module calculates cell positions for grid and table layouts using:
  - Row-major automatic flow (left-to-right, top-to-bottom)
  - Explicit positioning with x/y coordinates
  - Spanning calculations for colspan and rowspan
  - Row-based positioning for explicit row containers

  ## Algorithm

  1. Process explicit cells first (those with x/y coordinates)
  2. Mark all positions occupied by explicit cells (including spans)
  3. Flow remaining cells into available positions row-by-row
  4. For each cell, skip occupied positions and place at next available

  ## Examples

      # Position cells in a 3-column grid
      cells = [
        %{content: "A"},           # Will be at (0, 0)
        %{content: "B"},           # Will be at (1, 0)
        %{content: "C"},           # Will be at (2, 0)
        %{content: "D"},           # Will be at (0, 1)
      ]
      {:ok, positioned} = Positioning.position_cells(cells, columns: 3)

      # Explicit positioning
      cells = [
        %{x: 1, y: 0, content: "B"},  # Explicit at (1, 0)
        %{content: "A"},               # Flows to (0, 0)
        %{content: "C"},               # Flows to (2, 0)
      ]
      {:ok, positioned} = Positioning.position_cells(cells, columns: 3)
  """

  alias AshReports.Layout.{Errors, IR}

  @doc """
  Positions cells within a grid layout.

  ## Options

  - `:columns` - Number of columns in the grid (required)
  - `:rows` - Number of rows (optional, expands as needed)

  ## Returns

  - `{:ok, positioned_cells}` - List of cells with position tuples
  - `{:error, reason}` - Error if positioning fails
  """
  @spec position_cells(list(), keyword()) :: {:ok, list()} | {:error, term()}
  def position_cells(cells, opts \\ []) do
    columns = Keyword.get(opts, :columns, 1)

    with {:ok, {explicit, flow}} <- separate_cells(cells),
         {:ok, occupied, positioned_explicit} <- position_explicit_cells(explicit, columns),
         {:ok, positioned_flow} <- position_flow_cells(flow, columns, occupied) do
      # Combine and sort by position for consistent ordering
      all_cells = positioned_explicit ++ positioned_flow
      sorted = Enum.sort_by(all_cells, fn cell -> {elem(cell.position, 1), elem(cell.position, 0)} end)
      {:ok, sorted}
    end
  end

  @doc """
  Positions cells within explicit row containers.

  Each row container gets its own row index, and cells within are positioned
  sequentially in that row.

  ## Options

  - `:columns` - Number of columns in the grid (required)

  ## Returns

  - `{:ok, positioned_rows}` - List of rows with positioned cells
  - `{:error, reason}` - Error if positioning fails
  """
  @spec position_rows(list(), keyword()) :: {:ok, list()} | {:error, term()}
  def position_rows(rows, opts \\ []) do
    columns = Keyword.get(opts, :columns, 1)

    # Track occupied positions across all rows (for rowspan)
    initial_occupied = MapSet.new()

    {positioned_rows, _final_occupied} =
      rows
      |> Enum.with_index()
      |> Enum.map_reduce(initial_occupied, fn {row, row_index}, occupied ->
        case position_row_cells(row, row_index, columns, occupied) do
          {:ok, positioned_row, new_occupied} ->
            {positioned_row, new_occupied}
          {:error, _} = err ->
            throw(err)
        end
      end)

    {:ok, positioned_rows}
  catch
    {:error, _} = err -> err
  end

  @doc """
  Calculates all positions occupied by a cell with spanning.

  ## Examples

      iex> Positioning.calculate_occupied_positions({0, 0}, {2, 1})
      [{0, 0}, {1, 0}]

      iex> Positioning.calculate_occupied_positions({1, 1}, {2, 2})
      [{1, 1}, {2, 1}, {1, 2}, {2, 2}]
  """
  @spec calculate_occupied_positions({integer(), integer()}, {integer(), integer()}) :: list({integer(), integer()})
  def calculate_occupied_positions({x, y}, {colspan, rowspan}) do
    for cx <- x..(x + colspan - 1),
        cy <- y..(y + rowspan - 1) do
      {cx, cy}
    end
  end

  @doc """
  Validates that a span doesn't exceed grid bounds.

  ## Examples

      iex> Positioning.validate_span({0, 0}, {2, 1}, 3)
      :ok

      iex> Positioning.validate_span({2, 0}, {2, 1}, 3)
      {:error, {:span_overflow, {2, 0}, {2, 1}, 3}}
  """
  @spec validate_span({integer(), integer()}, {integer(), integer()}, integer()) :: :ok | {:error, term()}
  def validate_span({x, y}, {colspan, rowspan}, columns) do
    if x + colspan > columns do
      {:error, Errors.span_overflow({x, y}, {colspan, rowspan}, columns)}
    else
      :ok
    end
  end

  # Private functions

  defp separate_cells(cells) do
    {explicit, flow} =
      Enum.split_with(cells, fn cell ->
        has_explicit_position?(cell)
      end)

    {:ok, {explicit, flow}}
  end

  defp has_explicit_position?(cell) do
    x = get_cell_x(cell)
    y = get_cell_y(cell)
    # A cell has explicit position if both x and y are set to non-zero,
    # or if x is set (for explicit column placement)
    # For this implementation, we consider explicit if x > 0 or y > 0
    (x != nil and x > 0) or (y != nil and y > 0)
  end

  defp get_cell_x(%IR.Cell{position: {x, _}}), do: x
  defp get_cell_x(%{x: x}), do: x
  defp get_cell_x(%{position: {x, _}}), do: x
  defp get_cell_x(_), do: nil

  defp get_cell_y(%IR.Cell{position: {_, y}}), do: y
  defp get_cell_y(%{y: y}), do: y
  defp get_cell_y(%{position: {_, y}}), do: y
  defp get_cell_y(_), do: nil

  defp get_cell_span(%IR.Cell{span: span}), do: span
  defp get_cell_span(%{span: span}) when span != nil, do: span
  defp get_cell_span(%{} = cell) do
    colspan = Map.get(cell, :colspan, 1) || 1
    rowspan = Map.get(cell, :rowspan, 1) || 1
    {colspan, rowspan}
  end
  defp get_cell_span(_), do: {1, 1}

  defp position_explicit_cells(explicit_cells, columns) do
    Enum.reduce_while(explicit_cells, {:ok, MapSet.new(), []}, fn cell, {:ok, occupied, positioned} ->
      x = get_cell_x(cell) || 0
      y = get_cell_y(cell) || 0
      span = get_cell_span(cell)
      position = {x, y}

      # Validate span
      case validate_span(position, span, columns) do
        :ok ->
          # Calculate occupied positions
          new_positions = calculate_occupied_positions(position, span)

          # Check for conflicts
          conflicts = Enum.filter(new_positions, &MapSet.member?(occupied, &1))

          if conflicts != [] do
            {:halt, {:error, Errors.position_conflict(position, :existing_cell)}}
          else
            # Update cell with position
            positioned_cell = update_cell_position(cell, position)
            new_occupied = Enum.reduce(new_positions, occupied, &MapSet.put(&2, &1))
            {:cont, {:ok, new_occupied, [positioned_cell | positioned]}}
          end

        {:error, _} = err ->
          {:halt, err}
      end
    end)
    |> case do
      {:ok, occupied, positioned} -> {:ok, occupied, Enum.reverse(positioned)}
      error -> error
    end
  end

  defp position_flow_cells(flow_cells, columns, initial_occupied) do
    {positioned, _final_occupied, _final_pos} =
      Enum.reduce(flow_cells, {[], initial_occupied, {0, 0}}, fn cell, {acc, occupied, {col, row}} ->
        span = get_cell_span(cell)

        # Find next available position
        {next_col, next_row} = find_next_available({col, row}, columns, occupied, span)
        position = {next_col, next_row}

        # Calculate occupied positions for this cell
        new_positions = calculate_occupied_positions(position, span)
        new_occupied = Enum.reduce(new_positions, occupied, &MapSet.put(&2, &1))

        # Update cell with position
        positioned_cell = update_cell_position(cell, position)

        # Calculate next starting position (move past this cell's colspan)
        {colspan, _rowspan} = span
        next_start = advance_position({next_col + colspan, next_row}, columns)

        {[positioned_cell | acc], new_occupied, next_start}
      end)

    {:ok, Enum.reverse(positioned)}
  end

  defp find_next_available({col, row}, columns, occupied, {colspan, _rowspan} = span) do
    position = {col, row}

    # Check if current position is available and span fits
    positions_to_check = calculate_occupied_positions(position, span)
    all_available = Enum.all?(positions_to_check, fn pos -> not MapSet.member?(occupied, pos) end)
    fits_in_row = col + colspan <= columns

    if all_available and fits_in_row do
      position
    else
      # Move to next position
      next_pos = advance_position({col + 1, row}, columns)
      find_next_available(next_pos, columns, occupied, span)
    end
  end

  defp advance_position({col, row}, columns) when col >= columns do
    {0, row + 1}
  end

  defp advance_position(pos, _columns), do: pos

  defp update_cell_position(%IR.Cell{} = cell, position) do
    %{cell | position: position}
  end

  defp update_cell_position(%{} = cell, {x, y}) do
    cell
    |> Map.put(:x, x)
    |> Map.put(:y, y)
    |> Map.put(:position, {x, y})
  end

  defp position_row_cells(row, row_index, columns, global_occupied) do
    cells = get_row_cells(row)

    {positioned_cells, final_occupied, _col} =
      Enum.reduce(cells, {[], global_occupied, 0}, fn cell, {acc, occupied, col} ->
        span = get_cell_span(cell)
        {colspan, _rowspan} = span

        # Find next available column in this row
        next_col = find_next_column_in_row(col, row_index, columns, occupied, colspan)
        position = {next_col, row_index}

        # Validate span
        case validate_span(position, span, columns) do
          :ok ->
            # Calculate occupied positions
            new_positions = calculate_occupied_positions(position, span)
            new_occupied = Enum.reduce(new_positions, occupied, &MapSet.put(&2, &1))

            # Update cell with position
            positioned_cell = update_cell_position(cell, position)

            {[positioned_cell | acc], new_occupied, next_col + colspan}

          {:error, _} = err ->
            throw(err)
        end
      end)

    positioned_row = update_row_cells(row, Enum.reverse(positioned_cells))
    {:ok, positioned_row, final_occupied}
  catch
    {:error, _} = err -> err
  end

  defp find_next_column_in_row(col, row, columns, occupied, colspan) do
    if col >= columns do
      # Should not happen in well-formed input, but handle gracefully
      col
    else
      positions_to_check = for c <- col..(col + colspan - 1), do: {c, row}
      all_available = Enum.all?(positions_to_check, fn pos -> not MapSet.member?(occupied, pos) end)
      fits_in_row = col + colspan <= columns

      if all_available and fits_in_row do
        col
      else
        find_next_column_in_row(col + 1, row, columns, occupied, colspan)
      end
    end
  end

  defp get_row_cells(%IR.Row{cells: cells}), do: cells
  defp get_row_cells(%{cells: cells}), do: cells
  defp get_row_cells(%{elements: elements}), do: elements
  defp get_row_cells(_), do: []

  defp update_row_cells(%IR.Row{} = row, cells) do
    %{row | cells: cells}
  end

  defp update_row_cells(%{} = row, cells) do
    cond do
      Map.has_key?(row, :cells) -> %{row | cells: cells}
      Map.has_key?(row, :elements) -> %{row | elements: cells}
      true -> Map.put(row, :cells, cells)
    end
  end
end
