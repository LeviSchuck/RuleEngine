defmodule RuleEngine.LISP do
  alias RuleEngine.Bootstrap
  alias RuleEngine.Mutable
  alias RuleEngine.Types
  alias RuleEngine.Types.Token
  alias RuleEngine.Reduce
  def mk_mut do
    Bootstrap.bootstrap_mutable()
      |> Mutable.env_new(%{
          "debug_atom" =>
              Bootstrap.state_fun(fn x ->
                fn state ->
                  {Types.atom(x.value), state}
                end
              end, [:number]),
          "debug_get_environment" =>
            Bootstrap.state_fun(fn ->
              fn state ->
                {Types.dict(state.environment), state}
              end
            end, []),
          "debug_get_atoms" =>
            Bootstrap.state_fun(fn ->
              fn state ->
                {Types.dict(state.atoms), state}
              end
            end, []),
          "debug_reductions" =>
            Bootstrap.state_fun(fn ->
              fn state ->
                {Types.number(state.reductions), state}
              end
            end, [])
        })
  end
  def main do
    loop(mk_mut())
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
      {:error, desc} when is_binary(desc) ->
        IO.puts("Error: #{desc}")
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
        sequence([parse_value(), option(string("=>")), parse_value(), option(char(","))])
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

  def read(text) do
    case text do
      "" -> {:ignore}
      "end!" -> {:end}
      command ->
        case Combine.parse(command, Parser.parse_root()) do
          [x] -> {:ok, x}
          {:error, expected} -> {:error, {:parse_error, expected}}
          res -> res
        end
    end
  end
  def print(%Token{type: :list} = tok) do
    ["(", Enum.join(Enum.map(tok.value, &print/1), " "), ")"]
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
  def print(%Token{type: :dict} = tok) do
    ["%{", Enum.map(tok.value, fn {k, v} ->
      [print(k), " => ", print(v)]
    end) |> Enum.join(", "), "}"]
  end
  def print(%Token{type: :function, macro: true}) do
    "macro->"
  end
  def print(%Token{type: :function}) do
    "fn->"
  end
  def print(%Token{type: :hack} = tok) do
    inspect(tok.value)
  end
  def print(%Token{type: :atom} = tok) do
    "#atom_#{tok.value}"
  end
  def print(result) do
    "Unsupported?: #{inspect result}"
  end

  def eval(ast, mutable) do
    {res, nmutable} = Reduce.reduce(ast).(mutable)
    {:ok, res, nmutable}
  catch
    {:not_a_function, tok} ->
      {:error, {:not_a_function, tok}}
    {:no_symbol_found, tok} ->
      {:error, {:no_symbol_found, tok}}
    {:condition_not_boolean, tok} ->
      {:error, {:condition_not_boolean, tok}}
    {:arity_mismatch, expected, actual} ->
      {:error, "Expected #{expected} arguments, but got #{actual} arguments"}
    {:type_mismatch, :same, ref_ty, t} ->
      {:error, """
      Expected the same type for some args as prior args,
      namely #{ref_ty} instead of #{t}
      """}
    {:type_mismatch, ref_ty, t} ->
      {:error, "Expected #{ref_ty} as argument type, but got #{t}"}
    {:type_mismatch, ref_ty, t, val} ->
      {:error, "Expected #{ref_ty} as argument type, but got #{t}: #{print(val)}"}
    {:no_atom_found, atom_ref} ->
      {:error, {:no_atom_found, atom_ref}}
  end
end
