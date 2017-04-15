defmodule RuleEngine.Types do
  defmodule Token do
    defstruct [
      type: nil,
      value: nil,
      meta: nil,
      macro: false,
      env: nil
    ]
  end
  def symbol?(%Token{type: :symbol}), do: true
  def symbol?(_), do: false

  def list?(%Token{type: :list}), do: true
  def list?(_), do: false

  def dict?(%Token{type: :dict}), do: true
  def dict?(_), do: false

  def string?(%Token{type: :string}), do: true
  def string?(_), do: false

  def number?(%Token{type: :number}), do: true
  def number?(_), do: false

  def function?(%Token{type: :function}), do: true
  def function?(_), do: false

  def atom?(%Token{type: :atom}), do: true
  def atom?(_), do: false

  def macro?(%Token{type: :function, macro: true}), do: true
  def macro?(_), do: false

  def boolean?(%Token{type: :symbol, value: true}), do: true
  def boolean?(%Token{type: :symbol, value: false}), do: true
  def boolean?(%Token{type: :symbol, value: nil}), do: true
  def boolean?(_), do: false

  def nil?(%Token{type: :symbol, value: nil}), do: true
  def nil?(_), do: false

  def dict(%{} = m), do: mk(:dict, m)
  def list(l) when is_list(l), do: mk(:list, l)
  def symbol(s) when is_atom(s) or is_binary(s), do: mk(:symbol, s)
  def string(s) when is_binary(s), do: mk(:string, s)
  def number(n) when is_number(n), do: mk(:number, n)
  def function(f) when is_function(f), do: mk(:function, f)
  def macro(f) when is_function(f), do: mkm(f)
  def boolean(b) when is_boolean(b), do: mk(:symbol, b)
  def atom(a), do: mk(:atom, a)
  def hack(a), do: mk(:hack, a)

  def add_closure(fun, env), do: %{fun | env: env}

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
