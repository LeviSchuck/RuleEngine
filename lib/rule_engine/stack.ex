defmodule RuleEngine.Stack do
  alias RuleEngine.Stack
  @moduledoc false
  @type t :: %__MODULE__{}
  defstruct [
    vals: %{},
    parent: nil,
    depth: 0,
    origin: nil,
  ]

  def push(parent, vals, origin) do
    depth = case parent do
      %Stack{depth: depth} -> depth + 1
      _ -> 0
    end
    %Stack{
      vals: vals,
      parent: parent,
      depth: depth,
      origin: origin,
    }
  end

  def pop(stack) do
    case stack.parent do
      %Stack{} = parent -> parent
      _ -> %Stack{}
    end
  end

  def squash(stack, origin) do
    case stack.parent do
      %Stack{parent: parent, vals: v} ->
        # Merge with newer on the right so they stay on top
        vals = Map.merge(v, stack.vals)
        %{stack | parent: parent, vals: vals}
      _ -> %{stack | origin: origin}
    end
  end

  @spec get(Stack.t, any) :: {:ok, any} | :not_found
  def get(nil, _), do: :not_found
  def get(stack, key) do
    case Map.get(stack.vals, key, :not_found) do
      :not_found -> get(stack.parent, key)
      val -> {:ok, val}
    end
  end


end
