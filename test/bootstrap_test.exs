defmodule RuleEngineBootstrapTest do
  use ExUnit.Case
  import RuleEngine.Bootstrap
  import RuleEngine.Types
  alias RuleEngine.Mutable
  alias RuleEngine.Reduce

  @o bootstrap_origin()
  @sfalse symbol(false, @o)
  @strue symbol(true, @o)

  def execute(fun, args) do
    {res, _} = eval(fun, args)
    res
  end
  def eval(fun, args) do
    fun.value.(args).(bootstrap_mutable())
  end
  def execute_log_errors(fun, args) do
    mutable = Mutable.errors_log(bootstrap_mutable())
    {res, _} = Reduce.reduce(list([fun | args])).(mutable)
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
    assert @strue == execute(fun, [symbol("hello"), symbol("hello")])
    assert @sfalse == execute(fun, [symbol("abc"), number(123)])
  end

  test "bootstrap: !=" do
    fun = gfun("!=")
    assert @sfalse == execute(fun, [symbol("hello"), symbol("hello")])
    assert @strue == execute(fun, [symbol("abc"), number(123)])
  end

  test "bootstrap: <" do
    fun = gfun("<")
    assert @strue == execute(fun, [number(100), number(200)])
    assert @sfalse == execute(fun, [number(100), number(100)])
    assert @sfalse == execute(fun, [number(200), number(100)])
  end

  test "bootstrap: >" do
    fun = gfun(">")
    assert @sfalse == execute(fun, [number(100), number(200)])
    assert @sfalse == execute(fun, [number(100), number(100)])
    assert @strue == execute(fun, [number(200), number(100)])
  end

  test "bootstrap: <=" do
    fun = gfun("<=")
    assert @strue == execute(fun, [number(100), number(200)])
    assert @strue == execute(fun, [number(100), number(100)])
    assert @sfalse == execute(fun, [number(200), number(100)])
  end

  test "bootstrap: >=" do
    fun = gfun(">=")
    assert @sfalse == execute(fun, [number(100), number(200)])
    assert @strue == execute(fun, [number(100), number(100)])
    assert @strue == execute(fun, [number(200), number(100)])
  end

  test "bootstrap: &&" do
    fun = gfun("&&")
    assert @sfalse == execute(fun, [@sfalse, @sfalse])
    assert @sfalse == execute(fun, [@strue, @sfalse])
    assert @sfalse == execute(fun, [@sfalse, @strue])
    assert @strue == execute(fun, [@strue, @strue])
  end

  test "bootstrap: ||" do
    fun = gfun("||")
    assert @sfalse == execute(fun, [@sfalse, @sfalse])
    assert @strue == execute(fun, [@strue, @sfalse])
    assert @strue == execute(fun, [@sfalse, @strue])
    assert @strue == execute(fun, [@strue, @strue])
  end

  test "bootstrap: ++" do
    fun = gfun("++")
    assert string("", @o) == execute(fun, [string(""), string("")])
    assert string("a", @o) == execute(fun, [string(""), string("a")])
    assert string("a", @o) == execute(fun, [string("a"), string("")])
    assert string("ab", @o) == execute(fun, [string("a"), string("b")])
  end

  test "bootstrap: +" do
    fun = gfun("+")
    assert number(100+200, @o) == execute(fun, [number(100), number(200)])
    assert number(100+100, @o) == execute(fun, [number(100), number(100)])
    assert number(100+100+100, @o) == execute(fun, [number(100), number(100), number(100)])
    assert number(100, @o) == execute(fun, [number(100)])
  end

  test "bootstrap: -" do
    fun = gfun("-")
    assert number(100-200, @o) == execute(fun, [number(100), number(200)])
    assert number(100-100, @o) == execute(fun, [number(100), number(100)])
    assert number(100-100-100, @o) == execute(fun, [number(100), number(100), number(100)])
    assert number(-100, @o) == execute(fun, [number(100)])
  end

  test "bootstrap: and" do
    fun = gfun("and")
    assert @strue == execute(fun, [])
    assert @strue == execute(fun, [@strue])
    assert @strue == execute(fun, [@strue, @strue])
    assert @sfalse == execute(fun, [@strue, @sfalse])
    assert @sfalse == execute(fun, [@sfalse, @strue])
    assert @sfalse == execute(fun, [@sfalse, @sfalse])
  end

  test "bootstrap: or" do
    fun = gfun("or")
    assert @sfalse == execute(fun, [])
    assert @strue == execute(fun, [@strue])
    assert @strue == execute(fun, [@strue, @strue])
    assert @strue == execute(fun, [@strue, @sfalse])
    assert @strue == execute(fun, [@sfalse, @strue])
    assert @sfalse == execute(fun, [@sfalse, @sfalse])
  end

  test "bootstrap: map" do
    fun = gfun("map")
    opinc = function(fn [arg] ->
      fn state ->
        {number(arg.value + 1), state}
      end
    end)
    assert list([number(2), number(3)], @o) == execute(fun, [
      list([
        symbol("quote"),
        list([number(1), number(2)])
        ]),
      opinc
      ])
  end

  test "bootstrap: reduce" do
    fun = gfun("reduce")
    assert number(5, @o) == execute(fun, [
      list([symbol("quote"), list([number(3), number(2)])]),
      number(0),
      symbol("+")
      ])
  end

  test "bootstrap: nil?" do
    fun = gfun("nil?")
    assert @sfalse == execute(fun, [number(100)])
    assert @strue == execute(fun, [symbol(nil)])
  end

  test "bootstrap: boolean?" do
    fun = gfun("boolean?")
    assert @sfalse == execute(fun, [number(100)])
    assert @strue == execute(fun, [symbol(nil)])
    assert @strue == execute(fun, [@strue])
    assert @strue == execute(fun, [@sfalse])
  end

  test "bootstrap: symbol?" do
    fun = gfun("symbol?")
    assert @sfalse == execute(fun, [number(100)])
    assert @strue == execute(fun, [symbol(nil)])
    assert @strue == execute(fun, [symbol("cheese")])
  end

  test "bootstrap: list?" do
    fun = gfun("list?")
    assert @sfalse == execute(fun, [number(100)])
    assert @strue == execute(fun, [list([])])
    assert @strue == execute(fun, [list([symbol(nil), number(100)])])
  end

  test "bootstrap: dict?" do
    fun = gfun("dict?")
    assert @sfalse == execute(fun, [number(100)])
    assert @sfalse == execute(fun, [list([])])
    assert @strue == execute(fun, [dict(%{symbol("hello") => number(100)})])
  end

  test "bootstrap: string?" do
    fun = gfun("string?")
    assert @sfalse == execute(fun, [number(100)])
    assert @sfalse == execute(fun, [symbol(nil)])
    assert @sfalse == execute(fun, [symbol("cheese")])
    assert @strue == execute(fun, [string("cheese")])
  end

  test "bootstrap: macro?" do
    fun = gfun("macro?")
    assert @strue == execute(fun, [macro(fn x -> x end)])
    assert @sfalse == execute(fun, [symbol("hello")])
  end

  test "bootstrap: if" do
    fun = gfun("if")
    s1 = string("abc")
    s2 = string("def")
    assert s1 == execute(fun, [@strue, s1, s2])
    assert s2 == execute(fun, [@sfalse, s1, s2])
    assert s1 == execute(fun, [@strue, s1])
    assert symbol(nil) == execute(fun, [@sfalse, s1])
  end

  test "bootstrap: if bad" do
    fun = gfun("if")
    s1 = string("abc")
    s2 = string("def")
    assert(try do
      execute(fun, [number(3), s1, s2])
      false
    catch
      _ -> true
    end)
    assert symbol(nil, mko(:error)) == execute_log_errors(fun, [number(3), s1, s2])
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
    assert @strue == fun
  end

  test "bootstrap: false" do
    fun = gfun("false")
    assert @sfalse == fun
  end

  test "bootstrap: nil" do
    fun = gfun("nil")
    assert symbol(nil, @o) == fun
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
    assert number(n1 + n1 + n2, @o) == execute(let_fun, [
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

  test "bootstrap: def" do
    def_fun = gfun("def")
    key = "x"
    sy = symbol(key)
    n1 = number(100)
    {res, state} = eval(def_fun, [sy, n1])
    assert res == n1
    assert state.environment.vals[key] == n1
  end

  test "bootstrap: apply" do
    app_fun = gfun("apply")
    assert number(5, @o) == execute(app_fun, [
      symbol("+"),
      list([
        symbol("quote"),
        list([
          number(1),
          number(1),
          number(3)
          ])
        ])
      ])
  end
end
