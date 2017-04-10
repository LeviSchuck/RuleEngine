defmodule RuleEngine.Mutable do
  defstruct [
    next_atom: 1,
    atoms: %{},
    next_env: 1,
    environments: %{}
  ]
  def atom_new(mutable, value) do
    natom = mutable.next_atom
    nmutable = %__MODULE__{mutable |
      next_atom: natom + 1,
      atoms: %{mutable.atoms | natom => value}
    }
    {nmutable, natom}
  end
  def atom_deref(mutable, atom) do
    {mutable, Map.get(mutable.atoms, atom)}
  end
  def atom_reset!(mutable, atom, value) do
    lens = Lens.key(:atoms)
      |> Lens.key(atom)
    nmutable = update_in(mutable, [lens], fn _ -> value end)
    {nmutable, value}
  end
  def atom_swap!(mutable, atom, fun) do
    lens = Lens.key(:atoms)
      |> Lens.key(atom)
    {value, nmutable} = get_and_update_in(mutable, [lens], fun)
    {nmutable, value}
  end
  def env_new(mutable, outer, binds, exprs) do
    nenv = mutable.next_env
    data = Enum.zip(binds, exprs)
      |> Enum.into(%{})
    env = %{
      outer: outer,
      vals: data
    }
    nmutable = %__MODULE__{mutable |
      next_env: nenv + 1,
      environments: %{mutable.environments | nenv => env}
    }
    {nmutable, nenv}
  end
  def env_set(mutable, env, key, value) do
    lens = Lens.key(:environments)
      |> Lens.key(env)
    nmutable = update_in(mutable, [lens], fn m ->
      Map.put(m, key, value)
    end)
    {nmutable, value}
  end
  def env_merge(mutable, env, values) do
    lens = Lens.key(:environments)
      |> Lens.key(env)
    nmutable = update_in(mutable, [lens], fn m ->
      Map.merge(m, values)
    end)
    {nmutable, nil}
  end
  def env_lens(env), do: Lens.key(:environments) |> Lens.key(env)
  def env_retrieve_key(mutable, env, key) do
    lens = env_lens(env)
      |> Lens.key(:vals)
      |> Lens.key(key)
    case get_in(mutable, [lens]) do
      [] -> {mutable, :not_found}
      [head | _] -> {mutable, {:ok, head}}
    end
  end
  def env_get(mutable, env, key) do
    parent = env_lens(env)
      |> Lens.key(:outer)
    case env_retrieve_key(mutable, env, key) do
      {nmut, :not_found} ->
        case get_in(mutable, [parent]) do
          [outer | _] -> env_get(nmut, outer, key)
          [] -> {nmut, :not_found}
        end
      {nmut, {:ok, val}} -> {nmut, {:ok, val}}
    end
  end
end
