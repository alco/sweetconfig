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

  def subscribe(server, path, handler) do
    GenServer.call(server, {:subscribe, path, handler})
  end

  def notify(server, path, old_val, new_val) do
    GenServer.cast(server, {:notify, path, old_val, new_val})
  end

  ###

  def handle_call({:subscribe, path, handler}, _from, state(subscribers: subs, monitors: mons)=state) do
    new_mons = case handler do
      {:pid, pid} ->
        mon = Process.monitor(pid)
        Map.put(mons, mon, path)
      _ -> mons
    end
    new_subs = Map.update(subs, path, [handler], &[handler|&1])
    {:reply, :ok, state(state, subscribers: new_subs, monitors: new_mons)}
  end

  def handle_cast({:notify, path, old_val, new_val}, state(subscribers: subs)=state) do
    # FIXME: is it safe to call handlers in the server's process or should we
    # spawn_link them?
    Enum.each(Map.get(subs, path, []), &notify_subscriber(&1, path, old_val, new_val))
    {:noreply, state}
  end

  def handle_info({:DOWN, monitor, _type, pid, _info}, state(subscribers: subs, monitors: mons)=state) do
    {path, new_mons} = Map.pop(mons, monitor)
    new_subs = Map.update!(subs, path, &delete_all_matching(&1, {:pid, pid}))
    {:noreply, state(state, subscribers: new_subs, monitors: new_mons)}
  end

  ###

  defp notify_subscriber({:pid, pid}, path, old_val, new_val) do
    send(pid, {__MODULE__, path, old_val, new_val})
  end

  defp notify_subscriber({:func, f}, path, old_val, new_val) do
    f.({path, old_val, new_val})
  end

  defp notify_subscriber({:mfa, {m, f, args}}, path, old_val, new_val) do
    apply(m, f, args ++ [{path, old_val, new_val}])
  end

  defp delete_all_matching(list, val) do
    List.foldl(list, [], fn item, acc ->
      case item do
        ^val -> acc
        _    -> [item|acc]
      end
    end)
  end
end
