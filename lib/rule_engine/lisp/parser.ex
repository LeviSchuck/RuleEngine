defmodule RuleEngine.LISP.Parser do
  @moduledoc false
  use Combine
  use Combine.Helpers
  alias Combine.ParserState
  import Combine.Parsers.Base
  import Combine.Parsers.Text
  alias RuleEngine.Types

  require Logger

  defparser lazy(%ParserState{status: :ok} = state, generator) do
    (generator.()).(state)
  end

  # freaking choice doesn't give the right error
  # it just try-catches-ish around each attempt
  defparser first_of(%ParserState{status: :ok} = state, parsers) do
    do_first_of(parsers, state, nil)
  end

  defp do_first_of(_, _, %ParserState{status: :ok} = success) do
    success
  end
  defp do_first_of(_,
    %ParserState{status: :ok, line: line1, column: col1},
    %ParserState{status: :error, line: line2, column: col2} = failure
    ) when line1 != line2 or col1 != col2 do
    failure
  end
  defp do_first_of([parser|rest], state, _) do
    result = parser.(state)
    do_first_of(rest, state, result)
  end
  defp do_first_of([], %ParserState{line: line, column: col} = state, _) do
    %{state | :status => :error, :error => "Expected at least one parser to succeed at line #{line}, column #{col}."}
  end

  defparser correct_newline(%ParserState{} = state) do
   do_newline(state)
  end
  defp do_newline(%ParserState{status: :ok, line: line, input: <<?\n::utf8,rest::binary>>, results: results} = state) do
   %{state | :column => 0, :line => line + 1, :input => rest, :results => ["\n"|results]}
  end
  defp do_newline(%ParserState{status: :ok, line: line, input: <<?\r::utf8,?\n::utf8,rest::binary>>, results: results} = state) do
    %{state | :column => 0, :line => line + 1, :input => rest, :results => ["\n"|results]}
  end
  defp do_newline(%ParserState{status: :ok, line: line, column: col, input: <<?\r::utf8,c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected CRLF sequence, but found `\\r#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp do_newline(%ParserState{status: :ok, input: <<?\r::utf8>>} = state) do
    %{state | :status => :error, :error => "Expected CRLF sequence, but hit end of input."}
  end
  defp do_newline(%ParserState{status: :ok, line: line, column: col, input: <<c::utf8,_::binary>>} = state) do
    %{state | :status => :error, :error => "Expected newline but found `#{<<c::utf8>>}` at line #{line}, column #{col + 1}."}
  end
  defp do_newline(%ParserState{status: :ok, input: <<>>} = state) do
    %{state | :status => :error, :error => "Expected newline, but hit end of input."}
  end

  defp tol(x), do: [x]

  defp whitespace(p \\ nil), do: first_of([correct_newline(), word_of(p, ~r/[\t ]+/)])

  def parse_text do
    text_regex = ~r/([^\\"]|\\(\\|"))*/
    between(char("\""), word_of(text_regex), char("\""))
      |> tol()
      |> pipe(fn [text] ->
        Types.string(text)
      end)
  end
  def parse_symbol do
    symbol_regex = ~r/[a-z_0-9!?*<>=\!\#\^\+\-\|\&]+/
    word_of(symbol_regex)
      |> tol()
      |> pipe(fn [sy] ->
        Types.symbol(sy)
      end)
  end
  def parse_number do
    either(float(), integer())
      |> map(fn num ->
        Types.number(num)
      end)
  end
  def parse_list do
    pipe([
      char("("),
      lazy(fn -> many(parse_value()) end),
      char(")")
      ], fn [_, v, _] ->
        Types.list(v)
      end)
  end
  def parse_map do
    between(string("%{"), many(lazy(fn ->
      sequence([
        parse_value(),
        option(string("=>")),
        parse_value(),
        option(char(","))
        ])
    end))
    |> tol()
    |> pipe(fn [xs] ->
      xs
        |> Enum.map(fn [k, _, v, _] -> {k, v} end)
        |> Enum.into(%{})
        |> Types.dict()
    end), char("}"))
  end
  def parse_quoted(p \\ nil) do
    p |> pipe([
      char("'"),
      lazy(fn -> first_of([
        parse_quoted(),
        parse_value_direct(),
        ])
      end)
      ], fn [_, value] ->
        Types.list([
          Types.symbol("quote"),
          value
          ])
      end)
  end
  def parse_comment(p \\ nil) do
    word_of(p, ~r/;[^\n]*/) |> correct_newline()
  end
  def parse_dead_content(p \\ nil) do
    p |> many(first_of([
      whitespace(),
      parse_comment(),
      ]))
  end
  def parse_value(p \\ nil) do
    p |> between(parse_dead_content(), parse_value_direct(), parse_dead_content())
  end
  def parse_value_direct(p \\ nil) do
    p |> first_of([
      parse_quoted(),
      parse_value_unquoted(),
      ])
  end
  def parse_value_unquoted(p \\ nil) do
    p |> first_of([
      parse_map(),
      parse_list(),
      parse_number(),
      parse_text(),
      parse_symbol(),
      ])
  end
  def parse_root do
    parse_value() |> eof()
  end
  def parse_document do
    many(parse_value())
    |> map(fn vs ->
      Types.list([Types.symbol("do") | vs])
    end)
    |> eof()
  end
end
