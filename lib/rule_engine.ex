defmodule RuleEngine do
  @moduledoc """
  RuleEngine is a pure elixir library that helps execute
  basic predicates which may then modify arbitrary state.

  Although the AST is intended to be LISP-like for internal
  simplicity, the language used by an end user to create a rule
  need not be LISP, so long as it emits a compatble AST.
  """
  alias RuleEngine.Reduce
  alias RuleEngine.Mutable
  alias RuleEngine.LISP

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
    {res, mutable} = Reduce.reduce(ast).(mutable)
    {:ok, res, mutable}
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
      {:error, "Expected #{ref_ty} as argument type, but got #{t}: #{inspect(val)}"}
    {:no_atom_found, atom_ref} ->
      {:error, {:no_atom_found, atom_ref}}
    :max_reductions_reached ->
      {:end, "Maximum execution reached, ending."}
  end

  @spec parse_lisp(String.t, any)
    :: {:ok, Token.t}
    | {:error, String.t, Origin.t}
  def parse_lisp(input, source) do
    LISP.parse_document(input, source)
  end

  @spec parse_lisp(String.t, any)
    :: {:ok, Token.t}
    | {:error, String.t, Origin.t}
  def parse_lisp_value(input, source) do
    LISP.parse(input, source)
  end
end
