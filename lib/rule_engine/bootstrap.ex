defmodule RuleEngine.Bootstrap do
  alias RuleEngine.Mutable
  alias RuleEngine.Reduce
  import RuleEngine.Types
  alias RuleEngine.Types.Token
  require Monad.State, as: State
  def bootstrap_environment() do
    %{
      outer: nil,
      vals: %{
        "==" => mkfun(fn x, y -> x == y end, [:any, :any]),
        "!=" => mkfun(fn x, y -> x != y end, [:any, :any]),
        "<" => mkfun(fn x, y -> x < y end, [:any, :any]),
        ">" => mkfun(fn x, y -> x > y end, [:any, :any]),
        "<=" => mkfun(fn x, y -> x <= y end, [:any, :any]),
        ">=" => mkfun(fn x, y -> x >= y end, [:any, :any]),
        "+" => plusfun(),
        "-" => minusfun(),
        "nil?" => nil_check(),
        "boolean?" => bool_check(),
        "symbol?" => simple_fun(&symbol?/1),
        "list?" => simple_fun(&list?/1),
        "map?" => simple_fun(&map?/1),
        "string?" => simple_fun(&string?/1),
        "number?" => simple_fun(&number?/1),
        "function?" => simple_fun(&function?/1),
        "macro?" => simple_fun(&macro?/1),
        "do" => do_fun(),
        "quote" => quote_fun(),
        "if" => if_fun(),
      }
    }
  end

  def bootstrap_mutable() do
    %Mutable{
      environment: bootstrap_environment()
    }
  end
  def convert({:error, err}), do: throw err
  def convert(%Token{} = res), do: res
  def convert(res) when is_boolean(res), do: symbol(res)
  def convert(nil), do: symbol(nil)
  def convert(res) when is_number(res), do: number(res)
  def convert(res) when is_binary(res), do: string(res)
  def convert(res) when is_map(res) do
    Enum.map(res, fn {k, v} ->
      {convert(k), convert(v)}
    end)
      |> Enum.into(%{})
      |> map()
  end
  def convert(res) when is_list(res) do
    Enum.map(res, &convert/1)
      |> list()
  end
  def convert(res) when is_function(res), do: function(res)
  def convert(res), do: {:error, {:cannot_convert, res}}

  def simple_fun(fun) do
    lambda = fn args ->
      largs = length(args)
      case args do
        [arg] ->
          fun.(arg)
            |> convert()
        _ -> {:error, err_arity(1, largs)}
      end
    end
    wrap_state(lambda)
  end

  def simple_macro(fun) do
    macro(fn args ->
      State.m do
        res <- fun.(args)
        return res
      end
    end)
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
                      true -> {:halt, {:error, err_type(:same, ref_ty, t)}}
                    end
                end
              :any -> {:cont, {same, :ok}}
              other ->
                cond do
                  other == t -> {:cont, {same, :ok}}
                  true -> {:halt, {:error, err_type(other, t)}}
                end
            end
          end)
          case type_check do
            {_, :ok} -> exec_fun(fun, args)
            {:error, err} -> {:error, err}
          end
        true -> {:error, err_arity(ltypes, largs)}
      end
    end
    wrap_state(lambda)
  end 
  defp exec_fun(fun, typed_args) do
    args = Enum.map(typed_args, fn %Token{value: v} ->
      v
    end)
    apply(fun, args)
      |> convert()
  end
  defp wrap_state(lambda) do
    function(fn args ->
      State.m do
        return lambda.(args)
      end
    end)
  end

  defp all_type_check(args, type) do
    Enum.reduce_while(args, :ok, fn %Token{type: t}, :ok ->
      case t do
        ^type -> {:cont, :ok}
        _ -> {:halt, {:error, {:type_mismatch, "Expected #{type} as argument type, but got #{t}"}}}
      end
    end)
  end

  defp minusfun() do
    lambda = fn args ->
      type_check = all_type_check(args, :number)
      case type_check do
        :ok ->
          case args do
            [one] ->
              number(-one.value)
            [first | rest] ->
              number(Enum.reduce(rest, first.value, fn x, y ->
                y - x.value
              end))
          end
        _ -> type_check
      end
    end
    wrap_state(lambda)
  end
  defp plusfun() do
    lambda = fn args ->
      type_check = all_type_check(args, :number)
      case type_check do
        :ok ->
          number(Enum.reduce(args, 0, fn x, y ->
            x.value + y
          end))
        _ -> type_check
      end
    end
    wrap_state(lambda)
  end
  defp bool_check() do
    simple_fun(fn x ->
      res = case x.type do
        :symbol ->
          case x.value do
            true -> true
            false -> true
            nil -> true
            _ -> false
          end
        _ -> false
      end
      symbol(res)
    end)
  end
  defp nil_check() do
    simple_fun(fn x ->
      res = case x.type do
        :symbol -> is_nil(x.value)
        _ -> false
      end
      symbol(res)
    end)
  end
  def do_fun() do
    simple_macro(fn ast ->
      State.m do
        res <- lastReduce(ast)
        return res
      end
    end)
  end
  def quote_fun() do
    simple_macro(fn ast ->
      case ast do
        [single] ->
          State.m do
            return single
          end
        _ -> throw err_arity(1, length(ast))
      end
    end)
  end
  def if_fun() do
    simple_macro(fn ast ->
      case ast do
        [condition, true_ast, false_ast] ->
          State.m do
            result <- Reduce.reduce(condition)
            case result do
              %Token{type: :symbol, value: true} -> Reduce.reduce(true_ast)
              %Token{type: :symbol, value: false} -> Reduce.reduce(false_ast)
              %Token{type: :symbol, value: nil} -> Reduce.reduce(false_ast)
              _ -> throw {:condition_not_boolean, result}
            end
          end
        _ -> throw err_arity(3, length(ast))
      end
    end)
  end

  defp lastReduce([]) do
    State.m do
      return nil
    end
  end
  defp lastReduce([head]) do
    State.m do
      v <- Reduce.reduce(head)
      return v
    end
  end
  defp lastReduce([head | rest]) do
    State.m do
      _ <- Reduce.reduce(head)
      res <- lastReduce(rest)
      return res
    end
  end
  def err_arity(expected, actual) do
    {:arity_mismatch, "Expected #{expected} arguments, got #{actual}"}
  end
  def err_type(:same, ref_ty, t) do
    {:type_mismatch, "Expected the same type for some args as prior args, namely #{ref_ty} instead of #{t}"}
  end
  def err_type(ref_ty, t) do
    {:type_mismatch, "Expected #{ref_ty} as argument type, but got #{t}"}
  end
end
