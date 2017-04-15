defmodule RuleEngine.Types do
  @moduledoc """
  In RuleEngine, there are a couple types that may be given from the outside.
  Erlang / Elixir atoms are not the same as atoms in RuleEngine, the term
  is borrowed from other lispy environments.
  The only Erlang / Elixir atoms that can be directly used is:
  * true
  * false
  * nil

  The supported types from the outside in general are:
  * number
  * string
  * boolean
  * nil
  * list (with any element being a supported type)
  * dict / map (with any key or value being a supported type)

  Symbols may be `true`, `false`, `nil`, or a string.
  """
  defmodule Token do
    @moduledoc """
    Token data structure used for each AST element.

    This is primarily an internal data structure and should not be matched on.
    """
    defstruct [
      type: nil,
      value: nil,
      meta: nil,
      macro: false,
      env: nil
    ]
    @type t :: %__MODULE__{}
  end

  @doc "Type check"
  @spec symbol?(Token.t) :: boolean
  def symbol?(%Token{type: :symbol}), do: true
  def symbol?(_), do: false

  @doc "Type check"
  @spec list?(Token.t) :: boolean
  def list?(%Token{type: :list}), do: true
  def list?(_), do: false

  @doc "Type check"
  @spec dict?(Token.t) :: boolean
  def dict?(%Token{type: :dict}), do: true
  def dict?(_), do: false

  @doc "Type check"
  @spec string?(Token.t) :: boolean
  def string?(%Token{type: :string}), do: true
  def string?(_), do: false

  @doc "Type check"
  @spec number?(Token.t) :: boolean
  def number?(%Token{type: :number}), do: true
  def number?(_), do: false

  @doc "Type check"
  @spec function?(Token.t) :: boolean
  def function?(%Token{type: :function}), do: true
  def function?(_), do: false

  @doc "Type check"
  @spec atom?(Token.t) :: boolean
  def atom?(%Token{type: :atom}), do: true
  def atom?(_), do: false

  @doc "Type check"
  @spec macro?(Token.t) :: boolean
  def macro?(%Token{type: :function, macro: true}), do: true
  def macro?(_), do: false

  @doc "Type check"
  @spec boolean?(Token.t) :: boolean
  def boolean?(%Token{type: :symbol, value: true}), do: true
  def boolean?(%Token{type: :symbol, value: false}), do: true
  def boolean?(%Token{type: :symbol, value: nil}), do: true
  def boolean?(_), do: false

  @doc "Type check"
  @spec nil?(Token.t) :: boolean
  def nil?(%Token{type: :symbol, value: nil}), do: true
  def nil?(_), do: false

  @doc "Wraps a map of tokens to tokens"
  @spec dict(%{}) :: Token.t
  def dict(%{} = m), do: mk(:dict, m)

  @doc "Wraps a list of tokens"
  @spec list(list(Token.t)) :: Token.t
  def list(l) when is_list(l), do: mk(:list, l)

  @doc "Wraps a symbol"
  @spec symbol(boolean | nil | String.t) :: Token.t
  def symbol(s)
  when is_boolean(s) or is_nil(s) or is_binary(s),
    do: mk(:symbol, s)

  @doc "Wrap a string"
  def string(s) when is_binary(s), do: mk(:string, s)

  @doc "Wrap a number"
  @spec number(number) :: Token.t
  def number(n) when is_number(n), do: mk(:number, n)

  @doc "Wrap a non-macro function"
  @spec function(Fun) :: Token.t
  def function(f) when is_function(f), do: mk(:function, f)

  @doc "Wrap a macro-ready function"
  @spec macro(Fun) :: Token.t
  def macro(f) when is_function(f), do: mkm(f)

  @doc "Wraps a boolean value in a Token"
  @spec boolean(boolean) :: Token.t
  def boolean(b) when is_boolean(b), do: mk(:symbol, b)

  @doc "Internal use only"
  @spec atom(integer) :: Token.t
  def atom(a), do: mk(:atom, a)

  @doc """
  Internal use only.

  In case something bad happens, to maintain integrity, this wraps a value
  in an AST Token. However, it is not to be processed and will likely result
  in a runtime error that needs to be caught.
  """
  @spec hack(any) :: Token.t
  def hack(a), do: mk(:hack, a)

  @doc "Adds an environment to a macro function"
  @spec add_closure(Token.t, %{}) :: Token.t
  def add_closure(fun, env), do: %{fun | env: env}

  @doc "Access the value of a token"
  @spec value_of(Token.t) :: any
  def value_of(%Token{value: val}), do: val

  defp mk(ty, val), do: %Token{type: ty, value: val}
  defp mkm(val), do: %Token{type: :function, macro: true, value: val}
end

defimpl Inspect, for: RuleEngine.Types.Token do
  alias RuleEngine.Types.Token
  import Inspect.Algebra

  def inspect(%Token{type: :number} = tok, opts) do
    to_doc(tok.value, opts)
  end
  def inspect(%Token{type: :symbol} = tok, opts) do
    cond do
      is_binary(tok.value) -> tok.value
      true -> to_doc(tok.value, opts)
    end
  end
  def inspect(%Token{type: :string} = tok, opts) do
    to_doc(tok.value, opts)
  end
  def inspect(%Token{type: :dict} = tok, opts) do
    fun = fn {k, v}, _ ->
      concat([to_doc(k, opts), " => ", to_doc(v, opts)])
    end
    surround_many("%{", Map.to_list(tok.value), "}", opts, fun, ",")
  end
  def inspect(%Token{type: :function, macro: true}, _opts) do
    "macro->"
  end
  def inspect(%Token{type: :function}, _opts) do
    "fn->"
  end
  def inspect(%Token{type: :hack} = tok, opts) do
    to_doc(tok.value, opts)
  end
  def inspect(%Token{type: :atom} = tok, opts) do
    concat(["#atom_", to_doc(tok.value, opts)])
  end
  def inspect(%Token{type: :list} = tok, opts) do
    fun = fn v, opt ->
      to_doc(v, opt)
    end
    surround_many("(", tok.value, ")", opts, fun, "")
  end
end
