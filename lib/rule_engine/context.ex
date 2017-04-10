defmodule RuleEngine.Context do
  defstruct [
    mutable: nil,
    env: nil
  ]
  def update(context, mutable) do
    %{context | mutable: mutable}
  end
  def change_env(context, env) do
    %{context | env: env}
  end
end
