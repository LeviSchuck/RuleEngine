defmodule RuleEngineBootstrapTest do
  use ExUnit.Case
  import RuleEngine.Bootstrap
  import RuleEngine.Types
  require Monad.State, as: State

  def execute(fun, args) do
    {res, _} = State.run(nil, fun.value.(args))
    res
  end

  test "bootstrap: ==" do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, "==")
    end
    assert symbol(true) == execute(fun, [symbol("hello"), symbol("hello")])
    assert symbol(false) == execute(fun, [symbol("abc"), number(123)])
  end
  test "bootstrap: !=" do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, "!=")
    end
    assert symbol(false) == execute(fun, [symbol("hello"), symbol("hello")])
    assert symbol(true) == execute(fun, [symbol("abc"), number(123)])
  end

  test "bootstrap: <" do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, "<")
    end
    assert symbol(true) == execute(fun, [number(100), number(200)])
    assert symbol(false) == execute(fun, [number(100), number(100)])
    assert symbol(false) == execute(fun, [number(200), number(100)])
  end
  test "bootstrap: >" do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, ">")
    end
    assert symbol(false) == execute(fun, [number(100), number(200)])
    assert symbol(false) == execute(fun, [number(100), number(100)])
    assert symbol(true) == execute(fun, [number(200), number(100)])
  end

  test "bootstrap: <=" do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, "<=")
    end
    assert symbol(true) == execute(fun, [number(100), number(200)])
    assert symbol(true) == execute(fun, [number(100), number(100)])
    assert symbol(false) == execute(fun, [number(200), number(100)])
  end
  test "bootstrap: >=" do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, ">=")
    end
    assert symbol(false) == execute(fun, [number(100), number(200)])
    assert symbol(true) == execute(fun, [number(100), number(100)])
    assert symbol(true) == execute(fun, [number(200), number(100)])
  end
  test "bootstrap: +" do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, "+")
    end
    assert number(100+200) == execute(fun, [number(100), number(200)])
    assert number(100+100) == execute(fun, [number(100), number(100)])
    assert number(5+8) == execute(fun, [number(5), number(8)])
  end
end
