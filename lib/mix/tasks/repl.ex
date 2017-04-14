defmodule Mix.Tasks.RuleEngine.Repl do
  use Mix.Task
  import RuleEngine.LISP

  def run(_) do
    main()
  end
end
