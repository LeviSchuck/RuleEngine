defmodule RuleEngine.Eval do
  @moduledoc """
  This module evaluates `RuleEngine.AST`
  """
  require RuleEngine.AST
  import RuleEngine.AST

  defmodule Stack do
    defstruct [
      stack: [],
      symbols: %{},
      values: %{},
      level: 0,
      step: 0
    ]
  end

  @doc """
  Evaluate a list of AST
  """
  @spec exec([tuple], %{}, %{})
    :: {:ok, %{}}
    |  {:error, any, %{}}
  def exec(ops, state, accessors \\ %{}) do
    res = eval_list(ops, state, accessors)
    case res do
      {:ok, _, st, _} -> {:ok, st}
      {:error, _, _, _} -> res
    end
  #rescue
  #  err -> {:error, {:internal_error, err}, nil}
  end

  defp eval_app(op, state, access, stack) do
    fun = apply_fun(op, :fun)
    st = stack
      |> advance_stack()
      |> push_stack(fun)
    res = eval_op(op, state, access, st)
    case res do
      {:ok, val, st, s} ->
        okay(val, st, pop_stack(s))
      _ -> res
    end
  end

  def eval_op(op, state, access \\ %{}, stack \\ %Stack{}) do
    # IO.puts("eval(#{inspect op}, #{inspect state}, _)")
    eval(
      apply_fun(op, :fun),
      apply_fun(op, :values),
      state,
      access,
      stack
      )
  end

  def eval_list(ops, state, access \\ %{}, stack \\ %Stack{}) do
    Enum.reduce_while(ops, {:ok, nil, state, stack}, fn op, {:ok, _, os, s} ->
      case eval_app(op, os, access, s) do
        {:ok, val, ns, s1} -> {:cont, okay(val, ns, s1)}
        {:error, err, ns, s1} -> {:halt, error(err, ns, s1)}
      end
    end)
  end
  defp eval(:escaped_list, val, os, _, s) do
    okay(val, os, s)
  end
  defp eval(:literal, vals, state, _, stack) do
    case vals do
      [v | _] -> okay(v, state, stack)
      _ -> okay(nil, state, stack)
    end
  end
  defp eval(:and, [], s, _, _) do
    {:ok, false, s}
  end
  defp eval(:or, [], s, _, _) do
    {:ok, false, s}
  end
  defp eval(:and, vals, state, access, stack) do
    fnand = fn i, {_, st, s} ->
      eval_and(i, st, access, s)
    end
    res = Enum.reduce_while(vals, {true, state, stack}, fnand)
    case res do
      {:error, e, ns} -> error(e, ns, stack)
      {b, ns, s} -> okay(b, ns, s)
    end
  end

  defp eval(:or, vals, state, access, stack) do
    fnor = fn i, {_, st, s} ->
      eval_or(i, st, access, s)
    end
    res = Enum.reduce_while(vals, {false, state, stack}, fnor)
    case res do
      {:error, e, ns, s} -> error(e, ns, s)
      {b, ns, s} -> okay(b, ns, s)
    end
  end

  defp eval(:get, ops, state, access, stack) do
    one_param(fn key, ns, st ->
      okay(Map.get(ns, key), ns, st)
    end, nil, ops, state, access, stack)
  end

  defp eval(:set, ops, state, access, stack) do
    two_param(fn key, value, ns1, s ->
      ns2 = Map.put(ns1, key, value)
      okay(nil, ns2, s)
    end, nil, ops, state, access, stack)
  end

  defp eval(:equals, ops, state, access, stack) do
    two_param(fn v1, v2, ns, s ->
      okay(v1 == v2, ns, s)
    end, false, ops, state, access, stack)
  end

  defp eval(:less_than, ops, state, access, stack) do
    two_param(fn v1, v2, ns, s ->
      okay(v1 < v2, ns, s)
    end, false, ops, state, access, stack)
  end

  defp eval(:greater_than, ops, state, access, stack) do
    two_param(fn v1, v2, ns, s ->
      okay(v1 > v2, ns, s)
    end, false, ops, state, access, stack)
  end

  defp eval(:less_than_or_equals, ops, state, access, stack) do
    two_param(fn v1, v2, ns, s ->
      okay(v1 <= v2, ns, s)
    end, false, ops, state, access, stack)
  end

  defp eval(:greater_than_or_equals, ops, state, access, stack) do
    two_param(fn v1, v2, ns, s ->
      okay(v1 >= v2, ns, s)
    end, false, ops, state, access, stack)
  end

  defp eval(:not, ops, state, access, stack) do
    one_param(fn v, ns, s ->
      cond do
        is_boolean(v) -> okay(not(v), ns, s)
        true -> error({:not_boolean, v}, ns, s)
      end
    end, false, ops, state, access, stack)
  end

  defp eval(:is_nil, ops, state, access, stack) do
    one_param(fn v, ns, s ->
      okay(is_nil(v), ns, s)
    end, true, ops, state, access, stack)
  end

  defp eval(:cond, ops, state, access, stack) do
    Enum.reduce_while(ops, {:ok, nil, state, stack}, fn op, {_, old, os, s0} ->
      res1 = eval_app(op, os, access, s0)
      case res1 do
        {:ok, [c | ops], ns1, s1} ->
          res2 = eval_app(c, ns1, access, s1)
          case res2 do
            {:ok, true, ns2, s2} ->
              res3 = eval_list(ops, ns2, access, s2)
              case res3 do
                {:ok, result, ns3, s3} -> {:halt, okay(result, ns3, s3)}
                {:error, _, _, _} -> {:halt, res3}
              end
            {:ok, nil, ns2, s2} -> {:cont, okay(old, ns2, s2)}
            {:ok, false, ns2, s2} -> {:cont, okay(old, ns2, s2)}
            {:ok, bad, ns2, s2} -> {:halt, error({:not_boolean, bad}, ns2, s2)}
          end
        {:ok, [], ns1, s1} ->  {:halt, error(:no_conditions, ns1, s1)}
        {:error, _, _, _} -> {:halt, res1}
      end
    end)
  end

  defp eval(:substring, ops, state, access, stack) do
    two_param(fn str, sub, ns, s ->
      cond do
        not(is_binary(str)) -> error({:not_string, str}, ns, s)
        not(is_binary(sub)) -> error({:not_string, sub}, ns, s)
        true -> okay(String.contains?(str, sub), ns, s)
      end
    end, false, ops, state, access, stack)
  end

  defp two_param(fun, _, [op1, op2 | _], state, access, stack) do
    with {:ok, v1, ns1, s1} <- eval_app(op1, state, access, stack),
         {:ok, v2, ns2, s2} <- eval_app(op2, ns1, access, s1),
     do: fun.(v1, v2, ns2, s2)
  end
  defp two_param(_, default, _, state, _, stack) do
    okay(default, state, stack)
  end

  defp one_param(fun, _, [op1 | _], state, access, stack) do
    with {:ok, v1, ns1, s1} <- eval_app(op1, state, access, stack),
     do: fun.(v1, ns1, s1)
  end
  defp one_param(_, default, _, state, _, stack) do
    okay(default, state, stack)
  end

  defp eval_or(op, state, access, stack) do
    res = eval_app(op, state, access, stack)
    case res do
      {:ok, true, ns, s} -> {:halt, {true, ns, s}}
      {:ok, false, ns, s} -> {:cont, {false, ns, s}}
      {:ok, nil, ns, s} -> {:cont, {false, ns, s}}
      {:ok, bad, ns, s} -> {:halt, error({:not_boolean, bad}, ns, s)}
      {:error, err, ns, s} -> {:halt, error(err, ns, s)}
    end
  end

  defp eval_and(op, state, access, stack) do
    res = eval_app(op, state, access, stack)
    case res do
      {:ok, true, ns, s} -> {:cont, {true, ns, s}}
      {:ok, false, ns, s} -> {:halt, {false, ns, s}}
      {:ok, nil, ns, s} -> {:cont, {false, ns, s}}
      {:ok, bad, ns, s} -> {:halt, error({:not_boolean, bad}, ns, s)}
      {:error, err, ns, s} -> {:halt, error(err, ns, s)}
    end
  end

  defp okay(value, state, stack), do: {:ok, value, state, stack}
  defp error(err, state, stack), do: {:error, err, state, stack}
  def advance_stack(stack), do: %{stack | step: stack.step + 1}
  def push_stack(stack, op, values \\ %{}) do
    level = stack.level
    nlevel = level + 1
    nsymbols = values
      |> Enum.map(fn {sy, _} -> sy end)
      |> Enum.reduce(stack.symbols, fn symbol, syms ->
        Map.update(syms, symbol, [nlevel], fn c ->
          [nlevel | c]
        end)
      end)
    nvalues = values
      |> Enum.map(fn {sy, v} ->
        {{sy, nlevel}, v}
      end)
      |> Enum.into(stack.values)
    nstack = [op | stack.stack]
    %{stack |
      level: nlevel,
      stack: nstack,
      symbols: nsymbols,
      values: nvalues
    }
  end
  def pop_stack(stack) do
    level = stack.level
    nlevel = level - 1
    nsymbols = Enum.map(stack.symbols, fn {sy, levels} ->
      case levels do
        [^level | rest] -> {sy, rest}
        _ -> {sy, levels}
      end
    end) |> Enum.filter(fn {_, levels} ->
      case levels do
        [_ | _] -> true
        _ -> false
      end
    end) |> Enum.into(%{})

    nvalues = stack.symbols
      |> Enum.reduce(stack.values, fn {sy, levels}, vals ->
        case levels do
          [^level | _] ->
            res = Map.delete(vals, {sy, level})
            res
          _ -> vals
        end
      end)
    nstack = case stack.stack do
      [_ | rest] -> rest
      [] -> []
    end
    %{stack |
      level: nlevel,
      stack: nstack,
      symbols: nsymbols,
      values: nvalues
    }
  end

end
