defmodule Mix.Tasks.RuleEngine.Repl do
  @moduledoc false
  use Mix.Task
  import RuleEngine.LISP

  def run(_) do
    main()
  end
end
