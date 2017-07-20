defmodule RuleEngineLispParseTest do
  use ExUnit.Case
  import RuleEngine.LISP.Parser
  import RuleEngine.Types

  def expect({:value, x, _}, expected) do
    assert(x == expected, "Error, expected: #{inspect expected} but got #{inspect x}")
  end
  def expect(x, e), do: assert(false, "Error, expected: #{inspect e} but got #{inspect x}")

  def errored({:error, _, _, _}), do: nil
  def errored({:nothing}), do: nil
  def errored({:value, x, _}), do: assert(false, "Expected an error, but got value #{inspect x}")
  def errored(x), do: assert(false, "Expected an error, but got value #{inspect x}")

  def t("("), do: {:left_paren, 0, 0}
  def t(")"), do: {:right_paren, 0, 0}
  def t(","), do: {:comma, 0, 0}
  def t("'"), do: {:quote, 0, 0}
  def t("%{"), do: {:left_dict, 0, 0}
  def t("}"), do: {:right_dict, 0, 0}
  def t(n) when is_number(n), do: {{:number, n}, 0, 0}
  def t(a) when is_atom(a), do: {{:symbol, Atom.to_string(a)}, 0, 0}
  def t(" "), do: {:whitespace, 0, 0}
  def t(x) when is_binary(x), do: {{:symbol, x}, 0, 0}

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
