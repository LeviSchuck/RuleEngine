defmodule RuleEngine.Reduce do
  alias RuleEngine.Types.Token
  require Monad.State, as: State

  def reduce(%Token{type: :list} = tok) do
    State.m do
      vs <- leftReduce(tok.value)
      reduce_list(vs)
    end
  end

  def reduce(%Token{type: :function} = tok) do
    State.m do
      [fun | params] <- return tok.value
      vs <- leftReduce(params)
      fun.(vs)
    end
  end

  def reduce(%Token{} = tok) do
    State.m do
      return tok
    end
  end
  def reduce_list([%Token{type: :symbol, value: "do"} | ast]) do
    IO.puts("do: #{inspect ast}")
    State.m do
      lastReduce(ast)
    end
  end
  def reduce_list(ast) do
    throw :not_implemented
  end


  defp lastReduce([]) do
    State.m do
      return nil
    end
  end
  defp lastReduce([head]) do
    State.m do
      v <- reduce(head)
      return v
    end
  end
  defp lastReduce([head | rest]) do
    State.m do
      _ <- reduce(head)
      lastReduce(rest)
    end
  end


  defp leftReduce([]) do
    State.m do
      return []
    end
  end
  defp leftReduce([head | tail]) do
    State.m do
      v <- reduce(head)
      r <- leftReduce(tail)
      return [v | r]
    end
  end
end
