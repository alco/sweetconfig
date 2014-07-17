defmodule SweetconfigTest.AppEnvTest do
  use ExUnit.Case

  import SweetconfigTest.Helpers

  setup_all do
    Sweetconfig.Utils.load_configs :silent
    :ok
  end

  setup do
    on_exit fn ->
      Sweetconfig.purge()
    end
    Application.get_all_env(:sweetconfig)
    |> Enum.each(fn {key, _} ->
      Application.delete_env(:sweetconfig, key)
    end)
  end

  test "no app env" do
    assert Sweetconfig.get(:sweetconfig) == nil
    assert Sweetconfig.get([:sweetconfig]) == nil
    assert Sweetconfig.get([:sweetconfig, :nested, :a]) == nil

    load_from_fixture "appenv"

    env = %{test_key: "value", nested: %{a: 1, b: 2}}
    assert Sweetconfig.get(:sweetconfig) == env
    assert Sweetconfig.get([:sweetconfig]) == env
    assert Sweetconfig.get([:sweetconfig, :nested, :a]) == 1
  end

  test "app env only" do
    assert Sweetconfig.get(:sweetconfig) == nil
    assert Sweetconfig.get([:sweetconfig, :nested, :b]) == nil

    Application.put_env(:sweetconfig, :nested, %{a: 1, b: 2})

    assert Sweetconfig.get(:sweetconfig) == %{nested: %{a: 1, b: 2}}
    assert Sweetconfig.get([:sweetconfig, :nested, :b]) == 2
  end

  test "mixed config and app env" do
    assert Sweetconfig.get(:sweetconfig) == nil
    assert Sweetconfig.get([:sweetconfig, :nested, :a]) == nil
    assert Sweetconfig.get([:sweetconfig, :test_key]) == nil
    assert Sweetconfig.get([:sweetconfig, :other]) == nil

    Application.put_env(:sweetconfig, :other, %{a: "1", b: "2"})
    assert Sweetconfig.get([:sweetconfig, :other, :b]) == "2"

    load_from_fixture "appenv"
    # test that loaded config overrides the app environment
    assert Sweetconfig.get([:sweetconfig, :other]) == nil

    assert Sweetconfig.get([:sweetconfig, :test_key]) == "value"
  end
end

