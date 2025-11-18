defmodule AshReports.Report do
  @moduledoc """
  Represents a report definition with its structure, data source, and configuration.
  """

  defstruct [
    :name,
    :title,
    :description,
    :driving_resource,
    :base_filter,
    :permissions,
    :formats,
    :parameters,
    :bands,
    :variables,
    :groups
  ]

  @type t :: %__MODULE__{
          name: atom(),
          title: String.t() | nil,
          description: String.t() | nil,
          driving_resource: atom(),
          base_filter: Ash.Expr.t() | nil,
          permissions: [atom()],
          formats: [:html | :pdf | :heex | :json],
          parameters: [AshReports.Parameter.t()],
          bands: [AshReports.Band.t()],
          variables: [AshReports.Variable.t()],
          groups: [AshReports.Group.t()]
        }

  @doc """
  Creates a new Report struct with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:parameters, [])
      |> Keyword.put_new(:bands, [])
      |> Keyword.put_new(:variables, [])
      |> Keyword.put_new(:groups, [])
      |> Keyword.put_new(:permissions, [])
      |> Keyword.put_new(:formats, [:html])
    )
  end

  @doc """
  Gets the band with the given name from the report.
  """
  @spec get_band(t(), atom()) :: AshReports.Band.t() | nil
  def get_band(%__MODULE__{bands: bands}, name) do
    find_band_recursive(bands, name)
  end

  defp find_band_recursive([], _name), do: nil

  defp find_band_recursive([%AshReports.Band{name: name} = band | _rest], name) do
    band
  end

  defp find_band_recursive([%AshReports.Band{bands: sub_bands} | rest], name) do
    case find_band_recursive(sub_bands || [], name) do
      nil -> find_band_recursive(rest, name)
      found -> found
    end
  end

  @doc """
  Gets all bands of a specific type from the report.
  """
  @spec get_bands_by_type(t(), atom()) :: [AshReports.Band.t()]
  def get_bands_by_type(%__MODULE__{bands: bands}, type) do
    collect_bands_by_type(bands, type)
  end

  defp collect_bands_by_type(bands, type) do
    Enum.flat_map(bands, fn band ->
      matching = if band.type == type, do: [band], else: []
      matching ++ collect_bands_by_type(band.bands || [], type)
    end)
  end

  @doc """
  Gets the variable with the given name.
  """
  @spec get_variable(t(), atom()) :: AshReports.Variable.t() | nil
  def get_variable(%__MODULE__{variables: variables}, name) do
    Enum.find(variables, &(&1.name == name))
  end

  @doc """
  Gets the parameter with the given name.
  """
  @spec get_parameter(t(), atom()) :: AshReports.Parameter.t() | nil
  def get_parameter(%__MODULE__{parameters: parameters}, name) do
    Enum.find(parameters, &(&1.name == name))
  end

  @doc """
  Gets the group with the given name or level.
  """
  @spec get_group(t(), atom() | pos_integer()) :: AshReports.Group.t() | nil
  def get_group(%__MODULE__{groups: groups}, name) when is_atom(name) do
    Enum.find(groups, &(&1.name == name))
  end

  def get_group(%__MODULE__{groups: groups}, level) when is_integer(level) do
    Enum.find(groups, &(&1.level == level))
  end
end
