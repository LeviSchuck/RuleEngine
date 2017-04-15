defmodule RuleEngine.Bootstrap do
  alias RuleEngine.Mutable
  alias RuleEngine.Reduce
  import RuleEngine.Types
  alias RuleEngine.Types.Token

  def bootstrap_environment do
    %{
      outer: nil,
      vals: %{
        # Comparators
        "==" => mkfun(fn x, y -> x == y end, [:any, :any]),
        "!=" => mkfun(fn x, y -> x != y end, [:any, :any]),
        "<" => mkfun(fn x, y -> x < y end, [:any, :any]),
        ">" => mkfun(fn x, y -> x > y end, [:any, :any]),
        "<=" => mkfun(fn x, y -> x <= y end, [:any, :any]),
        ">=" => mkfun(fn x, y -> x >= y end, [:any, :any]),
        # Combinatoral
        "&&" => mkfun(fn x, y -> x && y end, [:boolean, :boolean]),
        "||" => mkfun(fn x, y -> x || y end, [:boolean, :boolean]),
        "++" => mkfun(fn x, y -> x <> y end, [:string, :string]),
        # Folding Combinatoral operations
        "+" => plus_fun(),
        "-" => minus_fun(),
        "and" => and_fun(),
        "or" => or_fun(),
        # Iteration
        "map" => map_fun(),
        "reduce" => reduce_fun(),
        # Types
        "nil?" => simple_fun(&nil?/1),
        "boolean?" => simple_fun(&boolean?/1),
        "symbol?" => simple_fun(&symbol?/1),
        "list?" => simple_fun(&list?/1),
        "dict?" => simple_fun(&dict?/1),
        "string?" => simple_fun(&string?/1),
        "number?" => simple_fun(&number?/1),
        "function?" => simple_fun(&function?/1),
        "macro?" => simple_fun(&macro?/1),
        "atom?" => simple_fun(&atom?/1),
        # Macros
        "do" => do_fun(),
        "quote" => quote_fun(),
        "if" => if_fun(),
        "let" => let_fun(),
        "fn" => lambda_fun(),
        "def" => def_fun(),
        "apply" => apply_fun(),
        # Built in symbols
        "true" => symbol(true),
        true => symbol(true),
        "false" => symbol(false),
        false => symbol(false),
        "nil" => symbol(nil),
        nil => symbol(nil),
        # Atom ops
        "atom" => state_fun(&make_atom/1, [:any]),
        "deref" => state_fun(&deref_atom/1, [:atom]),
        "reset!" => state_fun(&reset_atom/2, [:atom, :any]),
        # "swap!" => mkfun(???, [:atom, :function])
        "set!" => set_fun(),
      },
      id: 0
    }
  end

  def bootstrap_mutable do
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
      |> dict()
  end
  def convert(res) when is_list(res) do
    Enum.map(res, &convert/1)
      |> list()
  end
  def convert(res) when is_function(res), do: function(res)
  def convert(res), do: hack(res)

  def simple_fun(fun) do
    lambda = fn args ->
      largs = length(args)
      case args do
        [arg] ->
          fun.(arg)
            |> convert()
        _ -> throw err_arity(1, largs)
      end
    end
    wrap_state(lambda)
  end

  def simple_macro(fun) do
    macro(fn args ->
      fun.(args)
    end)
  end
  def mk_core_fun(fun, types, conversion) do
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
                    true -> {:halt, {:error, err_type(other, t)}}
                  end
              end
            end)
          case type_check do
            {_, :ok} ->
              case conversion do
                :convert -> exec_fun(fun, args)
                :naked -> apply(fun, args)
              end
            {:error, err} -> throw err
          end
        true -> throw err_arity(ltypes, largs)
      end
    end
  end
  def mkfun(fun, types) do
    lambda = mk_core_fun(fun, types, :convert)
    wrap_state(lambda)
  end
  def state_fun(fun, types) do
    lambda = mk_core_fun(fun, types, :naked)
    function(lambda)
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
      fn state ->
        {lambda.(args), state}
      end
    end)
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
  defp plus_fun do
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

  defp and_fun do
    simple_macro(fn ast ->
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
        {symbol(res), state_final}
      end
    end)
  end

  defp or_fun do
    simple_macro(fn ast ->
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
        {symbol(res), state_final}
      end
    end)
  end

  def map_fun do
    simple_macro(fn ast ->
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
    end)
  end
  defp map_fun_list(fun_ref, col_ref, state) do
    {res, state2} = Enum.map_reduce(col_ref.value, state, fn col, s ->
      {val, s2} = Reduce.reduce(list([fun_ref, col])).(s)
      {val, s2}
    end)
    res_list = res
      |> list()
    {res_list, state2}
  end
  defp map_fun_dict(fun_ref, col_ref, state) do
    {res, state2} = Enum.map_reduce(col_ref.value, state, fn {k_col, v_col}, s ->
      {val, s2} = Reduce.reduce(list([fun_ref, k_col, v_col])).(s)
      {{k_col, val}, s2}
    end)
    as_dict = Enum.into(res, %{})
      |> dict()
    {as_dict, state2}
  end

  def reduce_fun do
    simple_macro(fn ast ->
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
              %Token{type: :list} -> reduce_fun_list(fun_ref, col_ref, acc, state3)
              %Token{type: :dict} -> reduce_fun_dict(fun_ref, col_ref, acc, state3)
              _ -> throw err_type([:list, :dict], col_ref.type, col_ref)
            end
          end
      end
    end)
  end

  defp reduce_fun_list(fun_ref, col_ref, acc, state) do
    {res, state2} = Enum.reduce(col_ref.value, {acc, state}, fn col, {a, s} ->
      {next_a, s2} = Reduce.reduce(list([fun_ref, col, a])).(s)
      {next_a, s2}
    end)
    {res, state2}
  end
  defp reduce_fun_dict(fun_ref, col_ref, acc, state) do
    {res, state2} = Enum.reduce(col_ref.value, {acc, state}, fn {k_col, v_col}, {a, s} ->
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
  def do_fun do
    simple_macro(fn ast ->
      lastReduce(ast)
    end)
  end
  def quote_fun do
    simple_macro(fn ast ->
      case ast do
        [single] ->
          fn state ->
            {single, state}
          end
        _ -> throw err_arity(1, length(ast))
      end
    end)
  end
  def if_fun do
    simple_macro(fn ast ->
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
        _ -> throw err_arity(3, length(ast))
      end
    end)
  end
  def set_fun do
    simple_macro(fn ast ->
      case ast do
        [sy, val] ->
          fn state ->
            {sy_ref, state2} = Reduce.reduce(sy).(state)
            case sy_ref do
              %Token{type: :symbol} ->
                {sy_val, state3} = Reduce.reduce(val).(state2)
                state4 = Mutable.env_set(state3, sy_ref.value, sy_val)
                {sy_val, state4}
              _ -> throw err_type(:symbol, sy_ref.type, sy_ref)
            end
          end
        _ -> throw err_arity(2, length(ast))
      end
    end)
  end
  def let_fun do
    simple_macro(fn ast ->
      case ast do
        [bindings, body] ->
          case bindings do
            %Token{type: :list} ->
              fn state ->
                {vals, state2} = set_all(bindings.value, %{}).(state)
                pre_env = Mutable.env_ref(state2)
                state3 = Mutable.env_new(state2, vals)
                {body_result, state4} = Reduce.reduce(body).(state3)
                state5 = Mutable.env_override(state4, pre_env)
                {body_result, state5}
              end
            _ -> throw err_type(:list, bindings.type, bindings)
          end
        _ -> throw err_arity(2, length(ast))
      end
    end)
  end
  def lambda_fun do
    simple_macro(fn ast ->
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
                  final_state2 = Mutable.env_new(final_state, vals)
                  Reduce.reduce(body).(final_state2)
                end
                {last, fun_state3}
              end
            end)
            closure = add_closure(fun, Mutable.env_ref(state))
            {closure, state}
          end
        _ -> throw err_arity(2, length(ast))
      end
    end)
  end
  def def_fun do
    simple_macro(fn ast ->
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
            state4 = Mutable.env_set(state3, ident_ref.value, body_val)
            {body_val, state4}
          end
        _ -> throw err_arity(2, length(ast))
      end
    end)
  end

  def apply_fun do
    simple_macro(fn ast ->
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
    end)
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

  def zip_bias_left([], _), do: []
  def zip_bias_left([head | rest], []) do
    [{head, nil} | zip_bias_left(rest, [])]
  end
  def zip_bias_left([headk | restk], [headv | restv]) do
    [{headk, headv} | zip_bias_left(restk, restv)]
  end

  # Errors
  def err_arity(expected, actual) do
    {:arity_mismatch, expected, actual}
  end
  def err_type(:same, ref_ty, t) do
    {:type_mismatch, :same, ref_ty, t}
  end
  def err_type(ref_ty, t, val) do
    {:type_mismatch, ref_ty, t, val}
  end
  def err_type(ref_ty, t) do
    {:type_mismatch, ref_ty, t}
  end
  def err_no_atom(atom_ref) do
    {:no_atom_found, atom_ref}
  end
end
