defmodule RuleEngineBootstrapTest do
  use ExUnit.Case
  import RuleEngine.Bootstrap
  import RuleEngine.Types

  def execute(fun, args) do
    {res, _} = fun.value.(args).(bootstrap_mutable())
    res
  end
  def gfun(key) do
    fun = case bootstrap_environment() do
      %{vals: v} -> Map.get(v, key)
    end
    fun
  end

  test "bootstrap: ==" do
    fun = gfun("==")
    assert symbol(true) == execute(fun, [symbol("hello"), symbol("hello")])
    assert symbol(false) == execute(fun, [symbol("abc"), number(123)])
  end
  test "bootstrap: !=" do
    fun = gfun("!=")
    assert symbol(false) == execute(fun, [symbol("hello"), symbol("hello")])
    assert symbol(true) == execute(fun, [symbol("abc"), number(123)])
  end

  test "bootstrap: <" do
    fun = gfun("<")
    assert symbol(true) == execute(fun, [number(100), number(200)])
    assert symbol(false) == execute(fun, [number(100), number(100)])
    assert symbol(false) == execute(fun, [number(200), number(100)])
  end
  test "bootstrap: >" do
    fun = gfun(">")
    assert symbol(false) == execute(fun, [number(100), number(200)])
    assert symbol(false) == execute(fun, [number(100), number(100)])
    assert symbol(true) == execute(fun, [number(200), number(100)])
  end

  test "bootstrap: <=" do
    fun = gfun("<=")
    assert symbol(true) == execute(fun, [number(100), number(200)])
    assert symbol(true) == execute(fun, [number(100), number(100)])
    assert symbol(false) == execute(fun, [number(200), number(100)])
  end
  test "bootstrap: >=" do
    fun = gfun(">=")
    assert symbol(false) == execute(fun, [number(100), number(200)])
    assert symbol(true) == execute(fun, [number(100), number(100)])
    assert symbol(true) == execute(fun, [number(200), number(100)])
  end
  test "bootstrap: +" do
    fun = gfun("+")
    assert number(100+200) == execute(fun, [number(100), number(200)])
    assert number(100+100) == execute(fun, [number(100), number(100)])
    assert number(100+100+100) == execute(fun, [number(100), number(100), number(100)])
    assert number(100) == execute(fun, [number(100)])
  end
  test "bootstrap: -" do
    fun = gfun("-")
    assert number(100-200) == execute(fun, [number(100), number(200)])
    assert number(100-100) == execute(fun, [number(100), number(100)])
    assert number(100-100-100) == execute(fun, [number(100), number(100), number(100)])
    assert number(-100) == execute(fun, [number(100)])
  end
  test "bootstrap: nil?" do
    fun = gfun("nil?")
    assert symbol(false) == execute(fun, [number(100)])
    assert symbol(true) == execute(fun, [symbol(nil)])
  end
  test "bootstrap: boolean?" do
    fun = gfun("boolean?")
    assert symbol(false) == execute(fun, [number(100)])
    assert symbol(true) == execute(fun, [symbol(nil)])
    assert symbol(true) == execute(fun, [symbol(true)])
    assert symbol(true) == execute(fun, [symbol(false)])
  end
  test "bootstrap: symbol?" do
    fun = gfun("symbol?")
    assert symbol(false) == execute(fun, [number(100)])
    assert symbol(true) == execute(fun, [symbol(nil)])
    assert symbol(true) == execute(fun, [symbol("cheese")])
  end
  test "bootstrap: list?" do
    fun = gfun("list?")
    assert symbol(false) == execute(fun, [number(100)])
    assert symbol(true) == execute(fun, [list([])])
    assert symbol(true) == execute(fun, [list([symbol(nil), number(100)])])
  end
  test "bootstrap: map?" do
    fun = gfun("map?")
    assert symbol(false) == execute(fun, [number(100)])
    assert symbol(false) == execute(fun, [list([])])
    assert symbol(true) == execute(fun, [map(%{symbol("hello") => number(100)})])
  end
  test "bootstrap: string?" do
    fun = gfun("string?")
    assert symbol(false) == execute(fun, [number(100)])
    assert symbol(false) == execute(fun, [symbol(nil)])
    assert symbol(false) == execute(fun, [symbol("cheese")])
    assert symbol(true) == execute(fun, [string("cheese")])
  end

  test "bootstrap: macro?" do
    fun = gfun("macro?")
    assert symbol(true) == execute(fun, [macro(fn x -> x end)])
    assert symbol(false) == execute(fun, [symbol("hello")])
  end

  test "bootstrap: if" do
    fun = gfun("if")
    s1 = string("abc")
    s2 = string("def")
    assert s1 == execute(fun, [symbol(true), s1, s2])
    assert s2 == execute(fun, [symbol(false), s1, s2])
  end

  test "bootstrap: quote" do
    fun = gfun("quote")
    s1 = string("abc")
    l1 = list([s1,s1,s1])
    assert l1 == execute(fun, [l1])
    assert s1 == execute(fun, [s1])
  end

  test "bootstrap: do" do
    fun = gfun("do")
    s1 = string("abc")
    s2 = string("def")
    s3 = string("ghi")
    l1 = [s1,s2,s3]
    l2 = [s1]
    assert s3 == execute(fun, l1)
    assert s1 == execute(fun, l2)
  end

  test "bootstrap: true" do
    fun = gfun("true")
    assert fun == symbol(true)
  end

  test "bootstrap: false" do
    fun = gfun("false")
    assert fun == symbol(false)
  end

  test "bootstrap: nil" do
    fun = gfun("nil")
    assert fun == symbol(nil)
  end

  test "bootstrap: atom" do
    fun = gfun("atom")
    assert atom(1) == execute(fun, [symbol(nil)])
  end

  test "bootstrap: atom set" do
    do_fun = gfun("do")
    v1 = number(123)
    v2 = number(234)
    hard_atom = atom(1)
    assert v2 == execute(do_fun, [
      list([symbol("atom"), v1]),
      list([symbol("reset!"), hard_atom, v2]),
      ])
  end

  test "bootstrap: atom deref" do
    do_fun = gfun("do")
    v1 = number(123)
    hard_atom = atom(1)
    assert v1 == execute(do_fun, [
      list([symbol("atom"), v1]),
      list([symbol("deref"), hard_atom]),
      ])
  end

  test "bootstrap: let" do
    let_fun = gfun("let")
    v1 = number(123)
    sy = symbol("x")
    opid = function(fn [arg] ->
      fn state ->
        {arg, state}
      end
    end)
    assert v1 == execute(let_fun, [
      list([sy, v1]),
      list([opid, sy])
      ])
  end

  test "bootstrap: fn" do
    let_fun = gfun("let")
    n1 = 10
    n2 = 100
    sy_x = symbol("x")
    sy_y = symbol("y")
    sy_fn = symbol("fn")
    sy_plus = symbol("+")
    assert number(n1 + n1 + n2) == execute(let_fun, [
      list([sy_y, number(n2)]),
      list([
        list([
          sy_fn,
          list([sy_x]),
          list([sy_plus, sy_x, sy_x, sy_y])
          ]),
        number(n1)
        ])
      ])
  end
end
