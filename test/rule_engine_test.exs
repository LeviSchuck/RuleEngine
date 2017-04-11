defmodule RuleEngineTest do
  use ExUnit.Case
  doctest RuleEngine
  import RuleEngine.Types
  import RuleEngine.Reduce
  require Monad.State, as: State

  test "reduce number" do
    v1 = number(1)
    {res, _} = State.run(nil, reduce(v1))
    assert res == v1
  end

  test "reduce string" do
    v1 = string("hello")
    {res, _} = State.run(nil, reduce(v1))
    assert res == v1
  end

  test "reduce list: do value is last" do
    v1 = number(1)
    v2 = number(2)
    fun = reduce(list([
      symbol("do"),
      v1,
      v2
      ]))
    {res, _} = State.run(nil, fun)
    assert res == v2
  end

  test "reduce list: if true" do
    v1 = number(1)
    v2 = number(2)
    fun = reduce(list([
      symbol("if"),
      symbol(true),
      v1,
      v2
      ]))
    {res, _} = State.run(nil, fun)
    assert res == v1
  end

  test "reduce list: if false" do
    v1 = number(1)
    v2 = number(2)
    fun = reduce(list([
      symbol("if"),
      symbol(false),
      v1,
      v2
      ]))
    {res, _} = State.run(nil, fun)
    assert res == v2
  end

  test "reduce list: quote is simple" do
    v1 = list([number(1), number(2)])
    fun = reduce(list([
      symbol("quote"),
      v1
      ]))
    {res, _} = State.run(nil, fun)
    assert res == v1
  end

  test "reduce list: arbitrary function" do
    arbitrary = fn [v1, v2] ->
      State.m do
        return number(v1.value + v2.value)
      end
    end
    n1 = 3
    n2 = 5
    fun = reduce(list([
      function(arbitrary),
      number(n1),
      number(n2)
      ]))
    {res, _} = State.run(nil, fun)
    assert res == number(n1 + n2)
  end

end
