defmodule RuleEngine.LISP.Parser do
  alias RuleEngine.LISP.Lexer
  alias RuleEngine.Types

  require Logger

  defp parse_dead_content([{:whitespace, _, _} | rest]), do: parse_dead_content(rest)
  defp parse_dead_content([{{:comment, _}, _, _} | rest]), do: parse_dead_content(rest)
  defp parse_dead_content(lexed), do: lexed

  defp parse_optional_comma([]), do: []
  defp parse_optional_comma([first | _ ] = lexed) do
    case parse_dead_content(lexed) do
      [] -> []
      [{:error, _, _, _}] = error -> error
      [{:end_of_file, _, _}] = eof -> eof
      [{:right_paren, _, _} | _] = rest -> rest
      [{:right_dict, _, _} | _] = rest -> rest
      [{:comma, _, _} | rest] -> parse_dead_content(rest)
      [^first | _] ->
        {_, l, c} = first
        [{:error, "Expected some space or a comma or end of list or end of dict", l, c}]
      post_dead -> post_dead
    end
  end

  defp parse_optional_symbol(_, []), do: []
  defp parse_optional_symbol(sy, [first | _ ] = lexed) do
    case parse_dead_content(lexed) do
      [] -> []
      [{:error, _, _, _}] = error -> error
      [{:end_of_file, _, _}] = eof -> eof
      [{:right_paren, _, _} | _] = rest -> rest
      [{:right_dict, _, _} | _] = rest -> rest
      [{{:symbol, ^sy}, _, _} | rest] -> parse_dead_content(rest)
      [^first | _] ->
        {_, l, c} = first
        [{:error, "Expected some space or the symbol #{sy} or end of list or end of dict", l, c}]
      post_dead -> post_dead
    end
  end

  defp parse_list([]), do: {:nothing}
  defp parse_list([{:end_of_file, l, c}]), do: {:error, "Expected right parenthesis, but got end of file", l, c}
  defp parse_list([{:error, _, _, _}] = error), do: error
  defp parse_list([{_, l, c} | _] = lexed) do
    case parse_dead_content(lexed) do
      [] -> {:error, "Expected values for list or end of list", l, c}
      [{:end_of_file, _, _}] -> {:error, "Expected values for list or end of list", l, c}
      [{:right_paren, _, _} | rest] -> {:value, Types.list([]), rest}
      [{:error, m, l, c}] -> {:error, m, l, c}
      rest ->
        result = parse_list_chain(rest)
        case result do
          {:nothing} -> {:error, "Expected values for list or end of list", l, c}
          {:error, _, _, _} = error -> error
          {:value, value, remaining} -> {:value, Types.list(value), remaining}
        end
    end
  end

  defp parse_list_chain([]), do: {:nothing}
  defp parse_list_chain([{:end_of_file, l, c}]), do: {:error, "Expected right parenthesis, but got end of file", l, c}
  defp parse_list_chain([{:right_paren, _, _} | rest]), do: {:value, [], rest}
  defp parse_list_chain(lexed) do
    case parse_value(parse_dead_content(lexed)) do
      {:nothing} -> {:nothing}
      {:error, _, _, _} = error -> error
      {:value, value, remaining} ->
        case parse_list_chain(parse_optional_comma(remaining)) do
          {:nothing} ->
            {l, c} = case remaining do
              [{:error, _, l, c}] -> {l, c}
              [{_, l, c} | _] -> {l, c}
              [] -> {1, 0}
            end
            {:error, "Expected right parenthesis, but got end of file", l, c}
          {:error, _, _, _} = error -> error
          {:value, result, remaining} -> {:value, [value | result], remaining}
        end
    end
  end


  defp parse_dict([]), do: {:nothing}
  defp parse_dict([{:end_of_file, l, c}]), do: {:error, "Expected end map }, but got end of file", l, c}
  defp parse_dict([{:error, _, _, _}] = error), do: error
  defp parse_dict([{_, l, c} | _] = lexed) do
    case parse_dead_content(lexed) do
      [] -> {:error, "Expected values for dict or end of dict", l, c}
      [{:end_of_file, _, _}] -> {:error, "Expected values for dict or end of dict", l, c}
      [{:right_dict, _, _} | rest] -> {:value, Types.dict(%{}), rest}
      [{:error, m, l, c}] -> {:error, m, l, c}
      rest ->
        result = parse_dict_chain(rest)
        case result do
          {:nothing} -> {:error, "Expected values for dict or end of dict", l, c}
          {:error, _, _, _} = error -> error
          {:value, value, remaining} ->
            constructor = Types.list([Types.symbol("make-dict") | value])
            {:value, constructor, remaining}
        end
    end
  end

  defp parse_dict_chain([]), do: {:nothing}
  defp parse_dict_chain([{:end_of_file, l, c}]), do: {:error, "Expected end of map }, but got end of file", l, c}
  defp parse_dict_chain([{:right_dict, _, _} | rest]), do: {:value, [], rest}
  defp parse_dict_chain(lexed) do
    case parse_dict_pair(parse_dead_content(lexed)) do
      {:nothing} -> {:nothing}
      {:error, _, _, _} = error -> error
      {:value, {value1, value2}, remaining} ->
        case parse_dict_chain(parse_optional_comma(remaining)) do
          {:nothing} ->
            {l, c} = case remaining do
              [{:error, _, l, c}] -> {l, c}
              [{_, l, c} | _] -> {l, c}
              [] -> {1, 0}
            end
            {:error, "Expected end of map }, but got end of file", l, c}
          {:error, _, _, _} = error -> error
          {:value, result, remaining} -> {:value, [value1, value2 | result], remaining}
        end
    end
  end

  defp parse_dict_pair([]), do: {:error, "Expected a pair of values, but found nothing", 1, 0}
  defp parse_dict_pair([{:end_of_file, l, c}]), do: {:error, "Expected pair of values, but got end of file", l, c}
  defp parse_dict_pair([{:error, _, _, _} = error]), do: error
  defp parse_dict_pair([{_, l, c} | _] = lexed) do
    illegal = Types.symbol("=>")
    case parse_value(parse_dead_content(lexed)) do
      {:nothing} -> {:error, "Expected a pair of values, but could not parse a value", l, c}
      {:error, _, _, _} = error -> error
      {:value, ^illegal, _} -> {:error, "Expected a value for a dict pair, but got =>", l, c}
      {:value, v1, remaining} ->
        case parse_optional_symbol("=>", remaining) do
          [] -> {:error, "Expected a second value for dict entry", l, c}
          [{:end_of_file, _, _}] -> {:error, "Expected a second value for dict entry, but got end of file", l, c}
          [{:right_dict, _, _} | _] -> {:error, "Expected a second value for dict entry, but got end of dict.", l, c}
          [{:error, m, l, c}] -> {:error, m, l, c}
          [{_, l, c} | _] = remaining ->
            case parse_value(remaining) do
              {:nothing} -> {:error, "Expected a pair of values, but could not parse a value", l, c}
              {:error, _, _, _} = error -> error
              {:value, ^illegal, _} -> {:error, "Expected a value for a dict pair, but got =>", l, c}
              {:value, v2, remaining} -> {:value, {v1, v2}, remaining}
            end
        end
    end
  end

  def parse_value([]), do: {:nothing}
  def parse_value([{:end_of_file, _, _}]), do: {:nothing}
  def parse_value([{:error, m, l, c}]), do: {:error, m, l, c}
  def parse_value([{:right_paren, l, c} | _]), do: {:error, "Expected to find a value, but found a right parenthesis", l, c}
  def parse_value([{:right_map, l, c} | _]), do: {:error, "Expected to find a value, but found end of dict", l, c}
  def parse_value([{:comma, l, c} | _]), do: {:error, "Expected to find a value, but found a comma", l, c}
  def parse_value([{:quote, l, c} | rest]) do
    case rest do
      [] -> {:error, "Expected to quote a value, but could not parse a value after quote", l, c + 1}
      [{:error, m, l, c}] -> {:error, m, l, c}
      [{:end_of_file, l, c}] -> {:error, "Expected to quote a value immediate, but got end of file", l, c}
      [{:whitespace, l, c} | _] -> {:error, "Expected to quote a value immediately, but got whitespace", l, c}
      [{:comment, l, c} | _] -> {:error, "Expected to quote a value immediately, but got a comment", l, c}
      [{:right_paren, l, c} | _] -> {:error, "Expected to quote a value immediately, but got a right parenthesis", l, c}
      [{:right_dict, l, c} | _] -> {:error, "Expected to quote a value immediately, but got end of dict", l, c}
      [{:comma, l, c} | _] -> {:error, "Expected to quote a value immediately, but got end of dict", l, c}
      _ -> case parse_value(rest) do
        {:value, val, remaining} -> {:value, Types.list([Types.symbol("quote"), val]), remaining}
        {:nothing} -> {:error, "Expected to quote a value, but could not parse a value after quote", l, c + 1}
        {:error, _, _, _} = error -> error
      end
    end
  end
  def parse_value([{{:comment, _}, _, _} | rest]) do
    parse_value(rest)
  end
  def parse_value([{:whitespace, _, _} | rest]) do
    parse_value(rest)
  end
  def parse_value([{{:string, text}, _, _} | rest]) do
    {:value, Types.string(text), rest}
  end
  def parse_value([{{:symbol, name}, _, _} | rest]) do
    {:value, Types.symbol(name), rest}
  end
  def parse_value([{{:number, num}, _, _} | rest]) do
    {:value, Types.number(num), rest}
  end
  def parse_value([{:left_paren, _, _} | rest]) do
    parse_list(rest)
  end
  def parse_value([{:left_dict, _, _} | rest]) do
    parse_dict(rest)
  end


  defp parse_document([]), do: {:error, "Expected to parse a document, but got nothing", 1, 0}
  defp parse_document(lexed) do
    result = parse_document_chain(lexed)
    case List.last(result) do
      nil -> {:error, "Expected to parse a document, but failed to parse", 1, 0}
      {:error, m, l, c} -> {:error, m, l, c}
      {:nothing} -> {:error, "Expected to parse a document, but the last thing to parse", 1, 0}
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
      {:error, m, l, c} -> [{:error, m, l, c}]
    end
  end

  def parse_exec_root(input) do
    lexed = Lexer.lexer(input)
    case parse_value(parse_dead_content(lexed)) do
      {:nothing} -> {:error, "Tried to parse a value, but could not find a value anything", 1, 0}
      {:error, _, _, _} = error -> error
      {:value, value, remaining} ->
        case parse_dead_content(remaining) do
          [] -> {:ok, value}
          [{:error, _, _, _} = error] -> error
          [{:end_of_file, _, _}] -> {:ok, value}
          [{_, l, c} | _] -> {:error, "Parsed a value, but there was stuff after it", l, c}
          _ -> {:error, "Parsed a value, but there was stuff after it", 1, 0}
        end
    end
  end

  def parse_exec_document(input) do
    lexed = Lexer.lexer(input)
    case parse_document(lexed) do
      {:error, _, _, _} = error -> error
      res -> {:ok, res}
    end
  end
end
