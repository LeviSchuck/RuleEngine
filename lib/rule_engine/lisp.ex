defmodule RuleEngine.LISP do
  @moduledoc """
  RuleEngine Execution and AST most closely match that of LISP.
  To render LISP expressions from strings to the AST,
  use `RuleEngine.LISP.parse/1`.
  To convert an AST to a string, you can just use inspect.
  To evaluate an AST with an environment and get back an AST or an
  internal error, use `RuleEngine.LISP.eval/2`.
  """

  alias RuleEngine.Bootstrap
  alias RuleEngine.Mutable
  alias RuleEngine.Types
  alias RuleEngine.Types.Token
  alias RuleEngine.Reduce
  alias RuleEngine.LISP.Parser

  @doc """
  A couple internally provided functions are available which have access
  to internal state, or can wrap constants as if reference values.
  """
  @spec debug_environment :: %{}
  def debug_environment do
    %{
        "debug_atom" => debug_atom(),
        "debug_get_environment" => debug_get_environment(),
        "debug_get_atoms" => debug_get_atoms(),
        "debug_reductions" => debug_reductions(),
        "debug_set_max_reductions" => debug_set_max_reductions(),
      }
  end

  @doc """
  To run a basic repl with a terminal user, `main/0` is available.
  """
  def main do
    main(debug_environment())
  end
  @doc """
  If other libraries want a repl with their own internal functions,
  use `main/1` to specify a map of symbol names (as string) to functions.

  ## Example
  ```
  alias RuleEngine.Bootstrap
  alias RuleEngine.LISP
  env = %{
    "name_here" => Bootstrap.mkfun(fn -> "logic here" end, [])
  }
  LISP.main(env)
  user> (name_here)
  "logic here"
  ```

  """
  def main(environment) do
    mut = Bootstrap.bootstrap_mutable()
      |> Mutable.env_new(environment)
    loop(mut)
  end

  @doc """
  To parse a LISP string to an AST, use `parse/1`.
  A successfully parsed AST does not mean that the AST
  will evaluate without error.
  """
  @spec parse(String.t)
    :: {:ok, Token.t}
    | {:error, tuple}
  def parse(text) do
    case Combine.parse(text, Parser.parse_root()) do
      [x] -> {:ok, x}
      {:error, expected} -> {:error, {:parse_error, expected}}
      res -> res
    end
  end

  @doc """
  To parse a LISP document to an AST, use `parse_document/1`.
  A successfully parsed AST does not mean that the AST
  will evaluate without error.
  """
  @spec parse_document(String.t)
    :: {:ok, Token.t}
    | {:error, tuple}
  def parse_document(text) do
    case Combine.parse(text, Parser.parse_document()) do
      [x] -> {:ok, x}
      {:error, expected} -> {:error, {:parse_error, expected}}
      res -> res
    end
  end

  @doc """
  To evaluate an AST within an execution context, provide the root Token
  (likely a list) and the context.
  If you don't have a context to use, you can use
  `Bootstrap.bootstrap_mutable/0`.
  Internaly thrown errors are caught and returned here.
  """
  @spec eval(Token.t, Mutable.t)
    :: {:ok, Token.t, Mutable.t}
    | {:error, String.t}
    | {:error, tuple}
    | {:end, String.t}
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
    :max_reductions_reached ->
      {:end, "Maximum execution reached, ending."}
  end

  # Internal exposed functions
  defp debug_atom do
    Bootstrap.state_fun(fn x ->
      fn state ->
        {Types.atom(x.value), state}
      end
    end, [:number])
  end
  defp debug_get_environment do
    Bootstrap.state_fun(fn ->
      fn state ->
        {Types.dict(state.environment), state}
      end
    end, [])
  end
  defp debug_get_atoms do
    Bootstrap.state_fun(fn ->
      fn state ->
        {Types.dict(state.atoms), state}
      end
    end, [])
  end
  defp debug_set_max_reductions do
    Bootstrap.state_fun(fn x ->
      fn state ->
        case x do
          %Token{type: :symbol, value: "infinite"} ->
            {Types.symbol(nil), Mutable.reductions_max(state, :infinite)}
          %Token{type: :number, value: num} ->
            {Types.symbol(nil), Mutable.reductions_max(state, num)}
        end
      end
    end, [:number])
  end
  defp debug_reductions do
    Bootstrap.state_fun(fn ->
      fn state ->
        {Types.number(state.reductions), state}
      end
    end, [])
  end

  # Internal REPL
  defp read(text) do
    case text do
      "" -> {:ignore}
      "end!" -> {:end}
      command -> parse(command)
    end
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
      {:end, message} ->
        IO.puts("Ending: #{message}")
        nil
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

  defp print(result) do
    inspect(result)
  end
end
