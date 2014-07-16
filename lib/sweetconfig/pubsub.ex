defmodule Sweetconfig.Pubsub do
  use GenServer

  require Record
  Record.defrecordp :state, subscribers: %{}, monitors: %{}

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init([]) do
    {:ok, state()}
  end

  def subscribe(server, path, events, handler) do
    GenServer.call(server, {:subscribe, path, events, handler})
  end

  def get_subscribers(server, root) do
    GenServer.call(server, {:get_subscribers, root})
  end

  ###

  def handle_call({:subscribe, path, events, handler}, _from, state(subscribers: subs, monitors: mons)=state) do
    new_mons = case handler do
      {:pid, pid} ->
        mon = Process.monitor(pid)
        Map.put(mons, mon, path)
      _ -> mons
    end
    item = {handler, events}
    new_subs = Map.update(subs, path, [item], &[item|&1])
    {:reply, :ok, state(state, subscribers: new_subs, monitors: new_mons)}
  end

  def handle_call({:get_subscribers, root}, _from, state(subscribers: subs)=state) do
    matching_subs = Enum.filter(subs, fn {[h|_], _} -> h == root end)
    {:reply, matching_subs, state}
  end

  def handle_info({:DOWN, monitor, _type, pid, _info}, state(subscribers: subs, monitors: mons)=state) do
    {path, new_mons} = Map.pop(mons, monitor)
    new_subs = case delete_all_matching(Map.get(subs, path), {:pid, pid}) do
      [] -> Map.delete(subs, path)
      other -> Map.put(subs, path, other)
    end
    {:noreply, state(state, subscribers: new_subs, monitors: new_mons)}
  end

  ###

  def notify_subscriber({:pid, pid}, path, change) do
    send(pid, {__MODULE__, path, change})
  end

  def notify_subscriber({:func, f}, path, change) do
    f.({path, change})
  end

  def notify_subscriber({:mfa, {m, f, args}}, path, change) do
    apply(m, f, args ++ [{path, change}])
  end

  defp delete_all_matching(list, val) do
    List.foldl(list, [], fn {item, _}, acc ->
      case item do
        ^val -> acc
        _    -> [item|acc]
      end
    end)
  end
end
