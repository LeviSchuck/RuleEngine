defmodule RuleEngineEvalTest do
  use ExUnit.Case
  doctest RuleEngine
  import RuleEngine.Types
  import RuleEngine.Reduce
  alias RuleEngine.Bootstrap
  alias RuleEngine.Mutable

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

  test "cross source def and use" do
    {:ok, defs1} = RuleEngine.parse_lisp("""
(def aaa 100)
(def abc (+ aaa aaa))
    """, :test1)

    {:ok, defs2} = RuleEngine.parse_lisp("""
(def aaad (fn (before-d) (+ before-d 999)))
(def xyz "test data")
(def abcd (aaad abc))
(def nnnn (fn () (+ aaa bbbb)))
    """, :test2)

    {:ok, defs3} = RuleEngine.parse_lisp("""
(def bbbb 200)
(def xyz2 (aaad abcd))
(def cccc (nnnn))
    """, :test3)

    env = Bootstrap.bootstrap_mutable() |> Mutable.layer()

    env = [defs1, defs2, defs3] |> Enum.reduce(env, fn x, env ->
      x |> Enum.reduce(env, fn x, env ->
        {_, env} = reduce(x).(env)
        env
      end)
    end)
    {aaa, _} = reduce(symbol("aaa")).(env)
    assert value_of(aaa) == 100

    {abc, _} = reduce(symbol("abc")).(env)
    assert value_of(abc) == value_of(aaa) + value_of(aaa)

    {aaad, _} = reduce(symbol("aaad")).(env)
    assert function?(aaad)

    {abcd, _} = reduce(symbol("abcd")).(env)
    assert value_of(abcd) == value_of(abc) + 999

    {xyz, _} = reduce(symbol("xyz")).(env)
    assert value_of(xyz) == "test data"

    {xyz2, _} = reduce(symbol("xyz2")).(env)
    assert value_of(xyz2) == value_of(abcd) + 999

    {cccc, _} = reduce(symbol("cccc")).(env)
    assert value_of(cccc) == value_of(aaa) + 200

    assert source_of(aaa) == :test1
    assert source_of(aaad) == :test2
    assert source_of(xyz) == :test2

  end
  test "Infinite recursion should like not be infinite" do
    {:ok, defs} = RuleEngine.parse_lisp("""
(def infinity (fn () (infinity)))
(infinity)
    """, :test1)
    env = Bootstrap.bootstrap_mutable()
      |> Mutable.push()
      |> Mutable.reductions_max(1000)
    try do
      defs |> Enum.reduce(env, fn x, env ->
        {_, env} = reduce(x).(env)
        env
      end)
      assert false
    catch
      {:crash, _} -> nil
    end

  end

end
