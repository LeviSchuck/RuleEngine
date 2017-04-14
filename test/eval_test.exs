defmodule RuleEngineEvalTest do
  use ExUnit.Case
  doctest RuleEngine
  import RuleEngine.Types
  import RuleEngine.Reduce

  test "reduce number" do
    v1 = number(1)
    {res, _} = reduce(v1).(nil)
    assert res == v1
  end

  test "reduce string" do
    v1 = string("hello")
    {res, _} = reduce(v1).(nil)
    assert res == v1
  end

end
