defmodule SweetconfigTest.PubsubTest do
  use ExUnit.Case

  import SweetconfigTest.Helpers

  setup do
    on_exit fn ->
      Sweetconfig.purge()
      Sweetconfig.drop_subscribers()
    end
    Sweetconfig.Utils.load_configs silent: true
    :ok
  end

  test "new value" do
    Sweetconfig.subscribe [:cqlex, :new_key], [:added, :changed], self()
    Sweetconfig.subscribe :new_section, [:added], self()
    Sweetconfig.subscribe [:new_section, :creds, :username], :all, self()
    refute_receive _

    load_from_fixture "new"
    :timer.sleep(100)

    new_section = %{creds: %{username: "somename"}}
    assert_receive {Sweetconfig.Pubsub, [:cqlex, :new_key], {:added, "value"}}
    assert_receive {Sweetconfig.Pubsub, [:new_section], {:added, ^new_section}}
    assert_receive {Sweetconfig.Pubsub, [:new_section, :creds, :username], {:added, "somename"}}
    refute_receive _
  end

  test "changed value" do
    Sweetconfig.subscribe [:exrabbit, :keno_queue, :host], self()
    refute_receive _

    load_from_fixture "changed"

    assert_receive {Sweetconfig.Pubsub, [:exrabbit, :keno_queue, :host], {:changed, '127.0.0.1', "localhost"}}
    refute_receive _
  end

  test "removed value" do
    Sweetconfig.subscribe [:exrabbit, :test_queue, :host], :all, self()
    Sweetconfig.subscribe [:exrabbit, :test_queue], :all, self()
    Sweetconfig.subscribe [:cqlex], :removed, self()
    refute_receive _

    load_from_fixture "changed"

    test_queue = %{host: '127.0.0.1', username: "somename"}
    cqlex = %{pool: ["127.0.0.1", "127.0.0.2"]}
    assert_receive {Sweetconfig.Pubsub, [:exrabbit, :test_queue, :host], {:removed, '127.0.0.1'}}
    assert_receive {Sweetconfig.Pubsub, [:exrabbit, :test_queue], {:removed, ^test_queue}}
    assert_receive {Sweetconfig.Pubsub, [:cqlex], {:removed, ^cqlex}}
    refute_receive _
  end

  test "no path matching" do
    Sweetconfig.subscribe [:hello], :all, self()
    refute_receive _

    load_from_fixture "changed"

    refute_receive _
  end

  test "no event matching" do
    Sweetconfig.subscribe [:exrabbit, :test_queue, :host], :added, self()
    Sweetconfig.subscribe [:exrabbit, :test_queue], [:changed, :added], self()
    Sweetconfig.subscribe [:exrabbit, :keno_queue, :host], [:removed, :added], self()
    Sweetconfig.subscribe [:cqlex], [:changed], self()
    refute_receive _

    load_from_fixture "changed"

    refute_receive _
  end

  test "dead subscriber" do
    pid = spawn(fn -> receive do :die -> :ok end end)

    assert [] = Sweetconfig.get_subscribers(:exrabbit)
    Sweetconfig.subscribe [:exrabbit, :test_queue, :host], :all, pid
    refute [] = Sweetconfig.get_subscribers(:exrabbit)

    send(pid, :die)
    :timer.sleep(50)
    refute Process.alive?(pid)
    assert [] = Sweetconfig.get_subscribers(:exrabbit)
  end

  test "unsubscribe ref" do
    Sweetconfig.subscribe [:exrabbit, :test_queue, :host], :all, self()
    ref = Sweetconfig.subscribe [:exrabbit, :test_queue], :all, self()
    refute_receive _

    Sweetconfig.unsubscribe(ref)

    load_from_fixture "changed"

    assert_receive {Sweetconfig.Pubsub, [:exrabbit, :test_queue, :host], {:removed, '127.0.0.1'}}
    refute_receive _
  end

  test "unsubscribe pid" do
    Sweetconfig.subscribe [:exrabbit, :test_queue, :host], :all, self()
    Sweetconfig.subscribe [:exrabbit, :test_queue], :all, self()
    refute_receive _

    Sweetconfig.unsubscribe(self())

    load_from_fixture "changed"

    refute_receive _
  end

  test "function callback" do
    import ExUnit.CaptureIO

    Sweetconfig.subscribe [:exrabbit, :keno_queue, :host], :changed, &dump_change/1
    assert capture_io(fn ->
      load_from_fixture "changed"
    end) == ~s([:exrabbit, :keno_queue, :host]\nold: '127.0.0.1', new: "localhost")
  end

  test "mfa callback" do
    import ExUnit.CaptureIO

    Sweetconfig.subscribe [:exrabbit, :keno_queue, :host], :changed, {__MODULE__, :dump_it, [:foo]}
    assert capture_io(fn ->
      load_from_fixture "changed"
    end) == ~s([:exrabbit, :keno_queue, :host]\nold and new: '127.0.0.1' "localhost")
  end

  defp dump_change({path, {:changed, old, new}}) do
    IO.inspect path
    IO.write "old: #{inspect old}, new: #{inspect new}"
  end

  def dump_it(:foo, {path, {:changed, old, new}}) do
    IO.inspect path
    IO.write "old and new: #{inspect old} #{inspect new}"
  end
end
