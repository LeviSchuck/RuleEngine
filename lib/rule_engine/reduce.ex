defmodule RuleEngine.Reduce do
  @moduledoc """
  This is where computation occurs and is limited.
  Reduction happens recursively for each value.
  If a value is quoted, the structure as is will be value.
  """
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
            {vs, state2} = list_reduce(params).(state)
            arbitrary.(vs).(state2)
          end
        _ -> throw {:not_a_function, tok}
      end
    end
    fn state ->
      {fun, state2} = reduce(f).(state)
      {{fun_res, fun_ref}, state2} = case fun do
        %Token{type: :function} = tok ->
          {res, state2_1} = runfunc.(tok).(state2)
          {{res, tok}, state2_1}
        %Token{type: :symbol} ->
            {tok, state2_1} = resolve_symbol(fun).(state2)
            {res, state2_2} = runfunc.(tok).(state2_1)
            {{res, tok}, state2_2}
        _ -> throw {:not_a_function, fun}
      end
      {result, state3} = case fun_res do
        fun when is_function(fun) ->
          env = case fun_ref do
            %Token{env: nil} -> Mutable.env_ref(state2)
            %Token{env: environment} -> environment
          end
          env_pre = Mutable.env_ref(state2)
          state2_1 = Mutable.env_override(state2, env)
          {res, state2_2} = fun.(state2_1)
          state2_3 = Mutable.env_override(state2_2, env_pre)
          {res, state2_3}
        val -> {val, state2}
      end
      {_, state4} = add_reduction().(state3)
      {result, state4}
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
      tok = Mutable.env_lookup(state, sy)
      result = case tok do
        {:ok, val} -> val
        :not_found -> throw {:no_symbol_found, sy_tok}
      end
      {result, state}
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
      {v, state2} = reduce(head).(state)
      {r, state3} = list_reduce(tail).(state2)
      {[v | r], state3}
    end
  end
  defp list_reduce(bad) do
    throw {:not_implemented, bad}
  end
end
