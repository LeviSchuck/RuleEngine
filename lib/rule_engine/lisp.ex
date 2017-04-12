defmodule RuleEngine.LISP do
  alias RuleEngine.Mutable
  alias RuleEngine.Types
  alias RuleEngine.Types.Token
  require Monad.State, as: State

  def main() do
    loop(%Mutable{})
  end
  defp loop(mutable) do
    IO.write(:stdio, "user> ")
    input = IO.read(:stdio, :line)
      |> String.trim()
    case read_eval_print(mutable, input) do
      {:ok, out, nmutable} ->
        IO.puts(out)
        loop(nmutable)
      {:error, {err, val}} ->
        IO.puts("Error: #{inspect err}: #{print(val)}")
        loop(mutable)
      {:end} -> nil
      {:ignore} -> loop(mutable)
      what ->
        IO.puts("Unexpected: #{inspect what}")
        nil
    end
    
  end
  defp read_eval_print(mutable, input) do
    case read(input) do
      {:ok, ast} ->
        case eval(ast, mutable) do
          {:ok, res, nmutable} ->
            out = print(res)
            {:ok, out, nmutable}
          res -> res
        end      
      res -> res
    end
  end

  defmodule Parser do
    use Combine
    use Combine.Helpers
    alias Combine.ParserState
    import Combine.Parsers.Base
    import Combine.Parsers.Text

    defparser lazy(%ParserState{status: :ok} = state, generator) do
      (generator.()).(state)
    end
    defp tol(x), do: [x]

    def parse_text() do
      text_regex = ~r/([^\\"]|\\(\\|"))*/
      between(char("\""), word_of(text_regex), char("\""))
        |> tol()
        |> pipe(fn [text] ->
          Types.string(text)
        end)
    end
    def parse_symbol() do
      symbol_regex = ~r/[a-z_0-9!?*]+/
      word_of(symbol_regex)
        |> tol()
        |> pipe(fn [sy] ->
          case sy do
            "true" -> Types.symbol(true)
            "false" -> Types.symbol(false)
            "nil" -> Types.symbol(nil)
            _ -> Types.symbol(sy)
          end
        end)
    end
    def parse_number() do
      either(float(), integer())
      |> tol()
      |> pipe(fn [num] ->
        Types.number(num)
      end)
    end
    def parse_list() do
      between(char("("), many(lazy(fn -> parse_value() end)), char(")"))
        |> tol()
        |> pipe(fn [list] ->
          Types.list(list)
        end)
    end
    def parse_map() do
      between(string("%{"), many(lazy(fn ->
        sequence([parse_value(), option(string("=>")), parse_value(), option(char(","))])
      end))
      |> tol()
      |> pipe(fn [xs] ->
        Enum.map(xs, fn [k, _, v, _] -> {k, v} end)
          |> Enum.into(%{})
          |> Types.map()
      end), char("}"))
    end
    def parse_value() do
      between(option(spaces()), choice([
        parse_map(),
        parse_list(),
        parse_number(),
        parse_text(),
        parse_symbol()
        ]), option(spaces()))
    end
    def parse_root() do
      parse_list()
    end
  end
  
  def read(text) do
    case text do
      "" -> {:ignore}
      "end!" -> {:end}
      command ->
        case Combine.parse(command,Parser.parse_root()) do
          [x] -> {:ok, x}
          {:error, expected} -> {:error, {:parse_error, expected}}
          res -> res
        end
    end
  end
  def print(%Token{type: :list} = tok) do
    ["(", Enum.join(Enum.map(tok.value, &print/1)," ") ,")"]
  end
  def print(%Token{type: :number} = tok) do
    inspect(tok.value)
  end
  def print(%Token{type: :symbol} = tok) do
    cond do
      is_binary(tok.value) -> tok.value
      true -> inspect(tok.value)
    end
  end
  def print(%Token{type: :string} = tok) do
    inspect(tok.value)
  end
  def print(%Token{type: :map} = tok) do
    ["%{", Enum.map(tok.value, fn {k, v} ->
      [print(k), " => ", print(v)]
    end) |> Enum.join(", "), "}"]
  end
  def print(%Token{type: :function}) do
    "function ->."
  end
  def print(result), do: inspect(result)

  def eval(ast, mutable) do
    {res, nmutable} = State.run(mutable, RuleEngine.Reduce.reduce(ast))
    {:ok, res, nmutable}
  catch
    {:not_a_function, tok} -> {:error, {:not_a_function, tok}}
  end
end