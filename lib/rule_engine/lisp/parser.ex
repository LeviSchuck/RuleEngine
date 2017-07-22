defmodule RuleEngine.LISP.Parser do
  alias RuleEngine.LISP.Lexer
  alias RuleEngine.Types

  require Logger

  defp parse_dead_content([{:whitespace, _} | rest]), do: parse_dead_content(rest)
  defp parse_dead_content([{{:comment, _}, _} | rest]), do: parse_dead_content(rest)
  defp parse_dead_content(lexed), do: lexed

  defp parse_optional_comma([]), do: []
  defp parse_optional_comma([first | _ ] = lexed) do
    case parse_dead_content(lexed) do
      [] -> []
      [{:error, _, _}] = error -> error
      [{:end_of_file, _}] = eof -> eof
      [{:right_paren, _} | _] = rest -> rest
      [{:right_dict, _} | _] = rest -> rest
      [{:comma, _} | rest] -> parse_dead_content(rest)
      [^first | _] ->
        {_, o} = first
        [{:error, "Expected some space or a comma or end of list or end of dict", o}]
      post_dead -> post_dead
    end
  end

  defp parse_optional_symbol(_, []), do: []
  defp parse_optional_symbol(sy, [first | _ ] = lexed) do
    case parse_dead_content(lexed) do
      [] -> []
      [{:error, _, _}] = error -> error
      [{:end_of_file, _}] = eof -> eof
      [{:right_paren, _} | _] = rest -> rest
      [{:right_dict, _} | _] = rest -> rest
      [{{:symbol, ^sy}, _} | rest] -> parse_dead_content(rest)
      [^first | _] ->
        {_, o} = first
        [{:error, "Expected some space or the symbol #{sy} or end of list or end of dict", o}]
      post_dead -> post_dead
    end
  end

  defp parse_list([], _), do: {:nothing}
  defp parse_list([{:end_of_file, o}], _), do: {:error, "Expected right parenthesis, but got end of file", o}
  defp parse_list([{:error, _, _}] = error, _), do: error
  defp parse_list([{_, o} | _] = lexed, origin) do
    case parse_dead_content(lexed) do
      [] -> {:error, "Expected values for list or end of list", o}
      [{:end_of_file, _, _}] -> {:error, "Expected values for list or end of list", o}
      [{:right_paren, _, _} | rest] -> {:value, Types.list([], origin), rest}
      [{:error, m, o}] -> {:error, m, o}
      rest ->
        result = parse_list_chain(rest)
        case result do
          {:nothing} -> {:error, "Expected values for list or end of list", origin}
          {:error, _, _} = error -> error
          {:value, value, remaining} -> {:value, Types.list(value, origin), remaining}
        end
    end
  end

  defp parse_list_chain([]), do: {:nothing}
  defp parse_list_chain([{:end_of_file, o}]), do: {:error, "Expected right parenthesis, but got end of file", o}
  defp parse_list_chain([{:right_paren, _} | rest]), do: {:value, [], rest}
  defp parse_list_chain(lexed) do
    case parse_value(parse_dead_content(lexed)) do
      {:nothing} -> {:nothing}
      {:error, _, _} = error -> error
      {:value, value, remaining} ->
        case parse_list_chain(parse_optional_comma(remaining)) do
          {:nothing} ->
            o = case remaining do
              [{:error, _, o}] -> o
              [{_, o} | _] -> o
              [] -> Types.mko(:parser)
            end
            {:error, "Expected right parenthesis, but got end of file", o}
          {:error, _, _} = error -> error
          {:value, result, remaining} -> {:value, [value | result], remaining}
        end
    end
  end


  defp parse_dict([], _), do: {:nothing}
  defp parse_dict([{:end_of_file, o}], _), do: {:error, "Expected end map }, but got end of file", o}
  defp parse_dict([{:error, _, _}] = error, _), do: error
  defp parse_dict([{_, o} | _] = lexed, origin) do
    case parse_dead_content(lexed) do
      [] -> {:error, "Expected values for dict or end of dict", o}
      [{:end_of_file, _}] -> {:error, "Expected values for dict or end of dict", o}
      [{:right_dict, _} | rest] -> {:value, Types.dict(%{}, origin), rest}
      [{:error, m, o}] -> {:error, m, o}
      rest ->
        result = parse_dict_chain(rest)
        case result do
          {:nothing} -> {:error, "Expected values for dict or end of dict", o}
          {:error, _, _} = error -> error
          {:value, value, remaining} ->
            constructor = Types.list([Types.symbol("make-dict", Types.mko(:parser)) | value], origin)
            {:value, constructor, remaining}
        end
    end
  end

  defp parse_dict_chain([]), do: {:nothing}
  defp parse_dict_chain([{:end_of_file, o}]), do: {:error, "Expected end of map }, but got end of file", o}
  defp parse_dict_chain([{:right_dict, _} | rest]), do: {:value, [], rest}
  defp parse_dict_chain(lexed) do
    case parse_dict_pair(parse_dead_content(lexed)) do
      {:nothing} -> {:nothing}
      {:error, _, _} = error -> error
      {:value, {value1, value2}, remaining} ->
        case parse_dict_chain(parse_optional_comma(remaining)) do
          {:nothing} ->
            o = case remaining do
              [{:error, _, o}] -> o
              [{_, o} | _] -> o
              [] -> Types.mko(:parser)
            end
            {:error, "Expected end of map }, but got end of file", o}
          {:error, _, _} = error -> error
          {:value, result, remaining} -> {:value, [value1, value2 | result], remaining}
        end
    end
  end

  defp parse_dict_pair([]), do: {:error, "Expected a pair of values, but found nothing", Types.mko(:parser)}
  defp parse_dict_pair([{:end_of_file, o}]), do: {:error, "Expected pair of values, but got end of file", o}
  defp parse_dict_pair([{:error, _, _} = error]), do: error
  defp parse_dict_pair([{_, o} | _] = lexed) do
    illegal = Types.symbol("=>")
    case parse_value(parse_dead_content(lexed)) do
      {:nothing} -> {:error, "Expected a pair of values, but could not parse a value", o}
      {:error, _, _} = error -> error
      {:value, ^illegal, _} -> {:error, "Expected a value for a dict pair, but got =>", o}
      {:value, v1, remaining} ->
        case parse_optional_symbol("=>", remaining) do
          [] -> {:error, "Expected a second value for dict entry", o}
          [{:end_of_file, _}] -> {:error, "Expected a second value for dict entry, but got end of file", o}
          [{:right_dict, _} | _] -> {:error, "Expected a second value for dict entry, but got end of dict.", o}
          [{:error, m, o}] -> {:error, m, o}
          [{_, o} | _] = remaining ->
            case parse_value(remaining) do
              {:nothing} -> {:error, "Expected a pair of values, but could not parse a value", o}
              {:error, _, _} = error -> error
              {:value, ^illegal, _} -> {:error, "Expected a value for a dict pair, but got =>", o}
              {:value, v2, remaining} -> {:value, {v1, v2}, remaining}
            end
        end
    end
  end

  def parse_value([]), do: {:nothing}
  def parse_value([{:end_of_file, _}]), do: {:nothing}
  def parse_value([{:error, m, o}]), do: {:error, m, o}
  def parse_value([{:right_paren, o} | _]), do: {:error, "Expected to find a value, but found a right parenthesis", o}
  def parse_value([{:right_map, o} | _]), do: {:error, "Expected to find a value, but found end of dict", o}
  def parse_value([{:comma, o} | _]), do: {:error, "Expected to find a value, but found a comma", o}
  def parse_value([{:quote, o} | rest]) do
    next_origin = %{o | column: o.column + 1}
    case rest do
      [] -> {:error, "Expected to quote a value, but could not parse a value after quote", next_origin}
      [{:error, m, o}] -> {:error, m, o}
      [{:end_of_file, o}] -> {:error, "Expected to quote a value immediate, but got end of file", o}
      [{:whitespace, o} | _] -> {:error, "Expected to quote a value immediately, but got whitespace", o}
      [{:comment, o} | _] -> {:error, "Expected to quote a value immediately, but got a comment", o}
      [{:right_paren, o} | _] -> {:error, "Expected to quote a value immediately, but got a right parenthesis", o}
      [{:right_dict, o} | _] -> {:error, "Expected to quote a value immediately, but got end of dict",o}
      [{:comma, o} | _] -> {:error, "Expected to quote a value immediately, but got end of dict", o}
      _ -> case parse_value(rest) do
        {:value, val, remaining} -> {:value, Types.list([Types.symbol("quote"), val]), remaining}
        {:nothing} -> {:error, "Expected to quote a value, but could not parse a value after quote", next_origin}
        {:error, _, _} = error -> error
      end
    end
  end
  def parse_value([{{:comment, _}, _} | rest]) do
    parse_value(rest)
  end
  def parse_value([{:whitespace, _} | rest]) do
    parse_value(rest)
  end
  def parse_value([{{:string, text}, o} | rest]) do
    {:value, Types.string(text, o), rest}
  end
  def parse_value([{{:symbol, name}, o} | rest]) do
    {:value, Types.symbol(name, o), rest}
  end
  def parse_value([{{:number, num}, o} | rest]) do
    {:value, Types.number(num, o), rest}
  end
  def parse_value([{:left_paren, o} | rest]) do
    parse_list(rest, o)
  end
  def parse_value([{:left_dict, o} | rest]) do
    parse_dict(rest, o)
  end


  defp parse_document([]), do: {:error, "Expected to parse a document, but got nothing", Types.mko(:parser)}
  defp parse_document(lexed) do
    result = parse_document_chain(lexed)
    case List.last(result) do
      nil -> {:error, "Expected to parse a document, but failed to parse", Types.mko(:parser)}
      {:error, m, o} -> {:error, m, o}
      {:nothing} -> {:error, "Expected to parse a document, but the last thing to parse", Types.mko(:parser)}
      _ -> Types.list([Types.symbol("do") | result])
    end
  end
  defp parse_document_chain([]), do: []
  defp parse_document_chain([{:end_of_file, _, _}]), do: []
  defp parse_document_chain(lexed) do
    case parse_value(parse_dead_content(lexed)) do
      {:value, value, remaining} ->
        [value | parse_document_chain(remaining)]
      {:nothing} -> []
      {:error, m, o} -> [{:error, m, o}]
    end
  end

  def parse_exec_root(input, source) do
    lexed = Lexer.lexer(input, Types.mko(source, 1, 0))
    case parse_value(parse_dead_content(lexed)) do
      {:nothing} -> {:error, "Tried to parse a value, but could not find a value anything", Types.mko(:parser)}
      {:error, _, _} = error -> error
      {:value, value, remaining} ->
        case parse_dead_content(remaining) do
          [] -> {:ok, value}
          [{:error, _, _} = error] -> error
          [{:end_of_file, _}] -> {:ok, value}
          [{_, o} | _] -> {:error, "Parsed a value, but there was stuff after it", o}
          _ -> {:error, "Parsed a value, but there was stuff after it", Types.mko(:parser)}
        end
    end
  end

  def parse_exec_document(input, source) do
    lexed = Lexer.lexer(input, Types.mko(source, 1, 0))
    case parse_document(lexed) do
      {:error, _, _} = error -> error
      res -> {:ok, res}
    end
  end
end
