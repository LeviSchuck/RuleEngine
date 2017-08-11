defmodule RuleEngine.Environment do
  alias RuleEngine.Environment
  @moduledoc false
  @type t :: %__MODULE__{}
  defstruct [
    vals: %{},
    outer: nil,
    id: 0,
    depth: 0,
    label: nil,
  ]

  @spec make(%{}, any, Environment.t | nil, atom | nil) :: Environment.t
  def make(vals, id, outer \\ nil, label \\ nil) do
    {depth, outer} = case outer do
      %Environment{depth: depth} = outer -> {depth + 1, outer}
      _ -> {0, nil}
    end
    %Environment{
      vals: vals,
      outer: outer,
      id: id,
      depth: depth,
      label: label,
    }
  end

  @doc "Find a symbol in a hierarchy of environments"
  @spec get(Environment.t, any, atom | nil) :: {:ok, any} | :not_found
  def get(environment, key, label \\ nil) do
    local_get = fn environment, key ->
      case environment do
        %Environment{} ->
          case Map.get(environment.vals, key, :not_found) do
            :not_found -> :not_found
            res -> {:ok, res}
          end
        _ -> :not_found
      end
    end
    case label do
      nil ->
        case local_get.(environment, key) do
          :not_found ->
            case environment.outer do
              nil -> :not_found
              parent -> get(parent, key)
            end
          {:ok, val} -> {:ok, val}
        end
      label ->
        case environment do
          %Environment{label: ^label} -> local_get.(environment, key)
          %Environment{outer: nil} -> :not_found
          %Environment{outer: parent} -> get(parent, key, label)
          _ -> :not_found
        end
    end
  end

  def put(environment, key, value, label \\ nil)
  def put(%Environment{} = environment, key, value, nil) do
    update_in(environment, [Access.key!(:vals)], fn m ->
      Map.put(m, key, value)
    end)
  end
  def put(environment, key, value, label) do
    case environment do
      %Environment{label: ^label} -> put(environment, key, value)
      %Environment{outer: nil} -> throw {:environment_not_found, label}
      %Environment{outer: environment} ->
        update_in(environment, [Access.key!(:outer)], fn parent ->
          put(parent, key, value, label)
        end)
    end
  end

  def extract(environment, label \\ nil)
  def extract(%Environment{vals: vals}, nil), do: vals
  def extract(environment, label) do
    case environment do
      %Environment{label: ^label, vals: vals} -> vals
      %Environment{outer: nil} -> throw {:environment_not_found, label}
      %Environment{outer: environment} -> extract(environment, label)
    end
  end
end
