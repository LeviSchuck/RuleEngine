defmodule RuleEngineMutableTest do
  use ExUnit.Case
  import RuleEngine.Mutable
  alias RuleEngine.Mutable
  alias RuleEngine.Environment

  test "mutable: atom new" do
    val = :secret
    mut_before = %Mutable{}
    mut_expected = %Mutable{
      next_atom: 2,
      atoms: %{1 => val}
    }
    {mut_after, atom} = atom_new(mut_before, val)
    assert mut_expected == mut_after
    assert atom == 1
  end

  test "mutable: atom deref" do
    val = :secret
    atom_key = 1
    mut_before = %Mutable{
      atoms: %{atom_key => val}
    }
    {mut_after, result} = atom_deref(mut_before, atom_key)
    assert val == result
    assert mut_before == mut_after
  end

  test "mutable: atom reset!" do
    val_before = :secret1
    val_after = :secret2
    atom_key = 1
    mut_before = %Mutable{
      atoms: %{atom_key => val_before}
    }
    mut_expected = %Mutable{
      atoms: %{atom_key => val_after}
    }
    {mut_after, result} = atom_reset!(mut_before, atom_key, val_after)
    assert mut_expected == mut_after
    assert result == val_after
  end

  def bootstrap_raw() do
    %{boot: true}
  end
  def bootstrap() do
    Environment.make(bootstrap_raw(), 0, :bootstrap)
  end

  test "mutable: environment push" do
    vals = %{test: 123}
    mut_before = %Mutable{
      environment: bootstrap(),
    }
    mut_expected = %Mutable{
      environment: Environment.make(vals, 1, bootstrap(), :test),
      environment_id: 2,
    }
    mut_after = layer(mut_before, vals, :test)
    assert mut_expected == mut_after
  end

  test "mutable: environment set existing" do
    vals = %{test: 123}
    overwrite = 345
    env = Environment.make(vals, 1, bootstrap())
    mut_before = %Mutable{
      environment: env,
      environment_id: 2,
    }
    mut_expected = %Mutable{
      environment: %{env |
        vals: %{test: overwrite},
        id: 2
      },
      environment_id: 3
    }
    mut_after = set(mut_before, :test, overwrite)
    assert mut_expected == mut_after
  end

  test "mutable: environment set over" do
    vals = %{test: 123}
    overwrite = 333
    env = Environment.make(%{abc: 999}, 1, bootstrap())
    env = Environment.make(vals, 2, env)
    mut_before = %Mutable{
      environment: env,
      environment_id: 2
    }
    mut_expected = %Mutable{
      environment: %{env|
        vals: Map.put(env.vals, :abc, overwrite),
        id: 2,
      },
      environment_id: 3
    }
    mut_after = set(mut_before, :abc, overwrite)
    assert mut_expected == mut_after
  end

  test "mutable: environment labeled get" do
    env = Environment.make(%{abc: 123}, 1, bootstrap(), :depth1)
    env = Environment.make(%{test1: 456}, 2, env, :depth2)
    env = Environment.make(%{test20: 20}, 3, env, :depth3)
    env = Environment.make(%{test80: 80}, 4, env, :depth4)

    assert :not_found == Environment.get(env, :abc, :depth4)
    assert :not_found == Environment.get(env, :abc, :depth3)
    assert :not_found == Environment.get(env, :abc, :depth2)
    assert {:ok, 123} == Environment.get(env, :abc, :depth1)

    assert :not_found == Environment.get(env, :test1, :depth4)
    assert :not_found == Environment.get(env, :test1, :depth3)
    assert {:ok, 456} == Environment.get(env, :test1, :depth2)
    assert :not_found == Environment.get(env, :test1, :depth1)

    assert :not_found == Environment.get(env, :test20, :depth4)
    assert {:ok, 20} == Environment.get(env, :test20, :depth3)
    assert :not_found == Environment.get(env, :test20, :depth2)
    assert :not_found == Environment.get(env, :test20, :depth1)

    assert {:ok, 80} == Environment.get(env, :test80, :depth4)
    assert :not_found == Environment.get(env, :test80, :depth3)
    assert :not_found == Environment.get(env, :test80, :depth2)
    assert :not_found == Environment.get(env, :test80, :depth1)

  end

  test "mutable: environment hierarchical get" do
    env = Environment.make(%{abc: 123}, 1, bootstrap(), :depth1)
    env = Environment.make(%{test1: 456}, 2, env, :depth2)
    assert {:ok, 456} == Environment.get(env, :test1)
    assert :not_found == Environment.get(env, :test2)
    assert {:ok, 123} == Environment.get(env, :abc)
    assert {:ok, true} == Environment.get(env, :boot)
  end

  test "mutable: environment labeled put" do
    env = Environment.make(%{}, 1, bootstrap(), :depth1)
    env = Environment.make(%{}, 2, env, :depth2)
    env = Environment.make(%{}, 3, env, :depth3)
    env = Environment.make(%{}, 4, env, :depth4)
    env = Environment.put(env, :test1, 456, :depth2)
    env = Environment.put(env, :abc, 123, :depth1)
    env = Environment.put(env, :test80, 80, :depth4)
    env = Environment.put(env, :test20, 20, :depth3)

    assert :not_found == Environment.get(env, :abc, :depth4)
    assert :not_found == Environment.get(env, :abc, :depth3)
    assert :not_found == Environment.get(env, :abc, :depth2)
    assert {:ok, 123} == Environment.get(env, :abc, :depth1)

    assert :not_found == Environment.get(env, :test1, :depth4)
    assert :not_found == Environment.get(env, :test1, :depth3)
    assert {:ok, 456} == Environment.get(env, :test1, :depth2)
    assert :not_found == Environment.get(env, :test1, :depth1)

    assert :not_found == Environment.get(env, :test20, :depth4)
    assert {:ok, 20} == Environment.get(env, :test20, :depth3)
    assert :not_found == Environment.get(env, :test20, :depth2)
    assert :not_found == Environment.get(env, :test20, :depth1)

    assert {:ok, 80} == Environment.get(env, :test80, :depth4)
    assert :not_found == Environment.get(env, :test80, :depth3)
    assert :not_found == Environment.get(env, :test80, :depth2)
    assert :not_found == Environment.get(env, :test80, :depth1)
  end

end
