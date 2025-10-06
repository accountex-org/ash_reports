defmodule AshReports.Security.AtomValidator do
  @moduledoc """
  Validates and safely converts strings to atoms using whitelists.

  This module prevents atom table exhaustion attacks by only allowing
  conversion of whitelisted string values to atoms. All other values
  are kept as strings or rejected with clear error messages.

  ## Security Rationale

  Elixir atoms are not garbage collected. Creating atoms dynamically from
  user input can lead to atom table exhaustion (default limit: ~1M atoms),
  causing the VM to crash (DoS vulnerability).

  ## Usage

      # Safe - uses whitelist
      AtomValidator.to_chart_type("bar")
      #=> {:ok, :bar}

      # Safe - rejects unknown
      AtomValidator.to_chart_type("malicious")
      #=> {:error, :invalid_chart_type}

      # Safe - keeps as string
      AtomValidator.to_field_name("user_input")
      #=> {:ok, "user_input"}
  """

  # Allowed chart types that can be converted to atoms.
  @allowed_chart_types ~w(bar line pie area scatter)a

  # Allowed export formats that can be converted to atoms.
  @allowed_export_formats ~w(json csv png svg pdf html)a

  # Allowed chart providers that can be converted to atoms.
  @allowed_chart_providers ~w(chartjs d3 plotly contex)a

  # Allowed aggregation functions that can be converted to atoms.
  @allowed_aggregation_functions ~w(sum count avg min max median)a

  # Allowed sort directions that can be converted to atoms.
  @allowed_sort_directions ~w(asc desc)a

  @doc """
  Converts a string to a chart type atom if it's in the allowed list.

  ## Examples

      iex> AtomValidator.to_chart_type("bar")
      {:ok, :bar}

      iex> AtomValidator.to_chart_type("invalid")
      {:error, :invalid_chart_type}

      iex> AtomValidator.to_chart_type(:bar)
      {:ok, :bar}
  """
  @spec to_chart_type(String.t() | atom()) :: {:ok, atom()} | {:error, :invalid_chart_type}
  def to_chart_type(value) when is_atom(value) do
    if value in @allowed_chart_types do
      {:ok, value}
    else
      {:error, :invalid_chart_type}
    end
  end

  def to_chart_type(value) when is_binary(value) do
    try do
      atom_value = String.to_existing_atom(value)

      if atom_value in @allowed_chart_types do
        {:ok, atom_value}
      else
        {:error, :invalid_chart_type}
      end
    rescue
      ArgumentError -> {:error, :invalid_chart_type}
    end
  end

  @doc """
  Converts a string to an export format atom if it's in the allowed list.
  """
  @spec to_export_format(String.t() | atom()) :: {:ok, atom()} | {:error, :invalid_export_format}
  def to_export_format(value) when is_atom(value) do
    if value in @allowed_export_formats do
      {:ok, value}
    else
      {:error, :invalid_export_format}
    end
  end

  def to_export_format(value) when is_binary(value) do
    try do
      atom_value = String.to_existing_atom(value)

      if atom_value in @allowed_export_formats do
        {:ok, atom_value}
      else
        {:error, :invalid_export_format}
      end
    rescue
      ArgumentError -> {:error, :invalid_export_format}
    end
  end

  @doc """
  Converts a string to a chart provider atom if it's in the allowed list.
  """
  @spec to_chart_provider(String.t() | atom()) ::
          {:ok, atom()} | {:error, :invalid_chart_provider}
  def to_chart_provider(value) when is_atom(value) do
    if value in @allowed_chart_providers do
      {:ok, value}
    else
      {:error, :invalid_chart_provider}
    end
  end

  def to_chart_provider(value) when is_binary(value) do
    try do
      atom_value = String.to_existing_atom(value)

      if atom_value in @allowed_chart_providers do
        {:ok, atom_value}
      else
        {:error, :invalid_chart_provider}
      end
    rescue
      ArgumentError -> {:error, :invalid_chart_provider}
    end
  end

  @doc """
  Converts a string to a sort direction atom if it's in the allowed list.
  """
  @spec to_sort_direction(String.t() | atom()) ::
          {:ok, atom()} | {:error, :invalid_sort_direction}
  def to_sort_direction(value) when is_atom(value) do
    if value in @allowed_sort_directions do
      {:ok, value}
    else
      {:error, :invalid_sort_direction}
    end
  end

  def to_sort_direction(value) when is_binary(value) do
    try do
      atom_value = String.to_existing_atom(value)

      if atom_value in @allowed_sort_directions do
        {:ok, atom_value}
      else
        {:error, :invalid_sort_direction}
      end
    rescue
      ArgumentError -> {:error, :invalid_sort_direction}
    end
  end

  @doc """
  Safely handles field names by keeping them as strings.

  Field names come from user data/schema and should never be converted
  to atoms to prevent atom table exhaustion.

  ## Examples

      iex> AtomValidator.to_field_name("user_field")
      {:ok, "user_field"}

      iex> AtomValidator.to_field_name(:existing_atom)
      {:ok, :existing_atom}
  """
  @spec to_field_name(String.t() | atom()) :: {:ok, String.t() | atom()}
  def to_field_name(value) when is_atom(value), do: {:ok, value}
  def to_field_name(value) when is_binary(value), do: {:ok, value}

  @doc """
  Converts an aggregation function string to an atom if allowed.
  """
  @spec to_aggregation_function(String.t() | atom()) ::
          {:ok, atom()} | {:error, :invalid_aggregation_function}
  def to_aggregation_function(value) when is_atom(value) do
    if value in @allowed_aggregation_functions do
      {:ok, value}
    else
      {:error, :invalid_aggregation_function}
    end
  end

  def to_aggregation_function(value) when is_binary(value) do
    try do
      atom_value = String.to_existing_atom(value)

      if atom_value in @allowed_aggregation_functions do
        {:ok, atom_value}
      else
        {:error, :invalid_aggregation_function}
      end
    rescue
      ArgumentError -> {:error, :invalid_aggregation_function}
    end
  end

  @doc """
  Returns the list of allowed chart types.
  """
  def allowed_chart_types, do: @allowed_chart_types

  @doc """
  Returns the list of allowed export formats.
  """
  def allowed_export_formats, do: @allowed_export_formats

  @doc """
  Returns the list of allowed chart providers.
  """
  def allowed_chart_providers, do: @allowed_chart_providers

  @doc """
  Returns the list of allowed aggregation functions.
  """
  def allowed_aggregation_functions, do: @allowed_aggregation_functions

  @doc """
  Returns the list of allowed sort directions.
  """
  def allowed_sort_directions, do: @allowed_sort_directions
end
