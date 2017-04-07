defmodule RuleEngine.AST do
  @moduledoc """
  This module holds a couple AST records to represent
  predicates and directives.
  However, for simplicity, instead of an absolute AST,
  this will be a simple LISP like environment with lists
  and applied functions.
  Rules must be decidable and thus recursion is forbidden.
  When recursion is detected, it will not be executed
  and the return value will be nil.
  Built-in functions are prefixed by a `:` and are discussed
  below.

  To encode a value from the outside, wrap it in a literal call.
  In the AST, this function may be:
  * `:literal` - which only takes 1 parameter

  A logic check is an expression which combines expressions
  logically.
  All parameters are expected to be of boolean types.
  Any non-boolean types will result in a runtime error!
  Empty inputs (after filtering to only boolean types) will
  be considered false.
  Logic parameters may be shirt circuited and therefore should
  not have side effects. For example, if any parameters in
  an `:and` operation is false, the rest will not be evaluated.
  Function may be:
  * `:and`
  * `:or`

  Comparisons operate on single values and will be false
  for any collection that is given.
  The first parameter is expected to be a reference or value
  which is then compared to all subsequent parameters.
  If there is only one parameter, these functions will be false.
  Function may be:
  * `:equals`
  * `:less_than`
  * `:greater_than`
  * `:less_than_or_equals`
  * `:greater_than_or_equals`

  Special case two-parameter functions:
  If only one parameter is given, the result is false.
  All parameters after the second parameter are ignored.
  * `:substring` - The second parameter is expected to be the
    substring to find in the first parameter.

  To complete the comarisons, a couple boolean unary functions
  are available.
  Function may be:
  * `:not` - expects a single boolean expression
  * `:is_nil` - expects a reference-value expression,
    is true for empty maps and lists as well.

  For simple conditional logic, the following list functions are available.
  Only at most one subtree will be executed.
  Function may be:
  * `:cond` - Executes each list item's first element, when true,
    the other elements in that list will be executed.
    When false or nil, the other elements in that list will not be executed.
    Any other value for the first element than true, false, and nil, will
    result in a runtime error!

  As function calls may need to be assembled on the fly
  with function names as values and values as parameters,
  the following two-parameter function is available.
  The first parameter may also be a lambda.
  When called with only one parameter, nil will be the return
  value.
  All parameters after the second parameter are ignored.
  Function may be:
  * `:apply`

  In order to create your own non-recursing lambdas, you can use
  the following function.
  If a lambda is called and it is already present on the stack,
  it will return nil.
  The first parameter must be a list of symbols, this will be used
  to deconstruct the input.
  The subsequent parameters are executed, the last parameter's
  expression is the return value.
  In teh case that a lambda is applied to too few parameters or
  too many parameters, it will still execute, but ignore too many
  parameters, and when too few, the symbols will be assigned to nil.
  Function may be:
  * `:lambda`

  To operate on a collection, the following functions may be used.
  The first parameter is a function symbol, or lambda.
  The second parameter is a collection.
  The input function's first parameter is given the key (for maps)
  or thex index (for lists).
  The input function's second paremeter is given the value.
  The key or index is informational and may not be changed.
  Function may be:
  * `:each` - This will execute the lambda for each element,
    discarding the return value.

  *TODO: other collection functions like:*
  * Map
  * Filter
  * Into
  * Reduce

  To use external functions provided by the caller, the following
  get-like function may be used.
  Function may be:
  * `:access`

  """

  require Record
  Record.defrecord :apply_fun, fun: nil, values: []
  def literal(v), do: apply_fun(fun: :literal, values: [v])
  def list(v), do: apply_fun(fun: :escaped_list, values: v)
  def app(fun, vals) when is_list(vals),
    do: apply_fun(fun: fun, values: vals)
end
