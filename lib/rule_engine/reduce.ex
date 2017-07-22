defmodule RuleEngine.Reduce do
  @moduledoc """
  This is where computation occurs and is limited.
  Reduction happens recursively for each value.
  If a value is quoted, the structure as is will be value.
  """
  import RuleEngine.Types
  alias RuleEngine.Types.Token
  alias RuleEngine.Mutable

  @doc """
  Tokens reduce to other tokens, if it is a list, then it executes the
  first element as a function with the other elements as values to the
  function.
  When a normal function, each paremeter will be reduced recursively.
  When a macro function, each parameter will be given as is.
  """
  @spec reduce(Token.t) :: Token.t
  def reduce(%Token{type: :list, macro: false} = tok) do
    reduce_list(tok.value)
  end
  def reduce(%Token{type: :symbol} = tok) do
    resolve_symbol(tok)
  end

  def reduce(%Token{} = tok) do
    fn state ->
      {tok, state}
    end
  end
  defp reduce_list([f | params]) do
    runfunc = fn tok ->
      arbitrary = tok.value
      case tok do
        %Token{type: :function, macro: true} -> arbitrary.(params)
        %Token{type: :function} ->
          fn state ->
            reduce_result = list_reduce(params).(state)
            # Logger.info("Reduce list #{inspect params} -> #{inspect reduce_result}")
            {vs, state2} = reduce_result
            arbitrary.(vs).(state2)
          end
        _ -> throw {:not_a_function, tok}
      end
    end
    fn state ->
      try do
        {fun, state} = reduce(f).(state)
        {{fun_res, fun_ref}, state} = case fun do
          %Token{type: :function} = tok ->
            {res, state} = runfunc.(tok).(state)
            {{res, tok}, state}
          %Token{type: :symbol} ->
            {tok, state} = resolve_symbol(fun).(state)
            {res, state} = runfunc.(tok).(state)
            {{res, tok}, state}
          _ -> throw {:not_a_function, fun}
        end
        {result, state} = case fun_res do
          fun when is_function(fun) ->
            env = case fun_ref do
              %Token{env: nil} -> Mutable.env_ref(state)
              %Token{env: environment} -> environment
            end
            env_pre = Mutable.env_ref(state)
            state = Mutable.env_override(state, env)
            {res, state} = fun.(state)
            state = Mutable.env_override(state, env_pre)
            {res, state}
          val -> {val, state}
        end
        {_, state} = add_reduction().(state)
        {result, state}
      catch
        err ->
          state = Mutable.handle_error(state, err)
          {symbol(nil, mko(:error)), state}
      end
    end
  end
  defp reduce_list(bad) do
    throw {:not_implemented, bad}
  end

  @doc """
  Look up a symbol from the environment.
  Will throw if no value is found.
  """
  @spec resolve_symbol(Token.t) :: Token.t
  def resolve_symbol(%Token{value: sy} = sy_tok) do
    fn state ->
      try do
        tok = Mutable.env_lookup(state, sy)
        result = case tok do
          {:ok, val} -> val
          :not_found -> throw {:no_symbol_found, sy_tok}
        end
        {result, state}
      catch
        err ->
          state = Mutable.handle_error(state, err)
          {symbol(nil, mko(:error)), state}
      end
    end
  end

  @doc """
  Adds a reduction statistic to the execution context.

  Will throw `:max_reductions_reached` when the executions exceed
  the maximum.
  """
  @spec add_reduction() :: (Mutable.t -> {nil, Mutable.t})
  def add_reduction do
    fn state ->
      state2 = Mutable.reductions_inc(state)
      case state.max_reductions do
        num when is_number(num) ->
          if state.reductions > num do
            throw :max_reductions_reached
          end
        _ -> nil
      end
      {nil, state2}
    end
  end

  defp list_reduce([]) do
    fn state ->
      {[], state}
    end
  end
  defp list_reduce([head | tail]) do
    fn state ->
      try  do
        {v, state2} = reduce(head).(state)
        {r, state3} = list_reduce(tail).(state2)
        {[v | r], state3}
      catch
        err ->
          state = Mutable.handle_error(state, err)
          {symbol(nil, mko(:error)), state}
      end
    end
  end
  defp list_reduce(bad) do
    throw {:not_implemented, bad}
  end
end
