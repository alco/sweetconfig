defmodule Sweetconfig.Utils do
  def load_configs() do
    do_load_configs(priv_path, false)
  end

  def load_configs(:silent) do
    do_load_configs(priv_path, true)
  end

  def load_configs(path) when is_binary(path) do
    do_load_configs(path, false)
  end

  def load_configs(path, :silent) when is_binary(path) do
    do_load_configs(path, true)
  end

  defp do_load_configs(path, silent) do
    case File.ls(path) do
      {:ok, files} ->
        Enum.map(files, fn file -> path <> "/" <> file end)
        |> process_files
        |> push_to_ets(silent)
      {:error, _} -> {:error, :no_configs}
    end
  end

  defp priv_path do
    :code.priv_dir(get_config_app) |> List.to_string
  end

  @app Mix.Project.config[:app]
  defp get_config_app do
    :application.get_all_env(:sweetconfig)[:app] || @app
  end

  defp pre_process(int) when is_integer(int), do: int
  defp pre_process(atom) when is_atom(atom), do: atom
  defp pre_process(bin) when is_binary(bin), do: bin
  defp pre_process(list) when is_list(list) do
    for el <- list, into: [] do
      pre_process(el)
    end
  end
  defp pre_process(%{type: type, value: value}) when is_binary(value) do
    case type do
      :list -> :erlang.binary_to_list(value)
      :binary -> value
    end
  end
  defp pre_process(%{type: type, value: value}) when is_atom(value) do
    case type do
      :list -> :erlang.atom_to_list(value)
      :binary -> :erlang.atom_to_binary(value, :utf8)
    end
  end
  defp pre_process(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      {k, pre_process(v)}
    end
  end
  defp pre_process({k,v}) do
    pre_process({k, pre_process(v)})
  end

  defp push_to_ets([], _), do: []
  defp push_to_ets([configs], silent) do
    for {key, value} <- configs do
      new_dict = pre_process(value)
      old_dict = case :ets.lookup(:sweetconfig, key) do
        []    -> nil
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

  defp load_config(file) do
    case :yaml.load_file(file, [:implicit_atoms]) do
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
    old_val = get_with_path(old_dict, path)
    new_val = get_with_path(new_dict, path)
    if old_val != new_val do
      change = case {old_val, new_val} do
        {nil, _} -> {:added, new_val}
        {_, nil} -> {:removed, old_val}
        _        -> {:changed, old_val, new_val}
      end
      notify_handlers(handlers, fullpath, change)
    end
  end

  defp get_with_path(val, []), do: val
  defp get_with_path(val, path), do: get_in(val, path)

  defp notify_handlers(handlers, path, change) do
    handlers
    |> Enum.filter(fn {_, events} -> change_is_valid(change, events) end)
    |> Enum.each(fn {handler, _} ->
      Sweetconfig.Pubsub.notify_subscriber(handler, path, change)
    end)
  end

  defp change_is_valid(_, :all), do: true
  defp change_is_valid({x, _}, events), do: Enum.member?(events, x)
  defp change_is_valid({x, _, _}, events), do: Enum.member?(events, x)
end

