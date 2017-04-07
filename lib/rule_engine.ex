defmodule RuleEngine do
  @moduledoc """
  RuleEngine is a pure elixir library that helps execute
  basic predicates which may then modify arbitrary state.

  Each evaluation may access the input state, which has
  accessor methods (should be referentially transparent)
  and non-mutating, as well as the accumulating state
  which is returned at the end.

  Although the AST is intended to be LISP-like for internal
  simplicity, the language used to create a rule need not be LISP.
  """

end
