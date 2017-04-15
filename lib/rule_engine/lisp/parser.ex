defmodule RuleEngine.LISP.Parser do
  @moduledoc false
  use Combine
  use Combine.Helpers
  alias Combine.ParserState
  import Combine.Parsers.Base
  import Combine.Parsers.Text
  alias RuleEngine.Types

  defparser lazy(%ParserState{status: :ok} = state, generator) do
    (generator.()).(state)
  end
  defp tol(x), do: [x]

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
      |> tol()
      |> pipe(fn [num] ->
        Types.number(num)
      end)
  end
  def parse_list do
    between(char("("), many(lazy(fn -> parse_value() end)), char(")"))
      |> tol()
      |> pipe(fn [list] ->
        Types.list(list)
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
  def parse_value do
    between(option(spaces()), choice([
      parse_map(),
      parse_list(),
      parse_number(),
      parse_text(),
      parse_symbol()
      ]), option(spaces()))
  end
  def parse_root do
    parse_value()
  end
end
