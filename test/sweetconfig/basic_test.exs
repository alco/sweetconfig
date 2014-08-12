defmodule SweetconfigTest.BasicTest do
  use ExUnit.Case

  setup_all do
    Sweetconfig.Utils.load_configs silent: true
    :ok
  end

  test "it works" do
    assert %{pool: ["127.0.0.1", "127.0.0.2"]} = Sweetconfig.get(:cqlex)
  end
  test "defaults working" do
  	assert %{hello: :world} = Sweetconfig.get(:hello, %{hello: :world})
  end
  test "deep get works" do
  	assert ["127.0.0.1", "127.0.0.2"] = Sweetconfig.get([:cqlex, :pool])
  end
  test "types working" do
  	assert "somename" = Sweetconfig.get([:exrabbit, :test_queue, :username])
  end
end
