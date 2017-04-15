defmodule RuleEngineMutableTest do
  use ExUnit.Case
  import RuleEngine.Mutable
  alias RuleEngine.Mutable

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

  def bootstrap() do
    %{
      outer: nil,
      vals: %{boot: true}
    }
  end

  test "mutable: environment new" do
    vals = %{test: 123}
    mut_before = %Mutable{}
    mut_expected = %Mutable{
      environment: %{
        outer: bootstrap(),
        vals: vals,
        id: 1,
      },
      environment_id: 2,
    }
    mut_after = env_new(mut_before, bootstrap(), vals)
    assert mut_expected == mut_after
  end

  test "mutable: environment set existing" do
    vals = %{test: 123}
    overwrite = 345
    env = %{
      outer: bootstrap(),
      vals: vals,
      id: 1
    }
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
    mut_after = env_set(mut_before, :test, overwrite)
    assert mut_expected == mut_after
  end

  test "mutable: environment set over" do
    vals = %{test: 123}
    overwrite = 333
    env = %{
      outer: %{
        outer: bootstrap(),
        vals: %{abc: 999}
      },
      vals: vals,
      id: 1,
    }
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
    mut_after = env_set(mut_before, :abc, overwrite)
    assert mut_expected == mut_after
  end
  test "mutable: environment merge" do
    env1 = %{
      outer: %{
        outer: bootstrap(),
        vals: %{abc: 123}
      },
      vals: %{test1: 123}
    }
    env2 = %{
      outer: %{
        outer: bootstrap(),
        vals: %{abc: 456}
      },
      vals: %{test2: 123}
    }
    mut_before = %Mutable{
      environment: env1
    }
    mut_expected = %Mutable{
      environment: %{env1|
        vals: %{test1: 123, test2: 123}
      }
    }
    mut_after = env_merge(mut_before, env2)
    assert mut_expected == mut_after
  end

  test "mutable: environment local get" do
    env = %{
      outer: %{
        outer: bootstrap(),
        vals: %{abc: 123}
      },
      vals: %{test1: 456}
    }
    assert {:ok, 456} == env_retrieve_key(env, :test1)
    assert :not_found == env_retrieve_key(env, :test2)
    assert :not_found == env_retrieve_key(env, :abc)
  end

  test "mutable: environment hierarchical get" do
    env = %{
      outer: %{
        outer: bootstrap(),
        vals: %{abc: 123}
      },
      vals: %{test1: 456}
    }
    assert {:ok, 456} == env_get(env, :test1)
    assert :not_found == env_get(env, :test2)
    assert {:ok, 123} == env_get(env, :abc)
    assert {:ok, true} == env_get(env, :boot)
  end

end
