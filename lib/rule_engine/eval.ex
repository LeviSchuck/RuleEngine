defmodule RuleEngine.Eval do
  @moduledoc """
  This module evaluates `RuleEngine.AST`
  """
  require RuleEngine.AST
  import RuleEngine.AST

  @doc """
  Evaluate a list of AST
  """
  @spec exec([tuple], %{}, %{})
    :: {:ok, %{}}
    |  {:error, any, %{}}
  def exec(ops, state, accessors \\ %{}) do
    case eval_list(ops, state, accessors) do
      {:ok, _, st} -> {:ok, st}
      {:error, err, st} -> {:error, err, st}
    end
  #rescue
  #  err -> {:error, {:internal_error, err}, nil}
  end

  def eval_app(op, state, access \\ %{}) do
    # IO.puts("eval(#{inspect op}, #{inspect state}, _)")
    eval(
      apply_fun(op, :fun),
      apply_fun(op, :values),
      state,
      access
      )
  end

  def eval_list(ops, state, access \\ %{}) do
    Enum.reduce_while(ops, {:ok, nil, state}, fn op, {:ok, _, s} ->
      case eval_app(op, s, access) do
        {:ok, val, ns} -> {:cont, {:ok, val, ns}}
        {:error, err, ns} -> {:halt, {:error, err, ns}}
      end
    end)
  end
  defp eval(:escaped_list, val, s, _) do
    {:ok, val, s}
  end
  defp eval(:and, [], s, _) do
    {:ok, false, s}
  end
  defp eval(:or, [], s, _) do
    {:ok, false, s}
  end
  defp eval(:and, vals, state, access) do
    fnand = fn i, {_, st} ->
      eval_and(i, st, access)
    end
    res = Enum.reduce_while(vals, {true, state}, fnand)
    case res do
      {:error, _, _} -> res
      {b, ns} -> {:ok, b, ns}
    end
  end

  defp eval(:or, vals, state, access) do
    fnor = fn i, {_, st} ->
      eval_or(i, st, access)
    end
    res = Enum.reduce_while(vals, {false, state}, fnor)
    case res do
      {:error, _, _} -> res
      {b, ns} -> {:ok, b, ns}
    end
  end

  defp eval(:get, ops, state, access) do
    one_param(fn key, ns ->
      {:ok, Map.get(ns, key), ns}
    end, nil, ops, state, access)
  end

  defp eval(:set, ops, state, access) do
    two_param(fn key, value, ns ->
      {:ok, nil, Map.put(ns, key, value)}
    end, nil, ops, state, access)
  end

  defp eval(:literal, vals, state, _) do
    case vals do
      [v | _] -> {:ok, v, state}
      _ -> {:ok, nil, state}
    end
  end

  defp eval(:equals, ops, state, access) do
    two_param(fn v1, v2, ns ->
      {:ok, v1 == v2, ns}
    end, false, ops, state, access)
  end

  defp eval(:less_than, ops, state, access) do
    two_param(fn v1, v2, ns ->
      {:ok, v1 < v2, ns}
    end, false, ops, state, access)
  end

  defp eval(:greater_than, ops, state, access) do
    two_param(fn v1, v2, ns ->
      {:ok, v1 > v2, ns}
    end, false, ops, state, access)
  end

  defp eval(:less_than_or_equals, ops, state, access) do
    two_param(fn v1, v2, ns ->
      {:ok, v1 <= v2, ns}
    end, false, ops, state, access)
  end

  defp eval(:greater_than_or_equals, ops, state, access) do
    two_param(fn v1, v2, ns ->
      {:ok, v1 >= v2, ns}
    end, false, ops, state, access)
  end

  defp eval(:not, ops, state, access) do
    one_param(fn v, ns ->
      cond do
        is_boolean(v) -> {:ok, not(v), ns}
        true -> {:error, {:not_boolean, v}, ns}
      end
    end, false, ops, state, access)
  end

  defp eval(:is_nil, ops, state, access) do
    one_param(fn v, ns ->
      {:ok, is_nil(v), ns}
    end, true, ops, state, access)
  end

  defp eval(:cond, ops, state, access) do
    Enum.reduce_while(ops, {:ok, nil, state}, fn op, {_, old, s} ->
      res1 = eval_app(op, s, access)
      case res1 do
        {:ok, [c | ops], ns1} ->
          res2 = eval_app(c, ns1, access)
          case res2 do
            {:ok, true, ns2} ->
              res3 = eval_list(ops, ns2, access)
              case res3 do
                {:ok, result, ns3} -> {:halt, {:ok, result, ns3}}
                {:error, _, _} -> {:halt, res3}
              end
            {:ok, nil, ns2} -> {:cont, {:ok, old, ns2}}
            {:ok, false, ns2} -> {:cont, {:ok, old, ns2}}
            {:ok, bad, ns2} -> {:halt, {:error, {:not_boolean, bad}, ns2}}
          end
        {:ok, [], ns1} ->  {:halt, {:error, :no_conditions, ns1}}
        {:error, _, _} -> {:halt, res1}
      end
    end)
  end

  defp eval(:substring, ops, state, access) do
    two_param(fn str, sub, ns ->
      cond do
        not(is_binary(str)) -> {:error, {:not_string, str}, ns}
        not(is_binary(sub)) -> {:error, {:not_string, sub}, ns}
        true -> {:ok, String.contains?(str, sub), ns}
      end
    end, false, ops, state, access)
  end

  defp two_param(fun, _, [op1, op2 | _], state, access) do
    with {:ok, v1, ns1} <- eval_app(op1, state, access),
         {:ok, v2, ns2} <- eval_app(op2, ns1, access),
     do: fun.(v1, v2, ns2)
  end
  defp two_param(_, default, _, state, _) do
    {:ok, default, state}
  end

  defp one_param(fun, _, [op1 | _], state, access) do
    with {:ok, v1, ns1} <- eval_app(op1, state, access),
     do: fun.(v1, ns1)
  end
  defp one_param(_, default, _, state, _) do
    {:ok, default, state}
  end

  defp eval_or(op, state, access) do
    res = eval_app(op, state, access)
    case res do
      {:ok, false, ns} -> {:cont, {false, ns}}
      {:ok, nil, ns} -> {:cont, {false, ns}}
      {:ok, true, ns} -> {:halt, {true, ns}}
      {:ok, bad, ns} -> {:halt, {:error, {:not_boolean, bad}, ns}}
      {:error, err, ns} -> {:halt, {:error, err, ns}}
    end
  end

  defp eval_and(op, state, access) do
    res = eval_app(op, state, access)
    case res do
      {:ok, true, ns} -> {:cont, {true, ns}}
      {:ok, false, ns} -> {:halt, {false, ns}}
      {:ok, bad, ns} -> {:halt, {:error, {:not_boolean, bad}, ns}}
      {:error, err, ns} -> {:halt, {:error, err, ns}}
    end
  end

end
