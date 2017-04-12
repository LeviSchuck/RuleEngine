defmodule RuleEngine.Mutable do
  defstruct [
    next_atom: 1,
    atoms: %{},
    environment: %{}
  ]

  def atom_new(mutable, value) do
    {[natom], nmutable1} = get_and_update_in(mutable, [Lens.key(:next_atom)], fn x ->
      {x, x + 1}
    end)
    nmutable2 = update_in(nmutable1, [Lens.key(:atoms)], fn atoms ->
      Map.put(atoms, natom, value)
    end)
    {nmutable2, natom}
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

  def atom_swap!(mutable, atom, fun) when is_function(fun) do
    lens = Lens.key(:atoms)
      |> Lens.key(atom)
    {value, nmutable} = get_and_update_in(mutable, [lens], fn x ->
      result = fun.(x)
      {result, result}
    end)
    case value do
      [] -> {nmutable, {:no_such_atom, atom}}
      [val] -> {nmutable, {:ok, val}}
    end
  end

  def env_new(mutable, outer, data) do
    lens = Lens.key(:environment)
    nmutable = update_in(mutable, [lens], fn _ ->
      %{
        outer: outer,
        vals: data
      }
    end)
    nmutable
  end

  def env_set(mutable, key, value) do
    lens = Lens.key(:environment)
      |> Lens.key(:vals)
    nmutable = update_in(mutable, [lens], fn m ->
      Map.put(m, key, value)
    end)
    nmutable
  end

  def env_merge(mutable, %{vals: values}) do
    lens = Lens.key(:environment)
      |> Lens.key(:vals)
    nmutable = update_in(mutable, [lens], fn m ->
      Map.merge(m, values)
    end)
    nmutable
  end

  def env_lookup(mutable, key) do
    env_get(mutable.environment, key)
  end

  def env_retrieve_key(environment, key) do
    lens = Lens.key(:vals)
    case get_in(environment, [lens]) do
      [] -> :not_found
      [vals] ->
        case Map.get(vals, key, :not_found) do
          :not_found -> :not_found
          res -> {:ok, res}
        end
    end
  end
  
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
end
