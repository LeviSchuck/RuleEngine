defmodule RuleEngineEvalTest do
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

end
