defmodule RuleEngineTest do
  use ExUnit.Case
  doctest RuleEngine
  require RuleEngine.AST
  import RuleEngine.AST
  import RuleEngine.Eval

  test "equals true" do
    op = app(:equals, [literal(1), literal(1)])
    st = %{}
    {:ok, true, ^st, _} = eval_op(op, st)
  end

  test "equals false" do
    op = app(:equals, [literal(1), literal(2)])
    st = %{}
    {:ok, false, ^st, _} = eval_op(op, st)
  end

  test "equals incomplete false" do
    op = app(:equals, [literal(1)])
    st = %{}
    {:ok, false, ns, _} = eval_op(op, st)
    assert ns == st
  end

  test "less than" do
    st = %{}
    op1 = app(:less_than, [literal(1), literal(2)])
    {:ok, v1, ns1, _} = eval_op(op1, st)
    assert v1 == true
    assert ns1 == st

    op2 = app(:less_than, [literal(1), literal(1)])
    {:ok, v2, ns2, _} = eval_op(op2, st)
    assert v2 == false
    assert ns2 == st

    op3 = app(:less_than, [literal(1), literal(0)])
    {:ok, v3, ns3, _} = eval_op(op3, st)
    assert v3 == false
    assert ns3 == st
  end

  test "greater than" do
    st = %{}
    op1 = app(:greater_than, [literal(1), literal(2)])
    {:ok, v1, ns1, _} = eval_op(op1, st)
    assert v1 == false
    assert ns1 == st

    op2 = app(:greater_than, [literal(1), literal(1)])
    {:ok, v2, ns2, _} = eval_op(op2, st)
    assert v2 == false
    assert ns2 == st

    op3 = app(:greater_than, [literal(1), literal(0)])
    {:ok, v3, ns3, _} = eval_op(op3, st)
    assert v3 == true
    assert ns3 == st
  end

  test "less than or equal" do
    st = %{}
    op1 = app(:less_than_or_equals, [literal(1), literal(2)])
    {:ok, v1, ns1, _} = eval_op(op1, st)
    assert v1 == true
    assert ns1 == st

    op2 = app(:less_than_or_equals, [literal(1), literal(1)])
    {:ok, v2, ns2, _} = eval_op(op2, st)
    assert v2 == true
    assert ns2 == st

    op3 = app(:less_than_or_equals, [literal(1), literal(0)])
    {:ok, v3, ns3, _} = eval_op(op3, st)
    assert v3 == false
    assert ns3 == st
  end

  test "greater than or equal" do
    st = %{}
    op1 = app(:greater_than_or_equals, [literal(1), literal(2)])
    {:ok, v1, ns1, _} = eval_op(op1, st)
    assert v1 == false
    assert ns1 == st

    op2 = app(:greater_than_or_equals, [literal(1), literal(1)])
    {:ok, v2, ns2, _} = eval_op(op2, st)
    assert v2 == true
    assert ns2 == st

    op3 = app(:greater_than_or_equals, [literal(1), literal(0)])
    {:ok, v3, ns3, _} = eval_op(op3, st)
    assert v3 == true
    assert ns3 == st
  end

  test "not" do
    st = %{}
    op1 = app(:not, [literal(true)])
    {:ok, v1, ns1, _} = eval_op(op1, st)
    assert v1 == false
    assert ns1 == st

    op2 = app(:not, [literal(false)])
    {:ok, v2, ns2, _} = eval_op(op2, st)
    assert v2 == true
    assert ns2 == st
  end

  test "is_nil" do
    st = %{}
    op1 = app(:is_nil, [literal(true)])
    {:ok, v1, ns1, _} = eval_op(op1, st)
    assert v1 == false
    assert ns1 == st

    op2 = app(:is_nil, [literal(nil)])
    {:ok, v2, ns2, _} = eval_op(op2, st)
    assert v2 == true
    assert ns2 == st
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
    {:ok, val, ns, _} = eval_op(op, st)
    assert ns == st
    assert val == nil
  end

  test "get val" do
    op = app(:get, [literal(1), literal(true)])
    st = %{1 => true}
    {:ok, val, ns, _} = eval_op(op, st)
    assert ns == st
    assert val == true
  end

  test "literal" do
    st = %{}
    {:ok, 1, ns1, _} = eval_op(literal(1), st)
    assert ns1 == st
    {:ok, true, ns2, _} = eval_op(literal(true), st)
    assert ns2 == st
    {:ok, "hello", ns3, _} = eval_op(literal("hello"), st)
    assert ns3 == st
  end

  test "and all true" do
    op1 = app(:and, [
      literal(true),
      literal(true),
      ])
    st = %{}
    {:ok, true, ns, _} = eval_op(op1, st)
    assert ns == st
  end

  test "and some true (true first)" do
    op1 = app(:and, [
      literal(true),
      literal(false),
      ])
    st = %{}
    {:ok, false, ns, _} = eval_op(op1, st)
    assert ns == st
  end

  test "and some true (true second)" do
    op = app(:and, [
      literal(false),
      literal(true),
      ])
    st = %{}
    {:ok, false, ns, _} = eval_op(op, st)
    assert ns == st
  end

  test "and all false" do
    op1 = app(:and, [
      literal(false),
      literal(false),
      ])
    st = %{}
    {:ok, false, ns, _} = eval_op(op1, st)
    assert ns == st
  end

  test "or all true" do
    op1 = app(:or, [
      literal(true),
      literal(true),
      ])
    st = %{}
    {:ok, true, ns, _} = eval_op(op1, st)
    assert ns == st
  end

  test "or some true (true first)" do
    op = app(:or, [
      literal(true),
      literal(false),
      ])
    st = %{}
    {:ok, true, ns, _} = eval_op(op, st)
    assert ns == st
  end

  test "or some true (true second)" do
    op = app(:or, [
      literal(false),
      literal(true),
      ])
    st = %{}
    {:ok, true, ns, _} = eval_op(op, st)
    assert ns == st
  end

  test "or all false" do
    op1 = app(:or, [
      literal(false),
      literal(false),
      ])
    st = %{}
    {:ok, false, ns, _} = eval_op(op1, st)
    assert ns == st
  end

  test "substring true" do
    op1 = app(:substring, [
      literal("hello"),
      literal("ll"),
      ])
    st = %{}
    {:ok, val, ns, _} = eval_op(op1, st)
    assert ns == st
    assert val == true
  end

  test "substring false" do
    op1 = app(:substring, [
      literal("hello"),
      literal("yolo"),
      ])
    st = %{}
    {:ok, val, ns, _} = eval_op(op1, st)
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
    {:ok, val, ns, _} = eval_op(op, st)
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
    {:ok, val, ns, _} = eval_op(op1, st)
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
    {:ok, val, ns, _} = eval_op(op1, st)
    assert ns == expects
    assert val == nil
  end

  test "stack push" do
    empty = %RuleEngine.Eval.Stack{}
    vals1 = %{
      a: 1,
      b: 2
    }
    vals2 = %{
      a: 3,
      c: 4
    }
    st = empty
      |> push_stack(:dummy1, vals1)
      |> push_stack(:dummy2, vals2)
    assert st == %RuleEngine.Eval.Stack{
      level: 2,
      stack: [:dummy2, :dummy1],
      symbols: %{
        a: [2, 1],
        b: [1],
        c: [2]
      },
      values: %{
        {:a, 1} => 1,
        {:b, 1} => 2,
        {:a, 2} => 3,
        {:c, 2} => 4
      }
    }
  end

  test "stack pop" do
    stack = %RuleEngine.Eval.Stack{
      level: 2,
      stack: [:dummy2, :dummy1],
      symbols: %{
        a: [2, 1],
        b: [1],
        c: [2]
      },
      values: %{
        {:a, 1} => 1,
        {:b, 1} => 2,
        {:a, 2} => 3,
        {:c, 2} => 4
      }
    }
    expects = %RuleEngine.Eval.Stack{
      level: 1,
      stack: [:dummy1],
      symbols: %{
        a: [1],
        b: [1]
      },
      values: %{
        {:a, 1} => 1,
        {:b, 1} => 2
      }
    }
    assert pop_stack(stack) == expects
  end

  test "push and pop" do
    empty = %RuleEngine.Eval.Stack{}
    vals1 = %{a: 1, b: 2}
    vals2 = %{a: 3, c: 4}
    vals3 = %{a: 5}

    st = empty
      |> push_stack(:dummy1, vals1)
      |> push_stack(:dummy2, vals2)
      |> pop_stack()
      |> push_stack(:dummy3, vals3)
      |> pop_stack()
      |> pop_stack()

      expects = %RuleEngine.Eval.Stack{
        level: 0,
        stack: [],
        symbols: %{},
        values: %{}
      }
    assert st == expects
  end

end
