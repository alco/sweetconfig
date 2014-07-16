defmodule SweetconfigTest.PubsubTest do
  use ExUnit.Case

  setup do
    on_exit fn ->
      Sweetconfig.purge()
    end
    Sweetconfig.Utils.load_configs :silent
    :ok
  end

  test "new value" do
    Sweetconfig.subscribe [:cqlex, :new_key], [:added, :changed], self()
    Sweetconfig.subscribe [:new_section], [:added], self()
    Sweetconfig.subscribe [:new_section, :creds, :username], :all, self()
    refute_receive _

    load_from_fixture "new"
    :timer.sleep(100)

    assert_receive {Sweetconfig.Pubsub, [:cqlex, :new_key], {:added, "value"}}
    assert_receive {Sweetconfig.Pubsub, [:new_section], {:added, %{}}}
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

    assert_receive {Sweetconfig.Pubsub, [:exrabbit, :test_queue, :host], {:removed, '127.0.0.1'}}
    assert_receive {Sweetconfig.Pubsub, [:exrabbit, :test_queue], {:removed, %{}}}
    assert_receive {Sweetconfig.Pubsub, [:cqlex], {:removed, %{}}}
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

  defp load_from_fixture(name) do
    path = Path.join([Path.expand("..", __DIR__), "fixtures", name])
    Sweetconfig.Utils.load_configs(path)
  end
end
