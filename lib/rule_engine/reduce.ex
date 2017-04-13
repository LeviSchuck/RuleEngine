defmodule RuleEngine.Reduce do
  alias RuleEngine.Types.Token
  alias RuleEngine.Mutable
  require Monad.State, as: State

  def reduce(%Token{type: :list, macro: false} = tok) do
    State.m do
      reduce_list(tok.value)
    end
  end

  def reduce(%Token{} = tok) do
    State.m do
      return tok
    end
  end
  def reduce_list([%Token{type: :symbol, value: "do"} | ast]) do
    State.m do
      lastReduce(ast)
    end
  end
  def reduce_list([%Token{type: :symbol, value: "quote"}, ast]) do
    State.m do
      return ast
    end
  end

  def reduce_list([%Token{type: :symbol, value: "if"}, condition, true_ast, false_ast]) do
    State.m do
      result <- reduce(condition)
      case result do
        %Token{type: :symbol, value: true} -> reduce(true_ast)
        %Token{type: :symbol, value: false} -> reduce(false_ast)
        %Token{type: :symbol, value: nil} -> reduce(false_ast)
        _ -> throw :condition_not_boolean
      end
    end
  end
  def reduce_list([f | params]) do
    runfunc = fn arbitrary ->
      State.m do
        vs <- leftReduce(params)
        res <- arbitrary.(vs)
        return res
      end
    end
    State.m do
      fun <- reduce(f)
      case fun do
        %Token{type: :function, value: arbitrary} -> runfunc.(arbitrary)
        %Token{type: :symbol} ->
          State.m do
            tok <- resolve_symbol(fun)
            case tok do
              %Token{type: :function, value: arbitrary} -> runfunc.(arbitrary)
              _ -> throw {:not_a_function, tok}
            end
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
