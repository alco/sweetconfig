defmodule Sweetconfig do
  use Application

  @pubsub_server Sweetconfig.Pubsub

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Sweetconfig.Pubsub, [@pubsub_server])
    ]

    :sweetconfig = :ets.new(:sweetconfig, [:named_table, {:read_concurrency, true}, :public])
    _ = Sweetconfig.Utils.load_configs(silent: true)

    opts = [strategy: :one_for_one, name: Sweetconfig.Supervisor]
    Supervisor.start_link(children, opts)
  end


  alias Sweetconfig.Utils

  @doc """
  Perform `get/1` and return the supplied default in case nothing is found for
  the given path.
  """
  @spec get([term], term) :: term
  def get(path, default) do
    get(path) || default
  end

  @doc """
  Look up the path in the config denoted by the key in the head of the list.

  If no config is found, the key is treated as an app name and the application
  environment is checked instead.

  In case nothing is found, `nil` is returned.
  """
  @spec get([term]) :: term
  def get([root | path]) do
    case :ets.lookup(:sweetconfig, root) do
      [{^root, config}] -> Utils.lookup_config(config, path)
      [] -> get_app_config(root, path)
    end
  end

  @doc """
  Look up a single key that is normally an app name.

  If there is no corresponding config, the `app`'s application environment is
  returned as a map.
  """
  @spec get(term) :: term
  def get(app) when not is_list(app), do: get([app])

  @doc """
  Subscribe to notifications emitted whenever the specified config value
  changes.

  If the 2nd argument is a pid, a message will be sent to it that will have the
  following shape:

      {Sweetconfig.Pubsub, <path>, <change>}

  If the 2nd argument is a function, it will be invoked with a tuple
  `{<path>, <change>}`.

  If the 2nd argument is a tuple `{<module>, <function>, <args>}`, the function
  `<module>.<function>` will be called with `<args>` with `{<path>, <change>}`
  appended to the args.

  `<change>` will be one of the following (depending on the value of the
  `events` argument):

    * `{:changed, old_val, new_val}` – the value was changed
    * `{:added, new_val}` – the value was added where previously there was no
      value or it was `nil`
    * `{:removed, old_val}` – the value was removed or set to `nil`

  """
  @spec subscribe([term],
                  [:changed | :added | :removed] | :all,
                  pid | function | {atom,atom,[term]}) :: :ok

  def subscribe(path, events \\ [:changed], handler) do
    handler = case handler do
      pid when is_pid(pid)     -> {:pid, pid}
      f when is_function(f, 1) -> {:func, f}
      {_mod, _func, _args}=mfa -> {:mfa, mfa}
    end
    unless events == :all, do: events = List.wrap(events)
    Sweetconfig.Pubsub.subscribe(@pubsub_server, List.wrap(path), events, handler)
  end

  @doc """
  Remove a subscriber identified by the given pid or ref.

  The argument should be

    1) the ref returned from a previous call to `subscribe()`

    2) a pid of a subscribed process, in which case all subscription paths for
       that process will be removed
  """
  def unsubscribe(pid_or_ref) do
    Sweetconfig.Pubsub.unsubscribe(@pubsub_server, pid_or_ref)
  end

  @doc """
  Remove all subscribers registered for the given path.

  Passing `:all` instead of a list will remove subscribers for all paths.
  """
  def drop_subscribers(path \\ :all) do
    Sweetconfig.Pubsub.drop_subscribers(@pubsub_server, path)
  end

  @doc """
  Remove all loaded config values.
  """
  def purge() do
    :ets.delete_all_objects :sweetconfig
  end

  @doc false
  # this function is called internally when configs are reloaded
  def get_subscribers(root) do
    Sweetconfig.Pubsub.get_subscribers(@pubsub_server, root)
  end

  ###

  defp get_app_config(app, []) do
    case Application.get_all_env(app) do
      [] -> nil
      env -> Enum.into(env, %{})
    end
  end

  defp get_app_config(app, [key|path]) do
    Application.get_env(app, key) |> Utils.lookup_config(path)
  end
end
