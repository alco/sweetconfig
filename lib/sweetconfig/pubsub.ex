defmodule Sweetconfig.Pubsub do
  use GenServer

  require Record
  Record.defrecordp :state, subscribers: %{}

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init([]) do
    {:ok, state()}
  end

  def subscribe(server, path, events, handler) do
    GenServer.call(server, {:subscribe, path, events, handler})
  end

  def unsubscribe(server, ref) do
    GenServer.call(server, {:unsubscribe, ref})
  end

  def get_subscribers(server, root) do
    GenServer.call(server, {:get_subscribers, root})
  end

  def drop_subscribers(server, path \\ :all) do
    GenServer.call(server, {:drop_subscribers, path})
  end

  ###

  def handle_call({:subscribe, path, events, handler}, _from, state(subscribers: subs)=state) do
    handler = case handler do
      {:pid, pid} ->
        mon = Process.monitor(pid)
        {:pid, pid, mon}
      _ -> handler
    end
    ref = make_ref()
    item = {handler, events, ref}
    new_subs = Map.update(subs, path, [item], &[item|&1])
    {:reply, ref, state(state, subscribers: new_subs)}
  end

  def handle_call({:unsubscribe, ref}, _from, state(subscribers: subs)=state) do
    new_subs = delete_all_matching(subs, ref)
    {:reply, :ok, state(state, subscribers: new_subs)}
  end

  def handle_call({:get_subscribers, root}, _from, state(subscribers: subs)=state) do
    matching_subs = Enum.filter(subs, fn {[h|_], _} -> h == root end)
    {:reply, matching_subs, state}
  end

  def handle_call({:drop_subscribers, path}, _from, state(subscribers: subs)=state) do
    new_state = case path do
      :all ->
        Enum.each(subs, fn {_, handlers} -> demonitor_all(handlers) end)
        state()

      path ->
        {handlers, new_subs} = Map.pop(subs, path)
        demonitor_all(handlers)
        state(state, subscribers: new_subs)
    end
    {:reply, :ok, new_state}
  end

  def handle_info({:DOWN, _, _type, pid, _info}, state(subscribers: subs)=state) do
    new_subs = delete_all_matching(subs, pid)
    {:noreply, state(state, subscribers: new_subs)}
  end

  ###

  def notify_subscriber({:pid, pid, _}, path, change) do
    send(pid, {__MODULE__, path, change})
  end

  def notify_subscriber({:func, f}, path, change) do
    f.({path, change})
  end

  def notify_subscriber({:mfa, {m, f, args}}, path, change) do
    apply(m, f, args ++ [{path, change}])
  end

  defp delete_all_matching(subs, val) do
    import Enum

    subs
    |> map(fn {path, handlers} -> {path, delete_matching_handlers(handlers, val)} end)
    |> reject(fn {_, handlers} -> match?([], handlers) end)
    |> into(%{})
  end

  defp delete_matching_handlers(list, val) do
    List.foldl(list, [], fn {handler, _, ref}=item, acc ->
      case {handler, ref} do
        {{:pid, ^val, _}, _} -> acc
        {_, ^val} -> acc
        _ -> [item|acc]
      end
    end)
  end

  defp demonitor_all(handlers) do
    for {:pid, _, mon} <- handlers, do: Process.demonitor(mon)
  end
end
