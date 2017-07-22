defmodule RuleEngineLispParseTest do
  use ExUnit.Case
  import RuleEngine.LISP.Parser
  import RuleEngine.Types

  def expect({:value, x, _}, expected) do
    assert(similar(x, expected), "Error, expected: #{inspect expected} but got #{inspect x}")
  end
  def expect(x, e), do: assert(false, "Error, expected: #{inspect e} but got #{inspect x}")

  def similar(%{type: t1, value: v1}, %{type: t2, value: v2}), do: t1 == t2 and similar(v1, v2)
  def similar(l1, l2) when is_list(l1) and is_list(l2) do
    List.zip([l1, l2]) |> Enum.reduce(true, fn {x, y}, acc ->
      acc && similar(x, y)
    end)
  end
  def similar(x, y), do: x == y

  def errored({:error, _, _}), do: nil
  def errored({:nothing}), do: nil
  def errored({:value, x, _}), do: assert(false, "Expected an error, but got value #{inspect x}")
  def errored(x), do: assert(false, "Expected an error, but got value #{inspect x}")

  def t("("), do: {:left_paren, mko(:test, 0, 0)}
  def t(")"), do: {:right_paren, mko(:test, 0, 0)}
  def t(","), do: {:comma, mko(:test, 0, 0)}
  def t("'"), do: {:quote, mko(:test, 0, 0)}
  def t("%{"), do: {:left_dict, mko(:test, 0, 0)}
  def t("}"), do: {:right_dict, mko(:test, 0, 0)}
  def t(n) when is_number(n), do: {{:number, n}, mko(:test, 0, 0)}
  def t(a) when is_atom(a), do: {{:symbol, Atom.to_string(a)}, mko(:test, 0, 0)}
  def t(" "), do: {:whitespace, mko(:test, 0, 0)}
  def t(x) when is_binary(x), do: {{:symbol, x}, mko(:test, 0, 0)}

  test "parse bad list end" do
    lexed = [t("(")]
    errored(parse_value(lexed))
  end

  test "parse bad list start" do
    lexed = [t(")")]
    errored(parse_value(lexed))
  end

  test "parse empty list" do
    lexed = [t("("), t(")")]
    expect(parse_value(lexed), list([]))
  end

  test "parse single list" do
    lexed = [t("("), t(3), t(")")]
    expect(parse_value(lexed), list([number(3)]))
  end

  test "parse list with space" do
    lexed = [t("("), t(3), t(" "), t(4), t(")")]
    expect(parse_value(lexed), list([number(3), number(4)]))
  end

  test "parse list with comma" do
    lexed = [t("("), t(3), t(","), t(4), t(")")]
    expect(parse_value(lexed), list([number(3), number(4)]))
  end

  test "parse empty dict" do
    lexed = [t("%{"), t("}")]
    expect(parse_value(lexed), dict(%{}))
  end

  test "parse some dict with arrow" do
    lexed = [t("%{"), t(2), t("=>"), t(3), t("}")]
    expected = [symbol("make-dict"), number(2), number(3)]
    expect(parse_value(lexed), list(expected))
  end

  test "parse some dict with comma" do
    lexed = [t("%{"), t(2), t(" "), t(3), t(","), t("hello"), t(" "), t("world"), t("}")]
    expected = [symbol("make-dict"), number(2), number(3), symbol("hello"), symbol("world")]
    expect(parse_value(lexed), list(expected))
  end

  test "parse bad dict with extra arrow 1" do
    lexed = [t("%{"), t(2), t("=>"), t("=>"), t(3), t("}")]
    errored(parse_value(lexed))
  end

  test "parse bad dict with extra arrow 2" do
    lexed = [t("%{"), t(2), t("=>"), t(3), t("=>"), t("}")]
    errored(parse_value(lexed))
  end

  test "parse bad dict with extra arrow 3" do
    lexed = [t("%{"), t(2), t("=>"), t(3), t("=>"), t("=>"), t("}")]
    errored(parse_value(lexed))
  end

  test "parse bad dict missing space" do
    lexed = [t("%{"), t(2), t(3), t("}")]
    errored(parse_value(lexed))
  end

  test "parse bad dict middle comma" do
    lexed = [t("%{"), t(2), t(","), t(3), t("}")]
    errored(parse_value(lexed))
  end

  test "parse bad dict missing value" do
    lexed = [t("%{"), t(2), t("}")]
    errored(parse_value(lexed))
  end

  test "parse bad dict missing end" do
    lexed = [t("%{"), t(2), t(3)]
    errored(parse_value(lexed))
  end

  test "quote value" do
    lexed = [t("'"), t(3)]
    expect(parse_value(lexed), list([symbol("quote"), number(3)]))
  end

  test "number" do
    lexed = [t(3)]
    expect(parse_value(lexed), number(3))
  end

  test "symbol" do
    lexed = [t("hello")]
    expect(parse_value(lexed), symbol("hello"))
  end

end
