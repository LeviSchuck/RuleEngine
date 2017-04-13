defmodule RuleEngine.Reduce do
  alias RuleEngine.Types.Token
  alias RuleEngine.Mutable
  require Monad.State, as: State

  def reduce(%Token{type: :list, macro: false} = tok) do
    State.m do
      reduce_list(tok.value)
    end
  end
  def reduce(%Token{type: :symbol, macro: false} = tok) do
    default = State.m do
      return tok
    end
    case tok.value do
      nil -> default
      true -> default
      false -> default
      _ -> resolve_symbol(tok)
    end
  end

  def reduce(%Token{} = tok) do
    State.m do
      return tok
    end
  end
  def reduce_list([f | params]) do
    runfunc = fn tok ->
      arbitrary = tok.value
      case tok do
        %Token{type: :function, macro: true} ->
          State.m do
            res <- arbitrary.(params)
            return res
          end
        %Token{type: :function} ->
          State.m do
            vs <- leftReduce(params)
            res <- arbitrary.(vs)
            return res
          end
        _ -> throw {:not_a_function, tok}
      end
    end
    State.m do
      fun <- reduce(f)
      case fun do
        %Token{type: :function} = tok -> runfunc.(tok)
        %Token{type: :symbol} ->
          State.m do
            tok <- resolve_symbol(fun)
            runfunc.(tok)
          end
        _ -> throw {:not_a_function, fun}
      end
    end
  end
  def reduce_list(_ast) do
    throw :not_implemented
  end

  def resolve_symbol(%Token{value: sy} = sy_tok) do
    State.m do
      mut <- State.get()
      tok <- return Mutable.env_lookup(mut, sy)
      case tok do
        {:ok, val} ->
          State.m do
            return val
          end
        :not_found -> throw {:no_symbol_found, sy_tok}
      end
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
