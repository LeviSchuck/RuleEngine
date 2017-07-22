defmodule RuleEngineLispLexerTest do
  use ExUnit.Case
  import RuleEngine.LISP.Lexer

  def token_of({{token, _}, _}) when is_atom(token), do: token
  def token_of({token, _}) when is_atom(token), do: token
  def token_of({:error, _, _}), do: :error
  def token_of(unexpected), do: unexpected

  def value_of({{_, v}, _}), do: v
  def value_of({unexpected, _}), do: unexpected
  def value_of(unexpected), do: unexpected

  def assert_token(expected, tok) do
    case token_of(tok) do
      ^expected -> nil
      unexpected -> assert(false, "Unexpected token: #{inspect unexpected}, expected #{inspect expected}")
    end
  end

  def assert_value(expected, tok) do
    case value_of(tok) do
      ^expected -> nil
      unexpected -> assert(false, "Unexpected value, expected #{inspect expected}, but got #{inspect unexpected}")
    end
  end

  test "empty eof" do
    case lexer("") do
      [tok] -> assert_token(:end_of_file, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "left paren" do
    case lexer("(") do
      [tok | _] -> assert_token(:left_paren, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "right paren" do
    case lexer(")") do
      [tok | _] -> assert_token(:right_paren, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "left dict" do
    case lexer("%{") do
      [tok | _] -> assert_token(:left_dict, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "right dict" do
    case lexer("}") do
      [tok | _] -> assert_token(:right_dict, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "quote" do
    case lexer("'") do
      [tok | _] -> assert_token(:quote, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "comma" do
    case lexer(",") do
      [tok | _] -> assert_token(:comma, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "whitespace" do
    case lexer(" ") do
      [tok | _] -> assert_token(:whitespace, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer(" \t\r\n\r \t") do
      [tok | _] -> assert_token(:whitespace, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "number" do
    case lexer("123") do
      [tok | _] ->
        assert_token(:number, tok)
        assert_value(123, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer("123.4") do
      [tok | _] ->
        assert_token(:number, tok)
        assert_value(123.4, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "symbol" do
    case lexer("hello") do
      [tok | _] ->
        assert_token(:symbol, tok)
        assert_value("hello", tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer("hello ") do
      [tok | _] ->
        assert_token(:symbol, tok)
        assert_value("hello", tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer("b123") do
      [tok | _] ->
        assert_token(:symbol, tok)
        assert_value("b123", tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "comment" do
    case lexer(";") do
      [tok | _] -> assert_token(:comment, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer(";\n") do
      [tok | _] -> assert_token(:comment, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer(";hello") do
      [tok | _] -> assert_token(:comment, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer(";hello\n") do
      [tok | _] -> assert_token(:comment, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "string" do
    case lexer("\"\"") do
      [tok | _] ->
        assert_token(:string, tok)
        assert_value("", tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer("\"hello\"") do
      [tok | _] ->
        assert_token(:string, tok)
        assert_value("hello", tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer("\"hello\nhello\"") do
      [tok | _] ->
        assert_token(:string, tok)
        assert_value("hello\nhello", tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end

  test "string fail" do
    case lexer("\"") do
      [tok | _] ->
        assert_token(:error, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
    case lexer("\"hello") do
      [tok | _] ->
        assert_token(:error, tok)
      x -> assert(false, "Unexpected result: #{inspect x}")
    end
  end
end
