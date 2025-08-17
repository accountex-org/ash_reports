defmodule AshReports.Variable do
  @moduledoc """
  Represents a variable that accumulates values during report execution.

  Variables can perform calculations like sum, count, average, etc., and can be
  reset at different scopes (detail, group, page, or report level).
  """

  defstruct [
    :name,
    :type,
    :expression,
    :reset_on,
    :reset_group,
    :initial_value
  ]

  @type variable_type :: :sum | :count | :average | :min | :max | :custom
  @type reset_scope :: :detail | :group | :page | :report

  @type t :: %__MODULE__{
          name: atom(),
          type: variable_type(),
          expression: Ash.Expr.t(),
          reset_on: reset_scope(),
          reset_group: pos_integer() | nil,
          initial_value: any()
        }

  @doc """
  Creates a new Variable struct with the given name and options.
  """
  @spec new(atom(), Keyword.t()) :: t()
  def new(name, opts \\ []) do
    struct(
      __MODULE__,
      [name: name]
      |> Keyword.merge(opts)
      |> Keyword.put_new(:reset_on, :report)
      |> maybe_set_initial_value()
    )
  end

  defp maybe_set_initial_value(opts) do
    if opts[:initial_value] do
      opts
    else
      case opts[:type] do
        :sum -> Keyword.put(opts, :initial_value, 0)
        :count -> Keyword.put(opts, :initial_value, 0)
        # {sum, count}
        :average -> Keyword.put(opts, :initial_value, {0, 0})
        :min -> Keyword.put(opts, :initial_value, nil)
        :max -> Keyword.put(opts, :initial_value, nil)
        :custom -> opts
        _ -> opts
      end
    end
  end

  @doc """
  Returns the default initial value for a variable type.
  """
  @spec default_initial_value(variable_type()) :: any()
  def default_initial_value(:sum), do: 0
  def default_initial_value(:count), do: 0
  def default_initial_value(:average), do: {0, 0}
  def default_initial_value(:min), do: nil
  def default_initial_value(:max), do: nil
  def default_initial_value(:custom), do: nil

  @doc """
  Checks if this variable should reset when the given scope changes.
  """
  @spec should_reset?(t(), reset_scope(), pos_integer() | nil) :: boolean()
  def should_reset?(%__MODULE__{reset_on: reset_on}, scope, _group_level)
      when reset_on == scope do
    true
  end

  def should_reset?(%__MODULE__{reset_on: :group, reset_group: reset_group}, :group, group_level)
      when not is_nil(reset_group) and reset_group == group_level do
    true
  end

  def should_reset?(_variable, _scope, _group_level), do: false

  @doc """
  Calculates the next value for the variable based on its type.
  """
  @spec calculate_next_value(t(), any(), any()) :: any()
  def calculate_next_value(%__MODULE__{type: :sum, initial_value: initial}, current, new_value) do
    current = current || initial || 0
    current + (new_value || 0)
  end

  def calculate_next_value(%__MODULE__{type: :count}, current, _new_value) do
    (current || 0) + 1
  end

  def calculate_next_value(%__MODULE__{type: :average}, current, new_value) do
    {sum, count} = current || {0, 0}
    {sum + (new_value || 0), count + 1}
  end

  def calculate_next_value(%__MODULE__{type: :min}, current, new_value) do
    case {current, new_value} do
      {nil, val} -> val
      {curr, nil} -> curr
      {curr, val} -> min(curr, val)
    end
  end

  def calculate_next_value(%__MODULE__{type: :max}, current, new_value) do
    case {current, new_value} do
      {nil, val} -> val
      {curr, nil} -> curr
      {curr, val} -> max(curr, val)
    end
  end

  def calculate_next_value(%__MODULE__{type: :custom}, _current, new_value) do
    new_value
  end

  @doc """
  Gets the display value for the variable (handles average calculation).
  """
  @spec get_display_value(t(), any()) :: any()
  def get_display_value(%__MODULE__{type: :average}, {sum, count}) when count > 0 do
    sum / count
  end

  def get_display_value(%__MODULE__{type: :average}, _), do: 0

  def get_display_value(_variable, value), do: value
end
