defmodule RuleEngineTest do
  use ExUnit.Case
  doctest RuleEngine
  require RuleEngine.AST
  import RuleEngine.AST
  import RuleEngine.Eval

  test "equals true" do
    op = app(:equals, [literal(1), literal(1)])
    st = %{}
    {:ok, true, ^st} = eval_app(op, st)
  end

  test "equals false" do
    op = app(:equals, [literal(1), literal(2)])
    st = %{}
    {:ok, false, ^st} = eval_app(op, st)
  end

  test "equals incomplete false" do
    op = app(:equals, [literal(1)])
    st = %{}
    {:ok, false, ^st} = eval_app(op, st)
  end

  test "less than" do
    st = %{}
    op1 = app(:less_than, [literal(1), literal(2)])
    {:ok, true, ^st} = eval_app(op1, st)
    op2 = app(:less_than, [literal(1), literal(1)])
    {:ok, false, ^st} = eval_app(op2, st)
    op3 = app(:less_than, [literal(1), literal(0)])
    {:ok, false, ^st} = eval_app(op3, st)
  end

  test "greater than" do
    st = %{}
    op1 = app(:greater_than, [literal(1), literal(2)])
    {:ok, false, ^st} = eval_app(op1, st)
    op2 = app(:greater_than, [literal(1), literal(1)])
    {:ok, false, ^st} = eval_app(op2, st)
    op3 = app(:greater_than, [literal(1), literal(0)])
    {:ok, true, ^st} = eval_app(op3, st)
  end

  test "less than or equal" do
    st = %{}
    op1 = app(:less_than_or_equals, [literal(1), literal(2)])
    {:ok, true, ^st} = eval_app(op1, st)
    op2 = app(:less_than_or_equals, [literal(1), literal(1)])
    {:ok, true, ^st} = eval_app(op2, st)
    op3 = app(:less_than_or_equals, [literal(1), literal(0)])
    {:ok, false, ^st} = eval_app(op3, st)
  end

  test "greater than or equal" do
    st = %{}
    op1 = app(:greater_than_or_equals, [literal(1), literal(2)])
    {:ok, false, ns1} = eval_app(op1, st)
    assert ns1 == st
    op2 = app(:greater_than_or_equals, [literal(1), literal(1)])
    {:ok, true, ns2} = eval_app(op2, st)
    assert ns2 == st
    op3 = app(:greater_than_or_equals, [literal(1), literal(0)])
    {:ok, true, ns3} = eval_app(op3, st)
    assert ns3 == st
  end

  test "not" do
    st = %{}
    op1 = app(:not, [literal(true)])
    {:ok, false, ^st} = eval_app(op1, st)
    op2 = app(:not, [literal(false)])
    {:ok, true, ^st} = eval_app(op2, st)
  end

  test "is_nil" do
    st = %{}
    op1 = app(:is_nil, [literal(true)])
    {:ok, false, ^st} = eval_app(op1, st)
    op2 = app(:is_nil, [literal(nil)])
    {:ok, true, ^st} = eval_app(op2, st)
  end

  test "set over nothing" do
    ast = [
      app(:set, [literal(1), literal(true)])
    ]
    {:ok, st} = exec(ast, %{})
    expects = %{
      1 => true
    }
    assert st == expects
  end

  test "set over something once" do
    ast = [
      app(:set, [literal(1), literal(true)])
    ]
    state = %{1 => false}
    {:ok, st} = exec(ast, state)
    expects = %{
      1 => true
    }
    assert st == expects
  end
  test "set over something twice" do
    ast = [
      app(:set, [literal(1), literal(1)]),
      app(:set, [literal(1), literal(2)]),
    ]
    state = %{1 => 0}
    {:ok, st} = exec(ast, state)
    expects = %{
      1 => 2
    }
    assert st == expects
  end

  test "get nil" do
    op = app(:get, [literal(1), literal(true)])
    st = %{}
    {:ok, val, ^st} = eval_app(op, st)
    assert val == nil
  end

  test "get val" do
    op = app(:get, [literal(1), literal(true)])
    st = %{1 => true}
    {:ok, val, _} = eval_app(op, st)
    assert val == true
  end

  test "literal" do
    st = %{}
    {:ok, 1, ns1} = eval_app(literal(1), st)
    assert ns1 == st
    {:ok, true, ns2} = eval_app(literal(true), st)
    assert ns2 == st
    {:ok, "hello", ns3} = eval_app(literal("hello"), st)
    assert ns3 == st
  end

  test "and all true" do
    op1 = app(:and, [
      literal(true),
      literal(true),
      ])
    st = %{}
    {:ok, true, ^st} = eval_app(op1, st)
  end

  test "and some true (true first)" do
    op1 = app(:and, [
      literal(true),
      literal(false),
      ])
    st = %{}
    {:ok, false, ns} = eval_app(op1, st)
    assert ns == st
  end

  test "and some true (true second)" do
    op = app(:and, [
      literal(false),
      literal(true),
      ])
    st = %{}
    {:ok, false, ns} = eval_app(op, st)
    assert ns == st
  end

  test "and all false" do
    op1 = app(:and, [
      literal(false),
      literal(false),
      ])
    st = %{}
    {:ok, false, ns} = eval_app(op1, st)
    assert ns == st
  end

  test "or all true" do
    op1 = app(:or, [
      literal(true),
      literal(true),
      ])
    st = %{}
    {:ok, true, ns} = eval_app(op1, st)
    assert ns == st
  end

  test "or some true (true first)" do
    op = app(:or, [
      literal(true),
      literal(false),
      ])
    st = %{}
    {:ok, true, ns} = eval_app(op, st)
    assert ns == st
  end

  test "or some true (true second)" do
    op = app(:or, [
      literal(false),
      literal(true),
      ])
    st = %{}
    {:ok, true, ns} = eval_app(op, st)
    assert ns == st
  end

  test "or all false" do
    op1 = app(:or, [
      literal(false),
      literal(false),
      ])
    st = %{}
    {:ok, false, ns} = eval_app(op1, st)
    assert ns == st
  end

  test "substring true" do
    op1 = app(:substring, [
      literal("hello"),
      literal("ll"),
      ])
    st = %{}
    {:ok, val, ns} = eval_app(op1, st)
    assert ns == st
    assert val == true
  end

  test "substring false" do
    op1 = app(:substring, [
      literal("hello"),
      literal("yolo"),
      ])
    st = %{}
    {:ok, val, ns} = eval_app(op1, st)
    assert ns == st
    assert val == false
  end

  test "exec set, get, and, or" do
    ast = [
      app(:set, [literal(1), literal(true)]),
      app(:set, [literal(2), literal(false)]),
      app(:set, [
        literal("AND-true"),
        app(:and, [
          app(:get, [literal(1)]),
          literal(true),
          ])
        ]),
      app(:set, [
        literal("AND-false"),
        app(:and, [
          app(:get, [literal(1)]),
          literal(false)
          ])
        ]),
      app(:set, [
        literal("OR-true"),
        app(:or, [
          literal(false),
          app(:get, [literal(1)]),
          literal(false)
          ])
        ]),
      app(:set, [
        literal("OR-false"),
        app(:or, [
          literal(false),
          app(:get, [literal(2)]),
          literal(false)
          ])
        ]),
    ]
    expects = %{
      1 => true,
      2 => false,
      "AND-false" => false,
      "AND-true" => true,
      "OR-false" => false,
      "OR-true" => true
    }
    {:ok, ns} = exec(ast, %{})
    assert ns == expects
  end

  test "cond none true" do
    op = app(:cond, [
      list([
        literal(false),
        app(:set, [literal("bad-1"), literal(true)]),
        ]),
      list([
        app(:equals, [literal(1), literal(2)]),
        app(:set, [literal("bad-2"), literal(true)]),
        ])
      ])
    st = %{}
    {:ok, val, ns} = eval_app(op, st)
    assert ns == st
    assert val == nil
  end

  test "cond one true" do
    op1 = app(:cond, [
      list([
        literal(false),
        app(:set, [literal("bad-1"), literal(true)]),
        ]),
      list([
        app(:equals, [literal(1), literal(1)]),
        app(:set, [literal("good-2"), literal(true)]),
        ])
      ])
    st = %{}
    expects = %{
      "good-2" => true
    }
    {:ok, val, ns} = eval_app(op1, st)
    assert ns == expects
    assert val == nil
  end

  test "cond multiple true" do
    op1 = app(:cond, [
      list([
        literal(false),
        app(:set, [literal("bad-1"), literal(true)]),
        ]),
      # only good-2 is expected to execute
      list([
        app(:equals, [literal(1), literal(1)]),
        app(:set, [literal("good-2"), literal(true)]),
        ]),
      list([
        app(:equals, [literal(1), literal(1)]),
        app(:set, [literal("good-3"), literal(true)]),
        ])
      ])
    st = %{}
    expects = %{
      "good-2" => true
    }
    {:ok, val, ns} = eval_app(op1, st)
    assert ns == expects
    assert val == nil
  end

end
