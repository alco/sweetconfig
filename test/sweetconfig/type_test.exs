defmodule SweetconfigTest.TypeTest do
  use ExUnit.Case

  import SweetconfigTest.Helpers

  setup_all do
    load_from_fixture "types"
    :ok
  end

  test "basic scalars" do
    assert Sweetconfig.get(:nums) === [1, 2, 3.0, 4.0e5, 0xFF]
    assert Sweetconfig.get(:atoms) == [:atom, :nil, :error, :ok]
    assert Sweetconfig.get(:implicit) == %{
      :hello => :world,
      "good-bye" => "cruel world",
      :alias => File.Stat,
      :function => "String.slice",
    }
  end

  test "lists, charlists, binaries" do
    assert Sweetconfig.get(:list) === [1, :atom, [2, 3]]
    assert Sweetconfig.get(:seq) === [[1, :atom, [2, 3]], 4, 5]
    assert Sweetconfig.get(:charlist) == 'hello world'
    assert Sweetconfig.get(:strings) == ["binary", "юникод работает?", 'юникод работает', ['three', 'more', 'charlists']]
  end

  test "map" do
    assert Sweetconfig.get(:simple_key) == %{:hello => "world", 123 => 456, "spaces in key" => "...", 'charlist key' => "..."}
    assert Sweetconfig.get(:test) == %{'key' => :value, 123 => "number"}
  end

  test "showcase" do
    assert Sweetconfig.get(:showcase) ==
      %{
        map: %{:a => "keys are atoms", "b-c" => "unless they have non-identifier characters"},
        list: ["this is a binary", 'this is a char list', [:these, :are, :atoms], Elixir.Alias],
        implicit: [:can, "be ambiguous"],
      }
  end

  #test "keyword list" do
  #  assert Sweetconfig.get(:tuples) == [{}, {'hello'}, {:a,"b",13}]
  #  assert Sweetconfig.get(:keywords) == [[key: :val], [hi: "bye", nested: [a: :b], do: 'dont']]
  #end

  # TODO: we need to implement a translation step for this to work
  #test "struct" do
  #end
end
