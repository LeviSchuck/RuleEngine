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
  defparser simple_choice(%ParserState{status: :ok} = state, parsers) do
    do_simple_choice(parsers, state, nil)
  end

  defp do_simple_choice(_, _, %ParserState{status: :ok} = success) do
    success
  end
  defp do_simple_choice(_,
    %ParserState{status: :ok, line: line1, column: col1},
    %ParserState{status: :error, line: line2, column: col2} = failure
    ) when line1 != line2 or col1 != col2 do
    failure
  end
  defp do_simple_choice([parser|rest], state, _) do
    result = parser.(state)
    do_simple_choice(rest, state, result)
  end
  defp do_simple_choice([], %ParserState{line: line, column: col} = state, _) do
    %{state | :status => :error, :error => "Expected at least one choice to succeed at line #{line}, column #{col}."}
  end


  defp tol(x), do: [x]

  defp whitespace(p \\ nil), do: word_of(p, ~r/[\t\r\n ]+/)

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
      lazy(fn -> simple_choice([
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
    word_of(p, ~r/;[^\n]*\n/)
  end
  def parse_dead_content(p \\ nil) do
    p |> many(simple_choice([
      whitespace(),
      parse_comment(),
      ]))
  end
  def parse_value(p \\ nil) do
    p |> between(parse_dead_content(), parse_value_direct(), parse_dead_content())
  end
  def parse_value_direct(p \\ nil) do
    p |> simple_choice([
      parse_quoted(),
      parse_value_unquoted(),
      ])
  end
  def parse_value_unquoted(p \\ nil) do
    p |> simple_choice([
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
end
