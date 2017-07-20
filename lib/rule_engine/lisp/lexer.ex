defmodule RuleEngine.LISP.Lexer do
  require Logger
  import RuleEngine.LISP.LexerHelper

  def lexer(input) do
    lexer(input, %{column: 0, line: 1})
  end
  def lexer("", state) do
    [{:end_of_file, state.line, state.column}]
  end
  def lexer(<<"(", rest :: binary>>, state) do
    token = {:left_paren, state.line, state.column}
    [token | lexer(rest, %{state | column: state.column + 1})]
  end
  def lexer(<<")", rest :: binary>>, state) do
    token = {:right_paren, state.line, state.column}
    [token | lexer(rest, %{state | column: state.column + 1})]
  end
  def lexer(<<"%{", rest :: binary>>, state) do
    token = {:left_dict, state.line, state.column}
    [token | lexer(rest, %{state | column: state.column + 1})]
  end
  def lexer(<<"}", rest :: binary>>, state) do
    token = {:right_dict, state.line, state.column}
    [token | lexer(rest, %{state | column: state.column + 1})]
  end
  def lexer(<<"'", rest :: binary>>, state) do
    token = {:quote, state.line, state.column}
    [token | lexer(rest, %{state | column: state.column + 1})]
  end
  def lexer(<<",", rest :: binary>>, state) do
    token = {:comma, state.line, state.column}
    [token | lexer(rest, %{state | column: state.column + 1})]
  end
  def lexer(<<"\"", rest :: binary>>, state) do
    next_state = %{state | column: state.column + 1}
    lexer_string(rest, state, next_state, <<>>)
  end
  def lexer(<<";", rest :: binary>>, state) do
    next_state = %{state | column: state.column + 1}
    lexer_comment(rest, next_state, <<>>)
  end
  def lexer(input, state) do
    first = String.first(input)
    case first do
      x when is_whitespace(x) -> lexer_whitespace(input, state)
      x when is_digit(x) -> lexer_number(input, state)
      _ -> lexer_symbol(input, state)
    end
  end
  def lexer_string(<<"\\\"", rest :: binary>>, first_state, state, content) do
    next_state = %{state | column: state.column + 2}
    lexer_string(rest, first_state, next_state, content <> "\"")
  end
  def lexer_string(<<"\"", rest :: binary>>, first_state, state, content) do
    next_state = %{state | column: state.column + 1}
    token = {{:string, content}, first_state.line, first_state.column}
    [token | lexer(rest, next_state)]
  end
  def lexer_string("", _, state, _) do
    unexpected = {:error, "Expected \", but got end of file", state.line, state.column}
    [unexpected]
  end
  def lexer_string(input, first_state, state, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_state = %{state | column: state.column + 1}
    lexer_string(rest, first_state, next_state, content <> first)
  end
  def lexer_comment(<<"\r\n", rest :: binary>>, state, content) do
    next_state = %{state | line: state.line + 1, column: 0}
    token = {{:comment, content}, state.line, state.column}
    [token | lexer(rest, next_state)]
  end
  def lexer_comment(<<"\n", rest :: binary>>, state, content) do
    next_state = %{state | line: state.line + 1, column: 0}
    token = {{:comment, content}, state.line, state.column}
    [token | lexer(rest, next_state)]
  end
  def lexer_comment("", state, content) do
    token = {{:comment, content}, state.line, state.column}
    eof = {:end_of_file, state.line, state.column + 1}
    [token, eof]
  end
  def lexer_comment(input, state, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_state = %{state | column: state.column + 1}
    lexer_comment(rest, next_state, content <> first)
  end
  def lexer_number(input, state) do
    lexer_integer(input, state, state, "")
  end
  def lexer_integer(<<".">>, first_state, state, content) do
    {num, ""} = Float.parse(content)
    token = {{:number, num}, first_state.line, first_state.column}
    eof = {:end_of_file, state.line, state.column + 1}
    [token, eof]
  end
  def lexer_integer(<<".", rest :: binary>>, first_state, state, content) do
    first = String.first(rest)
    next_state = %{state | column: state.column + 1}
    if is_digit(first) do
      lexer_float(rest, first_state, next_state, content <> ".")
    else
      {num, ""} = Float.parse(content)
      token = {{:number, num}, first_state.line, first_state.column}
      if is_whitespace(first) or is_safe_terminal(first) do
        [token | lexer(rest, state)]
      else
        unexpected = {:error, "Expected whitespace or end of file after number, but got #{String.slice(rest, 0, 5)}...", state.line, state.column + 1}
        [token, unexpected]
      end
    end
  end
  def lexer_integer(input, first_state, state, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_state = %{state | column: state.column + 1}
    next_content = content <> first
    case rest do
      "" ->
        {num, ""} = Integer.parse(next_content)
        token = {{:number, num}, first_state.line, first_state.column}
        eof = {:end_of_file, state.line, state.column + 1}
        [token, eof]
      _ ->
        first_of_rest = String.first(rest)
        if is_digit(String.first(rest)) or first_of_rest == "." do
          lexer_integer(rest, first_state, next_state, next_content)
        else
          {num, ""} = Integer.parse(next_content)
          token = {{:number, num}, first_state.line, first_state.column}
          if is_whitespace(first_of_rest) or is_safe_terminal(first_of_rest) do
            [token | lexer(rest, state)]
          else
            unexpected = {:error, "Expected whitespace or end of file or right parenthesis or right dict or comment after number, but got #{String.slice(rest, 0, 5)}...", state.line, state.column + 1}
            [token, unexpected]
          end
        end
    end
  end
  def lexer_float(input, first_state, state, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_state = %{state | column: state.column + 1}
    next_content = content <> first
    case rest do
      "" ->
        {num, ""} = Float.parse(next_content)
        token = {{:number, num}, first_state.line, first_state.column}
        eof = {:end_of_file, state.line, state.column + 1}
        [token, eof]

      _ ->
        first_of_rest = String.first(rest)
        if is_digit(first_of_rest) do
          lexer_float(rest, first_state, next_state, next_content)
        else
          {num, ""} = Float.parse(next_content)
          token = {{:number, num}, first_state.line, first_state.column}
          [token | lexer(rest, next_state)]
        end
    end
  end
  def lexer_symbol(input, state) do
    lexer_symbol(input, state, state, "")
  end
  def lexer_symbol(input, first_state, state, content) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    next_state = %{state | column: state.column + 1}
    next_content = content <> first
    case rest do
      "" ->
        token = {{:symbol, next_content}, first_state.line, first_state.column}
        eof = {:end_of_file, state.line, state.column + 1}
        [token, eof]
      _ ->
        first_of_rest = String.first(rest)
        case first_of_rest do
          x when x == ";" or x == ")" or x == "}" or x == "," or is_whitespace(x) ->
            token = {{:symbol, next_content}, first_state.line, first_state.column}
            [token | lexer(rest, next_state)]
          "'" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a quote in the middle. Quotes should only go before keywords, not in between.", state.line, state.column}
            [unexpected]
          "\"" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a double quote in the middle. Strings should be spaced away from keywords.", state.line, state.column}
            [unexpected]
          "(" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a \"(\" in the middle. Parenthesis should be spaced away from keywords.", state.line, state.column}
            [unexpected]
          "%" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a \"%\" in the middle. Dicts should be spaced away from keywords.", state.line, state.column}
            [unexpected]
          "{" ->
            unexpected = {:error, "Tried to create a keyword starting with #{inspect next_content}, but got a \"{\" in the middle. Dicts should be spaced away from keywords. This is also a malformed dict, as dicts should start with %{", state.line, state.column}
            [unexpected]
          _ -> lexer_symbol(rest, state, next_state, next_content)
        end
    end
  end

  def lexer_whitespace(input, state) do
    lexer_whitespace(input, state, state)
  end
  def lexer_whitespace(input, first_state, state) do
    first = String.first(input)
    rest = String.slice(input, 1..-1)
    token = {:whitespace, first_state.line, first_state.column}
    line = case first do
      "\n" -> state.line + 1
      _ -> state.line
    end
    column = state.column + 1
    next_state = %{state | line: line, column: column}
    case rest do
      "" ->
        eof = {:end_of_file, state.line, state.column + 1}
        [token, eof]
      _ ->
        if is_whitespace(String.first(rest)) do
          lexer_whitespace(rest, first_state, next_state)
        else
          [token | lexer(rest, next_state)]
        end
    end
  end
end
