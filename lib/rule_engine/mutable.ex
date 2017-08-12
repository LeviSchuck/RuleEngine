defmodule RuleEngine.Mutable do
  @moduledoc """
  Mutable is the execution context that RuleEngine uses.
  It hosts references to every function available to user code,
  as well as meta information.

  A notable feature of RuleEngine is to limit how much computation occurs.
  Enforcement of this occurs in `RuleEngine.Reduce`, but the data lives in
  this data structure.
  """

  alias RuleEngine.Environment

  defstruct [
    next_atom: 1,
    atoms: %{},
    environment: %Environment{},
    environment_id: 1,
    reductions: 0,
    max_reductions: :infinite,
    errors: [],
    error_mode: :crash
  ]
  @type t :: %__MODULE__{}

  @doc "Create a new atom with a given value"
  @spec atom_new(t, any) :: {t, integer}
  def atom_new(mutable, value) do
    {natom, mutable} = get_and_update_in(
      mutable,
      [Access.key!(:next_atom)],
      fn x ->
        {x, x + 1}
      end)
    mutable = update_in(mutable, [Access.key!(:atoms)], fn atoms ->
      Map.put(atoms, natom, value)
    end)
    {mutable, natom}
  end

  @doc "Retrieve the value for an atom"
  @spec atom_deref(t, integer) :: {t, any | :not_found}
  def atom_deref(mutable, atom) do
    {mutable, Map.get(mutable.atoms, atom, :not_found)}
  end

  @doc "Set the value for an already existing atom"
  @spec atom_reset!(t, integer, any) :: {t, any}
  def atom_reset!(mutable, atom, value) do
    mutable = update_in(mutable, [Access.key!(:atoms), Access.key!(atom)], fn _ -> value end)
    {mutable, value}
  end

  @doc """
  Internal use only.
  Forcefully replaces the environment in the execution context.
  """
  @spec reset(t, Environment.t) :: t
  def reset(mutable, environment) do
    update_in(mutable, [Access.key!(:environment)], fn _ ->
      environment
    end)
  end

  @doc """
  Wraps the current environment in a new environment with new data.
  """
  @spec push(t, %{}, atom | nil) :: t
  def push(mutable, data \\ %{}, label \\ nil) do
    {id, mutable} = env_inc(mutable)
    update_in(mutable, [Access.key!(:environment)], fn outer ->
      Environment.make(data, id, outer, label)
    end)
  end

  @doc """
  Wraps the current environment in a new environment with no new data
  but with a label.
  """
  @spec push_label(t, atom) :: t
  def push_label(mutable, label), do: push(mutable, %{}, label)

  @doc "Get the environment data from the execution context"
  @spec reference(t) :: %{}
  def reference(mutable) do
    mutable.environment
  end

  @doc "Get the error mode"
  @spec error_mode(t) :: :crash | :log | :ignore
  def error_mode(mutable) do
    mutable.error_mode
  end

  @doc "Sets the error mode to crash"
  @spec errors_crash(t) :: t
  def errors_crash(mutable) do
    update_in(mutable, [Access.key!(:error_mode)], fn _ -> :crash end)
  end

  @doc "Sets the error mode to crash"
  @spec errors_log(t) :: t
  def errors_log(mutable) do
    update_in(mutable, [Access.key!(:error_mode)], fn _ -> :log end)
  end

  @doc "Sets the error mode to ignore"
  @spec errors_ignore(t) :: t
  def errors_ignore(mutable) do
    update_in(mutable, [Access.key!(:error_mode)], fn _ -> :ignore end)
  end

  @doc "Handles an error according to the mutable environment setting"
  @spec handle_error(t, any) :: t
  def handle_error(_, {:crash, error}), do: throw {:crash, error}
  def handle_error(mutable, error) do
    case mutable.error_mode do
      :crash -> throw {:crash, error}
      :log -> update_in(mutable, [Access.key!(:errors)], fn st -> [error | st] end)
      :ignore -> mutable
    end
  end

  @doc "Handles an error according to the mutable environment setting"
  @spec get_errors(t) :: [any]
  def get_errors(mutable) do
    mutable.errors
  end

  @doc """
  Set a key and value in the environment without making
  a new environment hierarchy
  """
  @spec set(t, any, any, atom | nil) :: t
  def set(mutable, key, value, label \\ nil) do
    {env_id, mutable} = env_inc(mutable)
    mutable
      |> update_in([Access.key!(:environment)], fn environment ->
      Environment.put(environment, key, value, label)
    end)
      |> update_in([Access.key!(:environment), Access.key!(:id)], fn _ ->
      env_id
    end)
  end

  @doc "Look up a symbol in the execution context."
  @spec lookup(t, any, atom | nil) :: {:ok, any} | :not_found
  def lookup(mutable, key, label \\ nil) do
    Environment.get(mutable.environment, key, label)
  end

  @doc """
  Increment the reductions count in the execution context
  This does not enforce maximum reductions.
  """
  @spec reductions_inc(t) :: t
  def reductions_inc(mutable) do
    update_in(mutable, [Access.key!(:reductions)], fn x ->
      x + 1
    end)
  end

  @doc """
  Resets the reductions count in the execution context.

  This is particularly useful if you split up initialization or shared code
  from on the fly executions.
  """
  @spec reductions_reset(t) :: t
  def reductions_reset(mutable) do
    update_in(mutable, [Access.key!(:reductions)], fn _ ->
      0
    end)
  end

  @doc "Sets the maximum reductions that may be reached."
  @spec reductions_max(t, integer | :infinite) :: t
  def reductions_max(mutable, maximum) do
    update_in(mutable, [Access.key!(:max_reductions)], fn _ ->
      maximum
    end)
  end

  defp env_inc(mutable) do
    get_and_update_in(mutable, [Access.key!(:environment_id)], fn x ->
      {x, x + 1}
    end)
  end
end
