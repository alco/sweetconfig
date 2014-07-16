defmodule Sweetconfig do
  use Application

  @pubsub_server Sweetconfig.Pubsub

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Sweetconfig.Pubsub, [@pubsub_server])
    ]

    :sweetconfig = :ets.new(:sweetconfig, [:named_table, {:read_concurrency, true}, :public, :protected])
    _ = Sweetconfig.Utils.load_configs

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

  @doc """
  Subscribe to notifications emitted whenever the specified config value
  changes.

  If the 2nd argument is a pid, a message will be sent to it that will have the
  following shape:

      {Sweetconfig.Pubsub, <path>, <old_value>, <new_value>}

  If the 2nd argument is a function, it will be invoked with a tuple
  `{<path>, <old_value>, <new_value>}`.

  If the 2nd argument is a tuple `{<module>, <function>, <args>}`, the function
  `<module>.<function>` will be called with `<args>` after `{<path>,
  <old_value>, <new_value>}` appended to the args.
  """
  @spec subscribe([term], pid | function | {atom,atom,[term]}) :: :ok

  def subscribe(path, pid) when is_pid(pid) do
    Sweetconfig.Pubsub.subscribe(@pubsub_server, path, {:pid, pid})
  end

  def subscribe(path, f) when is_function(f, 1) do
    Sweetconfig.Pubsub.subscribe(@pubsub_server, path, {:func, f})
  end

  def subscribe(path, {_mod, _func, _args}=mfa) do
    Sweetconfig.Pubsub.subscribe(@pubsub_server, path, {:mfa, mfa})
  end

  ###

  defp lookup_config(config, []), do: config
  defp lookup_config(config, path) do
    get_in(config, path)
  end
end
