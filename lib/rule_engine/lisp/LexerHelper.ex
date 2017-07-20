defmodule RuleEngine.LISP.LexerHelper do
  defmacro is_digit(x) do
    quote do
      "0" == unquote(x) or
      "1" == unquote(x) or
      "2" == unquote(x) or
      "3" == unquote(x) or
      "4" == unquote(x) or
      "5" == unquote(x) or
      "6" == unquote(x) or
      "7" == unquote(x) or
      "8" == unquote(x) or
      "9" == unquote(x)
    end
  end
  defmacro is_whitespace(x) do
    quote do
      " " == unquote(x) or
      "\n" == unquote(x) or
      "\r" == unquote(x) or
      "\t" == unquote(x)
    end
  end
  defmacro is_safe_terminal(x) do
    quote do
      "" == unquote(x) or
      ";" == unquote(x) or
      "," == unquote(x) or
      ")" == unquote(x) or
      "}" == unquote(x)
    end
  end
end
