defmodule RuleEngine.Bootstrap do
  alias RuleEngine.Mutable
  import RuleEngine.Types
  alias RuleEngine.Types.Token
  require Monad.State, as: State
  def bootstrap_environment() do
    %{
      outer: nil,
      vals: %{
        "==" => mkfun(fn x, y -> symbol(x == y) end, [:any, :any]),
        "!=" => mkfun(fn x, y -> symbol(x != y) end, [:any, :any]),
        "<" => mkfun(fn x, y -> symbol(x < y) end, [:any, :any]),
        ">" => mkfun(fn x, y -> symbol(x > y) end, [:any, :any]),
        "<=" => mkfun(fn x, y -> symbol(x <= y) end, [:any, :any]),
        ">=" => mkfun(fn x, y -> symbol(x >= y) end, [:any, :any]),
        "+" => mkfun(fn x, y -> number(x + y) end, [:number, :number]),
      }
    }
  end

  def bootstrap_mutable() do
    %Mutable{
      environment: bootstrap_environment()
    }
  end
  def mkfun(fun, types) do
    lambda = fn args ->
      ltypes = length(types)
      largs = length(args)
      cond do
        ltypes == largs ->
          argtys = Enum.zip(types, args)
          type_check = Enum.reduce_while(argtys, {%{}, :ok}, fn {ty, %Token{type: t}}, {same, :ok} ->
            case ty do
              {:same, label} ->
                case Map.get(same, label, :not_found) do
                  :not_found -> {:cont, {Map.put(same, label, t), :ok}}
                  ref_ty ->
                    cond do
                      ref_ty == t -> {:cont, {same, :ok}}
                      true -> {:halt, {:error, {:type_mismatch, "Expected the same type for some args as prior args, namely #{ref_ty} instead of #{t}"}}}
                    end
                end
              :any -> {:cont, {same, :ok}}
              other ->
                cond do
                  other == t -> {:cont, {same, :ok}}
                  true -> {:halt, {:error, {:type_mismatch, "Expected #{other} as argument type, but got #{t}"}}}
                end
            end
          end)
          case type_check do
            {_, :ok} -> exec_fun(fun, args)
            {:error, err} -> {:error, err}
          end
        true -> {:error, {:arity_mismatch, "Expected #{largs} arguments, got #{ltypes}"}}
      end
    end
    function(fn args ->
      State.m do
        return lambda.(args)
      end
    end)
  end 
  defp exec_fun(fun, typed_args) do
    args = Enum.map(typed_args, fn %Token{value: v} ->
      v
    end)
    apply(fun, args)
  end
end
