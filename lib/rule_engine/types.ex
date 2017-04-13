defmodule RuleEngine.Types do
  defmodule Token do
    defstruct [
      type: nil,
      value: nil,
      meta: nil,
      macro: false
    ]
  end
  def symbol?(%Token{type: :symbol}), do: true
  def symbol?(_), do: false

  def list?(%Token{type: :list}), do: true
  def list?(_), do: false

  def map?(%Token{type: :map}), do: true
  def map?(_), do: false

  def string?(%Token{type: :string}), do: true
  def string?(_), do: false

  def number?(%Token{type: :number}), do: true
  def number?(_), do: false

  def function?(%Token{type: :function}), do: true
  def function?(_), do: false

  def macro?(%Token{type: :function, macro: true}), do: true
  def macro?(_), do: false

  def map(%{} = m), do: mk(:map, m)
  def list(l) when is_list(l), do: mk(:list, l)
  def symbol(s) when is_atom(s) or is_binary(s), do: mk(:symbol, s)
  def string(s) when is_binary(s), do: mk(:string, s)
  def number(n) when is_number(n), do: mk(:number, n)
  def function(f) when is_function(f), do: mk(:function, f)
  def macro(f) when is_function(f), do: mkm(f)

  defp mk(ty, val), do: %Token{type: ty, value: val}
  defp mkm(val), do: %Token{type: :function, macro: true, value: val}

end
