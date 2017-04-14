defmodule RuleEngine.Reduce do
  alias RuleEngine.Types.Token
  alias RuleEngine.Mutable

  def reduce(%Token{type: :list, macro: false} = tok) do
    reduce_list(tok.value)
  end
  def reduce(%Token{type: :symbol, macro: false} = tok) do
    resolve_symbol(tok)
  end

  def reduce(%Token{} = tok) do
    fn state ->
      {tok, state}
    end
  end
  def reduce_list([f | params]) do
    runfunc = fn tok ->
      arbitrary = tok.value
      case tok do
        %Token{type: :function, macro: true} -> arbitrary.(params)
        %Token{type: :function} ->
          fn state ->
            {vs, state2} = leftReduce(params).(state)
            arbitrary.(vs).(state2)
          end
        _ -> throw {:not_a_function, tok}
      end
    end
    fn state ->
      {fun, state2} = reduce(f).(state)
      {result, state3} = case fun do
        %Token{type: :function} = tok -> runfunc.(tok).(state2)
        %Token{type: :symbol} ->
            {tok, state2_2} = resolve_symbol(fun).(state2)
            runfunc.(tok).(state2_2)
        _ -> throw {:not_a_function, fun}
      end
      {_, state4} = add_reduction().(state3)
      {result, state4}
    end
  end
  def reduce_list(_ast) do
    throw :not_implemented
  end

  def resolve_symbol(%Token{value: sy} = sy_tok) do
    fn state ->
      tok = Mutable.env_lookup(state, sy)
      result = case tok do
        {:ok, val} -> val
        :not_found -> throw {:no_symbol_found, sy_tok}
      end
      {_, state2} = add_reduction().(state)
      {result, state2}
    end
  end

  def add_reduction() do
    fn state ->
      {nil, Mutable.reductions_inc(state)}
    end
  end

  defp leftReduce([]) do
    fn state ->
      {[], state}
    end
  end
  defp leftReduce([head | tail]) do
    fn state ->
      {v, state2} = reduce(head).(state)
      {r, state3} = leftReduce(tail).(state2)
      {[v | r], state3}
    end
  end
end
