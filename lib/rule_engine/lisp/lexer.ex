defmodule RuleEngine.LISP.Lexer do
  import RuleEngine.LISP.LexerHelper
  import RuleEngine.Types

  def lexer(input) do
    lexer(input, mko(:user, 1, 0))
  end
  def lexer("", origin) do
    [{:end_of_file, origin}]
  end
  def lexer(<<"(", rest :: binary>>, origin) do
    token = {:left_paren, origin}
    [token | lexer(rest, %{origin | column: origin.column + 1})]
  end
  def lexer(<<")", rest :: binary>>, origin) do
    token = {:right_paren, origin}
    [token | lexer(rest, %{origin | column: origin.column + 1})]
  end
  def lexer(<<"%{", rest :: binary>>, origin) do
    token = {:left_dict, origin}
    [token | lexer(rest, %{origin | column: origin.column + 1})]
  end
  def lexer(<<"}", rest :: binary>>, origin) do
    token = {:right_dict, origin}
    [token | lexer(rest, %{origin | column: origin.column + 1})]
  end
  def lexer(<<"'", rest :: binary>>, origin) do
    token = {:quote, origin}
    [token | lexer(rest, %{origin | column: origin.column + 1})]
  end
  def lexer(<<",", rest :: binary>>, origin) do
    token = {:comma, origin}
    [token | lexer(rest, %{origin | column: origin.column + 1})]
  end
  def lexer(<<"\"", rest :: binary>>, origin) do
    next_origin = %{origin | column: origin.column + 1}
    lexer_string(rest, origin, next_origin, <<>>)
  end
  def lexer(<<";", rest :: binary>>, origin) do
    next_origin = %{origin | column: origin.column + 1}
    lexer_comment(rest, next_origin, <<>>)
  end
  def lexer(input, origin) do
    first = String.first(input)
    case first do
      x when is_whitespace(x) -> lexer_whitespace(input, origin)
      x when is_digit(x) -> lexer_number(input, origin)
      _ -> lexer_symbol(input, origin)
    end
  end
  def lexer_string(<<"\\\"", rest :: binary>>, first_origin, origin, content) do
    next_origin = %{origin | column: origin.column + 2}
    lexer_string(rest, first_origin, next_origin, content <> "\"")
  end
  def lexer_string(<<"\"", rest :: binary>>, first_origin, origin, content) do
    next_origin = %{origin | column: origin.column + 1}
    token = {{:string, content}, first_origin}
    [token | lexer(rest, next_origin)]
  end
  def lexer_string("", _, origin, _) do
    unexpected = {:error, "Expected \", but got end of file", origin}
    [unexpected]
  end
  def lexer_string(input, first_origin, origin, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_origin = %{origin | column: origin.column + 1}
    lexer_string(rest, first_origin, next_origin, content <> first)
  end
  def lexer_comment(<<"\r\n", rest :: binary>>, origin, content) do
    next_origin = %{origin | line: origin.line + 1, column: 0}
    token = {{:comment, content}, origin}
    [token | lexer(rest, next_origin)]
  end
  def lexer_comment(<<"\n", rest :: binary>>, origin, content) do
    next_origin = %{origin | line: origin.line + 1, column: 0}
    token = {{:comment, content}, origin}
    [token | lexer(rest, next_origin)]
  end
  def lexer_comment("", origin, content) do
    token = {{:comment, content}, origin}
    next_origin = %{origin | column: origin.column + 1}
    eof = {:end_of_file, next_origin}
    [token, eof]
  end
  def lexer_comment(input, origin, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_origin = %{origin | column: origin.column + 1}
    lexer_comment(rest, next_origin, content <> first)
  end
  def lexer_number(input, origin) do
    lexer_integer(input, origin, origin, "")
  end
  def lexer_integer(<<".">>, first_origin, origin, content) do
    {num, ""} = Float.parse(content)
    token = {{:number, num}, first_origin}
    next_origin = %{origin | column: origin.column + 1}
    eof = {:end_of_file, next_origin}
    [token, eof]
  end
  def lexer_integer(<<".", rest :: binary>>, first_origin, origin, content) do
    first = String.first(rest)
    next_origin = %{origin | column: origin.column + 1}
    if is_digit(first) do
      lexer_float(rest, first_origin, next_origin, content <> ".")
    else
      {num, ""} = Float.parse(content)
      token = {{:number, num}, first_origin}
      if is_whitespace(first) or is_safe_terminal(first) do
        [token | lexer(rest, origin)]
      else
        next_origin = %{origin | column: origin.column + 1}
        unexpected = {:error, "Expected whitespace or end of file after number, but got #{String.slice(rest, 0, 5)}...", next_origin}
        [token, unexpected]
      end
    end
  end
  def lexer_integer(input, first_origin, origin, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_origin = %{origin | column: origin.column + 1}
    next_content = content <> first
    case rest do
      "" ->
        {num, ""} = Integer.parse(next_content)
        token = {{:number, num}, first_origin}
        next_origin = %{origin | column: origin.column + 1}
        eof = {:end_of_file, next_origin}
        [token, eof]
      _ ->
        first_of_rest = String.first(rest)
        if is_digit(String.first(rest)) or first_of_rest == "." do
          lexer_integer(rest, first_origin, next_origin, next_content)
        else
          {num, ""} = Integer.parse(next_content)
          token = {{:number, num}, first_origin}
          if is_whitespace(first_of_rest) or is_safe_terminal(first_of_rest) do
            [token | lexer(rest, origin)]
          else
            next_origin = %{origin | column: origin.column + 1}
            unexpected = {:error, "Expected whitespace or end of file or right parenthesis or right dict or comment after number, but got #{String.slice(rest, 0, 5)}...", next_origin}
            [token, unexpected]
          end
        end
    end
  end
  def lexer_float(input, first_origin, origin, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_origin = %{origin | column: origin.column + 1}
    next_content = content <> first
    case rest do
      "" ->
        {num, ""} = Float.parse(next_content)
        token = {{:number, num}, first_origin}
        eof = {:end_of_file, next_origin}
        [token, eof]

      _ ->
        first_of_rest = String.first(rest)
        if is_digit(first_of_rest) do
          lexer_float(rest, first_origin, next_origin, next_content)
        else
          {num, ""} = Float.parse(next_content)
          token = {{:number, num}, first_origin}
          [token | lexer(rest, next_origin)]
        end
    end
  end
  def lexer_symbol(input, origin) do
    lexer_symbol(input, origin, origin, "")
  end
  def lexer_symbol(input, first_origin, origin, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_origin = %{origin | column: origin.column + 1}
    next_content = content <> first
    case rest do
      "" ->
        token = {{:symbol, next_content}, first_origin}
        eof = {:end_of_file, next_origin}
        [token, eof]
      _ ->
        first_of_rest = String.first(rest)
        case first_of_rest do
          x when x == ";" or x == ")" or x == "}" or x == "," or is_whitespace(x) ->
            token = {{:symbol, next_content}, first_origin}
            [token | lexer(rest, next_origin)]
          "'" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a quote in the middle. Quotes should only go before keywords, not in between.", origin}
            [unexpected]
          "\"" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a double quote in the middle. Strings should be spaced away from keywords.", origin}
            [unexpected]
          "(" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a \"(\" in the middle. Parenthesis should be spaced away from keywords.", origin}
            [unexpected]
          "%" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a \"%\" in the middle. Dicts should be spaced away from keywords.", origin}
            [unexpected]
          "{" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a \"{\" in the middle. Dicts should be spaced away from keywords. This is also a malformed dict, as dicts should start with %{", origin}
            [unexpected]
          _ -> lexer_symbol(rest, origin, next_origin, next_content)
        end
    end
  end

  def lexer_whitespace(input, origin) do
    lexer_whitespace(input, origin, origin)
  end

  def lexer_whitespace(input, first_origin, origin) do
    token = {:whitespace, first_origin}
    {rest, line, column} = case input do
      <<"\r\n", rest::binary>> -> {rest, origin.line + 1, 0}
      <<"\n", rest::binary>> -> {rest, origin.line + 1, 0}
      _ -> {String.slice(input, 1..-1), origin.line, origin.column + 1}
    end
    next_origin = %{origin | line: line, column: column}
    case rest do
      "" ->
        next_origin = %{next_origin | column: origin.column + 1}
        eof = {:end_of_file, next_origin}
        [token, eof]
      _ ->
        if is_whitespace(String.first(rest)) do
          lexer_whitespace(rest, first_origin, next_origin)
        else
          [token | lexer(rest, next_origin)]
        end
    end
  end
end
