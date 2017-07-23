defmodule RuleEngine.Mutable do
  @moduledoc """
  Mutable is the execution context that RuleEngine uses.
  It hosts references to every function available to user code,
  as well as meta information.

  A notable feature of RuleEngine is to limit how much computation occurs.
  Enforcement of this occurs in `RuleEngine.Reduce`, but the data lives in
  this data structure.
  """
  defstruct [
    next_atom: 1,
    atoms: %{},
    environment: %{},
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
    {natom, nmutable1} = get_and_update_in(
      mutable,
      [Access.key!(:next_atom)],
      fn x ->
        {x, x + 1}
      end)
    nmutable2 = update_in(nmutable1, [Access.key!(:atoms)], fn atoms ->
      Map.put(atoms, natom, value)
    end)
    {nmutable2, natom}
  end

  @doc "Retrieve the value for an atom"
  @spec atom_deref(t, integer) :: {t, any | :not_found}
  def atom_deref(mutable, atom) do
    {mutable, Map.get(mutable.atoms, atom, :not_found)}
  end

  @doc "Set the value for an already existing atom"
  @spec atom_reset!(t, integer, any) :: {t, any}
  def atom_reset!(mutable, atom, value) do
    nmutable = update_in(mutable, [Access.key!(:atoms), Access.key!(atom)], fn _ -> value end)
    {nmutable, value}
  end

  @doc "Increment the environment number, signifies uniqueness for later use."
  @spec env_inc(t) :: {integer, t}
  def env_inc(mutable) do
    {eid, nmutable} = get_and_update_in(mutable, [Access.key!(:environment_id)], fn x ->
      {x, x + 1}
    end)
    {eid, nmutable}
  end

  @doc """
  Internal use only.
  Forcefully replaces the environment in the execution context.
  """
  @spec env_override(t, %{}) :: t
  def env_override(mutable, environment) do
    nmutable = update_in(mutable, [Access.key!(:environment)], fn _ ->
      environment
    end)
    nmutable
  end

  @doc """
  Wraps the current environment in a new environment with different new data.
  """
  @spec env_new(t, %{}) :: t
  def env_new(mutable, data) do
    {env_id, nmutable1} = env_inc(mutable)
    nmutable2 = update_in(nmutable1, [Access.key!(:environment)], fn outer ->
      %{
        outer: outer,
        vals: data,
        id: env_id
      }
    end)
    nmutable2
  end

  @doc """
  Wraps the current environment in a new environment with a specified parent
  environment.
  """
  @spec env_new(t, %{}, %{}) :: t
  def env_new(mutable, outer, data) do
    {env_id, nmutable1} = env_inc(mutable)
    nmutable2 = update_in(nmutable1, [Access.key!(:environment)], fn _ ->
      %{
        outer: outer,
        vals: data,
        id: env_id
      }
    end)
    nmutable2
  end

  @doc "Get the environment data from the execution context"
  @spec env_ref(t) :: %{}
  def env_ref(mutable) do
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
  @spec env_get_errors(t) :: [any]
  def env_get_errors(mutable) do
    mutable.errors
  end

  @doc """
  Set a key and value in the environment without making
  a new environment hierarchy
  """
  @spec env_set(t, any, any) :: t
  def env_set(mutable, key, value) do
    {env_id, nmutable1} = env_inc(mutable)
    nmutable2 = update_in(nmutable1, [Access.key!(:environment), Access.key!(:vals)], fn m ->
      Map.put(m, key, value)
    end)
    nmutable3 = update_in(nmutable2, [Access.key!(:environment), Access.key!(:id)], fn _ ->
      env_id
    end)
    nmutable3
  end

  @doc "Merge another environment into the current environment"
  @spec env_merge(t, %{}) :: t
  def env_merge(mutable, %{vals: values}) do
    nmutable = update_in(mutable, [Access.key!(:environment), Access.key!(:vals)], fn m ->
      Map.merge(m, values)
    end)
    nmutable
  end

  @doc "Look up a symbol in the execution context."
  @spec env_lookup(t, any) :: {:ok, any} | :not_found
  def env_lookup(mutable, key) do
    env_get(mutable.environment, key)
  end

  @doc "Find a symbol in the selected environment."
  @spec env_retrieve_key(%{}, any) :: {:ok, any} | :not_found
  def env_retrieve_key(environment, key) do
    case get_in(environment, [Access.key!(:vals)]) do
      nil -> :not_found
      vals ->
        case Map.get(vals, key, :not_found) do
          :not_found -> :not_found
          res -> {:ok, res}
        end
    end
  end

  @doc "Find a symbol in a hierarchy of environments"
  @spec env_retrieve_key(%{}, any) :: {:ok, any} | :not_found
  def env_get(environment, key) do
    case env_retrieve_key(environment, key) do
      :not_found ->
        case environment.outer do
          nil -> :not_found
          parent -> env_get(parent, key)
        end
      {:ok, val} -> {:ok, val}
    end
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
end
