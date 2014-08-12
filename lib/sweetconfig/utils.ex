defmodule Sweetconfig.Utils do
  @doc """
  Reload configs from the config directory with default options.
  """
  def load_configs() do
    load_configs([])
  end

  @doc """
  Reload configs from the config directory.

  ## Options

    * `silent: <boolean>` - whether to notify the subscribers of the changes;
      default: `false`

    * `write_to_env: <keyword list>` - for each app specify the list of keys
      that will be written to application env; default: `[]` (overridable in
      config.exs)

  """
  def load_configs(options) when is_list(options) do
    do_load_configs(config_path, options)
  end

  @doc """
  Reload configs from the specified directory.
  """
  def load_configs(path, options \\ []) when is_binary(path) and is_list(options) do
    do_load_configs(path, options)
  end

  @doc false
  def lookup_config(config, []), do: config
  def lookup_config(config, path), do: get_in(config, path)

  ###

  defp do_load_configs(path, options) do
    silent = Keyword.get(options, :silent, false)
    env_keys =
      case Keyword.fetch(options, :write_to_env) do
        {:ok, list} -> list
        :error -> Application.get_env(:sweetconfig, :write_to_env, [])
      end
      |> Enum.map(fn {app, keys} -> {app, Enum.into(keys, HashSet.new)} end)
      |> Enum.into(%{})

    case File.ls(path) do
      {:ok, files} ->
        configs =
          Enum.map(files, fn file -> path <> "/" <> file end)
          |> process_files
          |> push_to_ets(silent)
          |> push_to_env(env_keys)
          {:ok, configs}
      {:error, _} -> {:error, :no_configs}
    end
  end

  defp config_path do
    case Application.fetch_env(:sweetconfig, :dir) do
      {:ok, dir} -> dir
      :error -> :code.priv_dir(get_config_app) |> List.to_string
    end
  end

  @app Mix.Project.config[:app]
  defp get_config_app do
    Application.get_env(:sweetconfig, :app, @app)
  end

  defp push_to_ets([], _), do: []
  defp push_to_ets([configs], silent) do
    for {key, value} <- configs do
      new_dict = value
      old_dict = case :ets.lookup(:sweetconfig, key) do
        []        -> nil
        [{_,val}] -> val
      end
      :ets.insert(:sweetconfig, {key, new_dict})
      unless silent, do: diff_and_notify(key, old_dict, new_dict)
    end
    configs
  end
  defp push_to_ets(configs, silent) when is_list(configs) do
    # FIXME: the Map.merge called below will override recurrent config values,
    # but the order in which it will happen is not defined explicitly. The
    # order depends solely on the order of files return from `File.ls` which is
    # not guaranteed to be consistent between calls
    case Enum.all?(configs, &is_map/1) do
      true -> [Enum.reduce(configs, %{}, &Map.merge/2)] |> push_to_ets(silent)
      false -> raise "Strange configuration structure: #{inspect configs}"
    end
  end

  defp push_to_env(configs, env_keys) do
    Enum.each(env_keys, fn {app, keys} ->
      update_env(app, keys, Map.fetch(configs, app))
    end)
    configs
  end

  defp update_env(_, _, :error), do: nil
  defp update_env(app, keys, {:ok, config}) do
    for key <- keys do
      case Map.fetch(config, key) do
        {:ok, value} -> Application.put_env(app, key, value)
        :error -> nil
      end
    end
  end

  defp load_config(file) do
    case :yaml.load_file(file, [:implicit_atoms, schema: :yaml_schema_elixir]) do
      {:ok, data} -> data
      err -> raise "Failed to parse configuration file #{file} with error #{inspect err}"
    end
  end

  defp process_files([]), do: %{}
  defp process_files(files) do
    Enum.reduce(files, [], fn file, merged_config ->
      case file =~ ~r/\.ya?ml$/ do
        true -> merge_configs(load_config(file), merged_config)
        false -> merged_config
      end
    end)
  end

  defp merge_configs(config1, config2) do
    config1 ++ config2
  end

  defp diff_and_notify(key, old_dict, new_dict) do
    Sweetconfig.get_subscribers(key)
    |> Enum.each(&process_handler(&1, old_dict, new_dict))
  end

  defp process_handler({[_|path]=fullpath, handlers}, old_dict, new_dict) do
    old_val = lookup_config(old_dict, path)
    new_val = lookup_config(new_dict, path)
    if old_val != new_val do
      change = case {old_val, new_val} do
        {nil, _} -> {:added, new_val}
        {_, nil} -> {:removed, old_val}
        _        -> {:changed, old_val, new_val}
      end
      notify_handlers(handlers, fullpath, change)
    end
  end

  defp notify_handlers(handlers, path, change) do
    handlers
    |> Enum.filter(fn {_, events, _} -> change_is_valid(change, events) end)
    |> Enum.each(fn {handler, _, _} ->
      Sweetconfig.Pubsub.notify_subscriber(handler, path, change)
    end)
  end

  defp change_is_valid(_, :all), do: true
  defp change_is_valid({x, _}, events), do: Enum.member?(events, x)
  defp change_is_valid({x, _, _}, events), do: Enum.member?(events, x)
end

