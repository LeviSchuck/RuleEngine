defmodule RuleEngine.Bootstrap do
  @moduledoc """
  To get your functions up and running, Bootstrap comes with many
  handy functions to build your environment quickly.

  State modifying functions are more clunky and not recommended unless you
  are making type sensitive macros.

  To make a basic state altering function, you can return
  ```
  alias RuleEngine.Bootstrap
  alias RuleEngine.Types
  Bootstrap.state_fun(fn ->
    fn state ->
      {return_value_here, state}
    end
  end, [], Types.mko(:your_module))
  ```

  To make a basic pre-typed and abstracted function, you can return
  ```
  alias RuleEngine.Bootstrap
  alias RuleEngine.Types
  Bootstrap.mkfun(fn x, y ->
    x <> y
  end, [:string, :string], Types.mko(:your_module))
  ```
  where the second parameter is a list of the parameters and types.
  The return type is automatically converted from a native type:
  * number
  * string
  * boolean
  * nil
  * list (with any element being a supported type)
  * dict / map (with any key or value being a supported type)

  """
  alias RuleEngine.Mutable
  alias RuleEngine.Environment
  alias RuleEngine.Reduce
  import RuleEngine.Types
  alias RuleEngine.Types.Token

  @origin mko(:bootstrap)

  def bootstrap_origin, do: @origin

  @doc "Bootstrap environment with basic functions"
  @spec bootstrap_environment() :: %{}
  def bootstrap_environment do
    core = %{
      # Comparators
      "==" => mkfun(fn x, y -> x == y end, [:any, :any], @origin),
      "!=" => mkfun(fn x, y -> x != y end, [:any, :any], @origin),
      "<" => mkfun(fn x, y -> x < y end, [:any, :any], @origin),
      ">" => mkfun(fn x, y -> x > y end, [:any, :any], @origin),
      "<=" => mkfun(fn x, y -> x <= y end, [:any, :any], @origin),
      ">=" => mkfun(fn x, y -> x >= y end, [:any, :any], @origin),
      # Combinatoral
      "&&" => mkfun(fn x, y -> x && y end, [:boolean, :boolean], @origin),
      "||" => mkfun(fn x, y -> x || y end, [:boolean, :boolean], @origin),
      "++" => mkfun(fn x, y -> x <> y end, [:string, :string], @origin),
      # Folding Combinatoral operations
      "+" => plus_fun(),
      "-" => minus_fun(),
      "and" => and_fun(),
      "or" => or_fun(),
      # Iteration
      "map" => map_fun(),
      "reduce" => reduce_fun(),
      # Types
      "nil?" => simple_fun(&nil?/1, @origin),
      "boolean?" => simple_fun(&boolean?/1, @origin),
      "symbol?" => simple_fun(&symbol?/1, @origin),
      "list?" => simple_fun(&list?/1, @origin),
      "dict?" => simple_fun(&dict?/1, @origin),
      "string?" => simple_fun(&string?/1, @origin),
      "number?" => simple_fun(&number?/1, @origin),
      "function?" => simple_fun(&function?/1, @origin),
      "macro?" => simple_fun(&macro?/1, @origin),
      "atom?" => simple_fun(&atom?/1, @origin),
      # Macros
      "do" => do_fun(),
      "quote" => quote_fun(),
      "if" => if_fun(),
      "let" => let_fun(),
      "fn" => lambda_fun(),
      "def" => def_fun(),
      "apply" => apply_fun(),
      "make-dict" => dict_fun(),
      # Built in symbols
      "true" => symbol(true, @origin),
      true => symbol(true, @origin),
      "false" => symbol(false, @origin),
      false => symbol(false, @origin),
      "nil" => symbol(nil, @origin),
      nil => symbol(nil, @origin),
      # Atom ops
      "atom" => state_fun(&make_atom/1, [:any], @origin),
      "deref" => state_fun(&deref_atom/1, [:atom], @origin),
      "reset!" => state_fun(&reset_atom/2, [:atom, :any], @origin),
      # "swap!" => mkfun(???, [:atom, :function])
      "set!" => set_fun(),
    }
    Environment.make(core, nil, :bootstrap)
  end

  @doc "Wraps the bootstrap environment in an execution context"
  @spec bootstrap_mutable() :: Mutable.t
  def bootstrap_mutable do
    %Mutable{
      environment: bootstrap_environment()
    }
  end

  @doc """
  Converts an elixir / erlang data structure to a Token.
  """
  @spec convert(any, Origin.t) :: Token.t
  def convert({:error, err}, _), do: throw err
  def convert(%Token{} = res, _), do: res
  def convert(res, origin) when is_boolean(res), do: symbol(res, origin)
  def convert(nil, origin), do: symbol(nil, origin)
  def convert(res, origin) when is_number(res), do: number(res, origin)
  def convert(res, origin) when is_binary(res), do: string(res, origin)
  def convert(res, origin) when is_map(res) do
    Enum.map(res, fn {k, v} ->
      {convert(k, origin), convert(v, origin)}
    end)
      |> Enum.into(%{})
      |> dict(origin)
  end
  def convert(res, origin) when is_list(res) do
    Enum.map(res, &convert(&1, origin))
      |> list(origin)
  end
  def convert(res, origin) when is_function(res), do: function(res, origin)
  def convert(res, origin), do: hack(res, origin)

  defp simple_fun(fun, origin) do
    lambda = fn args ->
      largs = length(args)
      case args do
        [arg] ->
          fun.(arg)
            |> convert(origin)
        _ -> throw err_arity(1, largs)
      end
    end
    wrap_state(lambda, origin)
  end


  @type fun_type
    :: :boolean
    | :any
    | :number
    | :string
    | :atom
    | :dict
    | :list
    | {:same, fun_type}
  @doc """
  This is a function wrapper to check the types on the AST inputs.
  It may also unwrap the value when `:convert` is given.

  `:naked` means not to unwrap tokens to their plain values
  """
  @spec mk_core_fun(Fun, [fun_type], :naked | :convert, Origin.t) :: Fun
  def mk_core_fun(fun, types, conversion, origin) do
    fn args ->
      ltypes = length(types)
      largs = length(args)
      cond do
        ltypes == largs ->
          argtys = Enum.zip(types, args)
          type_check = Enum.reduce_while(
            argtys,
            {%{}, :ok},
            fn {ty, %Token{type: t} = tok}, {same, :ok} ->
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
                :boolean ->
                  cond do
                    boolean?(tok) -> {:cont, {same, :ok}}
                    true -> {:halt, {:error, err_type(:boolean, t)}}
                  end
                other ->
                  cond do
                    other == t -> {:cont, {same, :ok}}
                    with_type?(tok, other) -> {:cont, {same, :ok}}
                    true -> {:halt, {:error, err_type(other, t)}}
                  end
              end
            end)
          case type_check do
            {_, :ok} ->
              case conversion do
                :convert -> exec_fun(fun, args, origin)
                :naked -> apply(fun, args)
              end
            {:error, err} -> throw err
          end
        true -> throw err_arity(ltypes, largs)
      end
    end
  end

  @doc "Makes a function that can be called with unwrapped typed values"
  @spec mkfun(Fun, [fun_type], Origin.t) :: Token.t
  def mkfun(fun, types, origin) do
    lambda = mk_core_fun(fun, types, :convert, origin)
    wrap_state(lambda, origin)
  end

  @doc """
  Makes a function that can modify state which can be called
  with wrapped typed values
  """
  @spec state_fun(Fun, [fun_type], Origin.t) :: Token.t
  def state_fun(fun, types, origin) do
    lambda = mk_core_fun(fun, types, :naked, origin)
    function(lambda, origin)
  end

  defp exec_fun(fun, typed_args, origin) do
    args = Enum.map(typed_args, fn %Token{value: v} ->
      v
    end)
    apply(fun, args)
      |> convert(origin)
  end

  defp wrap_state(lambda, origin) do
    function(fn args ->
      fn state ->
        {lambda.(args), state}
      end
    end, origin)
  end

  defp all_type_check(args, type) do
    Enum.each(args, fn %Token{type: t} = tok ->
      case t do
        ^type -> nil
        _ -> throw err_type(type, t, tok)
      end
    end)
    :ok
  end

  defp minus_fun do
    lambda = fn args ->
      type_check = all_type_check(args, :number)
      case type_check do
        :ok ->
          case args do
            [one] ->
              number(-one.value, @origin)
            [first | rest] ->
              number(Enum.reduce(rest, first.value, fn x, y ->
                y - x.value
              end), @origin)
          end
        _ -> type_check
      end
    end
    wrap_state(lambda, @origin)
  end
  defp plus_fun do
    lambda = fn args ->
      type_check = all_type_check(args, :number)
      case type_check do
        :ok ->
          number(Enum.reduce(args, 0, fn x, y ->
            x.value + y
          end), @origin)
        _ -> type_check
      end
    end
    wrap_state(lambda, @origin)
  end

  defp and_fun do
    macro(fn ast ->
      fn state ->
        {res, state_final} = Enum.reduce_while(
          ast,
          {true, state},
          fn v, {_, s} ->
            {res, state2} = Reduce.reduce(v).(s)
            case res do
              %Token{type: :symbol, value: nil} -> {:halt, {false, state2}}
              %Token{type: :symbol, value: false} -> {:halt, {false, state2}}
              %Token{type: :symbol, value: true} -> {:cont, {true, state2}}
              _ -> throw err_type(:boolean, v.type, v)
            end
          end)
        {symbol(res, @origin), state_final}
      end
    end, @origin)
  end

  defp or_fun do
    macro(fn ast ->
      fn state ->
        {res, state_final} = Enum.reduce_while(
          ast,
          {false, state},
          fn v, {_, s} ->
            {res, state2} = Reduce.reduce(v).(s)
            case res do
              %Token{type: :symbol, value: nil} -> {:cont, {false, state2}}
              %Token{type: :symbol, value: false} -> {:cont, {false, state2}}
              %Token{type: :symbol, value: true} -> {:halt, {true, state2}}
              _ -> throw err_type(:boolean, v.type, v)
            end
          end)
        {symbol(res, @origin), state_final}
      end
    end, @origin)
  end

  defp map_fun do
    macro(fn ast ->
      case ast do
        [collection, fun] ->
          fn state ->
            {fun_ref, state2} = Reduce.reduce(fun).(state)
            case fun_ref do
              %Token{type: :function} -> nil
              _ -> throw err_type(:function, fun_ref.type, fun_ref)
            end
            {col_ref, state3} = Reduce.reduce(collection).(state2)
            case col_ref do
              %Token{type: :list} -> map_fun_list(fun_ref, col_ref, state3)
              %Token{type: :dict} -> map_fun_dict(fun_ref, col_ref, state3)
              _ -> throw err_type([:list, :dict], col_ref.type, col_ref)
            end
          end
        _ -> throw err_arity(2, length(ast))
      end
    end, @origin)
  end
  defp map_fun_list(fun_ref, col_ref, state) do
    {res, state2} = Enum.map_reduce(
      col_ref.value,
      state,
      fn col, s ->
        {val, s2} = Reduce.reduce(list([fun_ref, col])).(s)
        {val, s2}
      end)
    res_list = res
      |> list(@origin)
    {res_list, state2}
  end
  defp map_fun_dict(fun_ref, col_ref, state) do
    {res, state2} = Enum.map_reduce(
      col_ref.value,
      state,
      fn {k_col, v_col}, s ->
        {val, s2} = Reduce.reduce(list([fun_ref, k_col, v_col])).(s)
        {{k_col, val}, s2}
      end)
    as_dict = Enum.into(res, %{})
      |> dict(@origin)
    {as_dict, state2}
  end

  defp reduce_fun do
    macro(fn ast ->
      case ast do
        [collection, acc, fun] ->
          fn state ->
            {fun_ref, state2} = Reduce.reduce(fun).(state)
            case fun_ref do
              %Token{type: :function} -> nil
              _ -> throw err_type(:function, fun_ref.type, fun_ref)
            end
            {col_ref, state3} = Reduce.reduce(collection).(state2)
            case col_ref do
              %Token{type: :list} ->
                reduce_fun_list(fun_ref, col_ref, acc, state3)
              %Token{type: :dict} ->
                reduce_fun_dict(fun_ref, col_ref, acc, state3)
              _ -> throw err_type([:list, :dict], col_ref.type, col_ref)
            end
          end
      end
    end, @origin)
  end

  defp reduce_fun_list(fun_ref, col_ref, acc, state) do
    {res, state2} = Enum.reduce(
      col_ref.value,
      {acc, state},
      fn col, {a, s} ->
        {next_a, s2} = Reduce.reduce(list([fun_ref, col, a])).(s)
        {next_a, s2}
      end)
    {res, state2}
  end
  defp reduce_fun_dict(fun_ref, col_ref, acc, state) do
    {res, state2} = Enum.reduce(
      col_ref.value,
      {acc, state},
      fn {k_col, v_col}, {a, s} ->
        {next_a, s2} = Reduce.reduce(list([fun_ref, k_col, v_col, a])).(s)
        {next_a, s2}
      end)
    {res, state2}
  end

  defp make_atom(value) do
    fn state ->
      {state2, atom_ref} = Mutable.atom_new(state, value)
      {atom(atom_ref), state2}
    end
  end

  defp deref_atom(atom) do
    atom_ref = Map.get(atom, :value, atom)
    fn state ->
      {state2, atom_val} = Mutable.atom_deref(state, atom_ref)
      case atom_val do
        :not_found -> throw err_no_atom(atom_ref)
        _ -> {atom_val, state2}
      end
    end
  end

  defp reset_atom(atom, atom_value) do
    atom_ref = atom.value
    fn state ->
      {state2, rvalue} = Mutable.atom_reset!(state, atom_ref, atom_value)
      {rvalue, state2}
    end
  end

  # Macros
  defp do_fun do
    macro(fn ast ->
      lastReduce(ast)
    end, @origin)
  end
  defp quote_fun do
    macro(fn ast ->
      case ast do
        [single] ->
          fn state ->
            {single, state}
          end
        _ -> throw err_arity(1, length(ast))
      end
    end, @origin)
  end
  defp if_fun do
    macro(fn ast ->
      case ast do
        [condition, true_ast, false_ast] ->
          fn state ->
            {result, state2} = Reduce.reduce(condition).(state)
            case result do
              %Token{type: :symbol, value: true} ->
                Reduce.reduce(true_ast).(state2)
              %Token{type: :symbol, value: false} ->
                Reduce.reduce(false_ast).(state2)
              %Token{type: :symbol, value: nil} ->
                Reduce.reduce(false_ast).(state2)
              %Token{} ->
                throw err_type(:boolean, result.type, result)
              x -> throw err_type(:boolean, :unknown, x)
            end
          end
        [condition, true_ast] ->
          fn state ->
            {result, state2} = Reduce.reduce(condition).(state)
            case result do
              %Token{type: :symbol, value: true} ->
                Reduce.reduce(true_ast).(state2)
              %Token{type: :symbol, value: false} ->
                {symbol(nil), state2}
              %Token{type: :symbol, value: nil} ->
                {symbol(nil), state2}
              %Token{} ->
                throw err_type(:boolean, result.type, result)
              x -> throw err_type(:boolean, :unknown, x)
            end
          end
        _ -> throw err_arity(3, length(ast))
      end
    end, @origin)
  end
  defp set_fun do
    macro(fn ast ->
      case ast do
        [sy, val] ->
          fn state ->
            {sy_ref, state2} = Reduce.reduce(sy).(state)
            case sy_ref do
              %Token{type: :symbol} ->
                {sy_val, state3} = Reduce.reduce(val).(state2)
                state4 = Mutable.set(state3, sy_ref.value, sy_val)
                {sy_val, state4}
              _ -> throw err_type(:symbol, sy_ref.type, sy_ref)
            end
          end
        _ -> throw err_arity(2, length(ast))
      end
    end, @origin)
  end
  defp let_fun do
    macro(fn ast ->
      case ast do
        [bindings, body] ->
          case bindings do
            %Token{type: :list} ->
              fn state ->
                {vals, state} = set_all(bindings.value, %{}).(state)
                pre_env = Mutable.reference(state)
                state = Mutable.push(state, vals)
                {body_result, state} = Reduce.reduce(body).(state)
                state = Mutable.reset(state, pre_env)
                {body_result, state}
              end
            _ -> throw err_type(:list, bindings.type, bindings)
          end
        _ -> throw err_arity(2, length(ast))
      end
    end, @origin)
  end
  defp lambda_fun do
    macro(fn ast ->
      case ast do
        [bindings, body] ->
          case bindings do
            %Token{type: :list} -> nil
            _ -> throw err_type(:list, bindings.type, bindings)
          end
          fn state ->
            fun = function(fn args ->
              fn fun_state ->
                {bound, fun_state2} = Enum.map_reduce(
                  bindings.value,
                  fun_state,
                  fn binding, st ->
                    case binding do
                      %Token{type: :list} -> Reduce.reduce(binding).(st)
                      %Token{type: :symbol} -> {binding, st}
                      _ -> throw err_type(:list, bindings.type, bindings)
                    end
                  end)
                Enum.each(bound, fn binding ->
                  case binding do
                    %Token{type: :symbol} -> nil
                    _ -> throw err_type(:symbol, binding.type, binding)
                  end
                end)
                matched = zip_bias_left(bound, args)
                {vals, fun_state3} = Enum.reduce(
                  matched,
                  {%{}, fun_state2},
                  fn {k, v}, {vs, st} ->
                    {res, post_state} = Reduce.reduce(v).(st)
                    {Map.put(vs, k.value, res), post_state}
                  end)
                # Finally, have the outside say it has placed the environment
                last = fn final_state ->
                  final_state2 = Mutable.push(final_state, vals)
                  Reduce.reduce(body).(final_state2)
                end
                {last, fun_state3}
              end
            end, bindings.origin)
            closure = add_closure(fun, Mutable.reference(state))
            {closure, state}
          end
        _ -> throw err_arity(2, length(ast))
      end
    end, @origin)
  end
  defp def_fun do
    macro(fn ast ->
      case ast do
        [identifier, body] ->
          fn state ->
            {ident_ref, state2} = case identifier do
              %Token{type: :list} ->
                {ident_val, state1_1} = Reduce.reduce(identifier).(state)
                case ident_val do
                  %Token{type: :symbol} -> nil
                  _ -> throw err_type(:symbol, ident_val.type, ident_val)
                end
                {ident_val, state1_1}
              %Token{type: :symbol} -> {identifier, state}
              _ -> throw err_type(:symbol, identifier, identifier)
            end
            {body_val, state3} = Reduce.reduce(body).(state2)
            state4 = Mutable.set(state3, value_of(ident_ref), body_val)
            {body_val, state4}
          end
        _ -> throw err_arity(2, length(ast))
      end
    end, @origin)
  end
  defp dict_fun_consumer([], dict, state), do: {dict, state}
  defp dict_fun_consumer([_], _, _) do
    throw err_arity(2, 1)
  end
  defp dict_fun_consumer([k, v | rest], dict, state) do
    {k_value, next_state} = Reduce.reduce(k).(state)
    {v_value, next_state} = Reduce.reduce(v).(next_state)
    dict_fun_consumer(rest, Map.put(dict, k_value, v_value), next_state)
  end
  defp dict_fun do
    macro(fn ast ->
      len = length(ast)
      expected = (Integer.floor_div(len, 2)) * 2
      if len != expected do
        throw err_arity(expected, length(ast))
      end
      fn state ->
        dict_fun_consumer(ast, %{}, state)
      end
    end, @origin)
  end

  defp apply_fun do
    macro(fn ast ->
      case ast do
        [identifier, args] ->
          fn state ->
            {arg_list, state2} = Reduce.reduce(args).(state)
            case arg_list do
              %Token{type: :list} -> nil
              _ -> throw err_type(:list, arg_list.type, arg_list)
            end
            Reduce.reduce(list([identifier | arg_list.value])).(state2)
          end

        _ -> throw err_arity(2, length(ast))
      end
    end, @origin)
  end

  # Helpers

  defp lastReduce([]) do
    fn state ->
      {nil, state}
    end
  end
  defp lastReduce([head]) do
    Reduce.reduce(head)
  end
  defp lastReduce([head | rest]) do
    fn state ->
      {_, state2} = Reduce.reduce(head).(state)
      lastReduce(rest).(state2)
    end
  end

  defp set_all([], val) do
    fn state ->
      {val, state}
    end
  end
  defp set_all([_], _), do: throw err_arity(2, 1)
  defp set_all([k, v | rest], val) do
    fn state ->
      {k_ref, state2} = get_key(k).(state)
      {v_val, state3} = Reduce.reduce(v).(state2)
      next_val = Map.put(val, k_ref.value, v_val)
      set_all(rest, next_val).(state3)
    end
  end

  defp get_key(k) do
    case k do
      %Token{type: :symbol} ->
        fn state ->
          {k, state}
        end
      _ ->
        fn state ->
          {k_val, state2} = Reduce.reduce(k).(state)
          case k_val do
            %Token{type: :symbol} -> {k_val, state2}
            _ -> throw err_type(:symbol, k_val.type, k_val)
          end
        end
    end
  end

  defp zip_bias_left([], _), do: []
  defp zip_bias_left([head | rest], []) do
    [{head, nil} | zip_bias_left(rest, [])]
  end
  defp zip_bias_left([headk | restk], [headv | restv]) do
    [{headk, headv} | zip_bias_left(restk, restv)]
  end

  # Errors
  @doc "Prepares an arity error"
  @spec err_arity(integer, integer) :: tuple
  def err_arity(expected, actual) do
    {:arity_mismatch, expected, actual}
  end
  @doc "Prepares a type error"
  @spec err_type(:same, atom, atom) ::tuple
  def err_type(:same, ref_ty, t) do
    {:type_mismatch, :same, ref_ty, t}
  end
  @spec err_type(atom, atom, Token.t) :: tuple
  def err_type(ref_ty, t, val) do
    {:type_mismatch, ref_ty, t, val}
  end
  @doc "Prepares a type error"
  @spec err_type(atom, atom) :: tuple
  def err_type(ref_ty, t) do
    {:type_mismatch, ref_ty, t}
  end

  @doc "Prepares an atom not found error"
  @spec err_no_atom(Token.t) :: tuple
  def err_no_atom(atom_ref) do
    {:no_atom_found, atom_ref}
  end
end
