defmodule Sweetconfig do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Sweetconfig.Worker, [arg1, arg2, arg3])
    ]

    :sweetconfig = :ets.new :sweetconfig, [:named_table, {:read_concurrency, true}, :public, :protected]
    Sweetconfig.Utils.load_configs
    opts = [strategy: :one_for_one, name: Sweetconfig.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @type config :: [{term,term}]

  @doc """
  Performs `get/1` and returns default values in case nothing is found for the
  given path.
  """
  @spec get([term], config) :: config
  def get(path, defaults) do
    get(path) || defaults
  end

  @doc """
  Looks up the path in the config denoted by the key in the head of the list.
  """
  @spec get([term]) :: nil | config
  def get([root | path]) do
    case :ets.lookup(:sweetconfig, root) do
      [{^root, config}] -> lookup_config(config, path)
      [] ->
        case :application.get_all_env(root) do
          [] -> nil
          config -> lookup_config(config, path)
        end
    end
  end

  @doc """
  Looks up a single key.
  """
  @spec get(term) :: nil | config
  def get(key) do
    case :ets.lookup(:sweetconfig, key) do
      [{^key, config}] -> config
      [] ->
        case :application.get_all_env(key) do
          [] -> nil
          config -> config
        end
    end
  end

  defp lookup_config(config, []), do: config
  defp lookup_config(config, path) do
    get_in(config, path)
  end
end
