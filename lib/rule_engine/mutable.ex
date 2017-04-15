defmodule RuleEngine.Mutable do
  defstruct [
    next_atom: 1,
    atoms: %{},
    environment: %{},
    environment_id: 1,
    reductions: 0,
    max_reductions: :infinite,
  ]

  def atom_new(mutable, value) do
    {[natom], nmutable1} = get_and_update_in(
      mutable,
      [Lens.key(:next_atom)],
      fn x ->
        {x, x + 1}
      end)
    nmutable2 = update_in(nmutable1, [Lens.key(:atoms)], fn atoms ->
      Map.put(atoms, natom, value)
    end)
    {nmutable2, natom}
  end

  def atom_deref(mutable, atom) do
    {mutable, Map.get(mutable.atoms, atom, :not_found)}
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

  def env_inc(mutable) do
    lens = [Lens.key(:environment_id)]
    {[eid], nmutable} = get_and_update_in(mutable, lens, fn x ->
      {x, x + 1}
    end)
    {eid, nmutable}
  end
  def env_override(mutable, environment) do
    nmutable = update_in(mutable, [Lens.key(:environment)], fn _ ->
      environment
    end)
    nmutable
  end
  def env_new(mutable, data) do
    {env_id, nmutable1} = env_inc(mutable)
    nmutable2 = update_in(nmutable1, [Lens.key(:environment)], fn outer ->
      %{
        outer: outer,
        vals: data,
        id: env_id
      }
    end)
    nmutable2
  end
  def env_new(mutable, outer, data) do
    {env_id, nmutable1} = env_inc(mutable)
    nmutable2 = update_in(nmutable1, [Lens.key(:environment)], fn _ ->
      %{
        outer: outer,
        vals: data,
        id: env_id
      }
    end)
    nmutable2
  end
  def env_ref(mutable) do
    mutable.environment
  end

  def env_set(mutable, key, value) do
    {env_id, nmutable1} = env_inc(mutable)
    lens_vals = Lens.key(:environment)
      |> Lens.key(:vals)
    lens_id = Lens.key(:environment)
      |> Lens.key(:id)
    nmutable2 = update_in(nmutable1, [lens_vals], fn m ->
      Map.put(m, key, value)
    end)
    nmutable3 = update_in(nmutable2, [lens_id], fn _ ->
      env_id
    end)
    nmutable3
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

  def reductions_inc(mutable) do
    update_in(mutable, [Lens.key(:reductions)], fn x ->
      x + 1
    end)
  end
  def reductions_reset(mutable) do
    update_in(mutable, [Lens.key(:reductions)], fn _ ->
      0
    end)
  end
  def reductions_max(mutable, maximum) do
    update_in(mutable, [Lens.key(:max_reductions)], fn _ ->
      maximum
    end)
  end
end
