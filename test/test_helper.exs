ExUnit.start()

defmodule SweetconfigTest.Helpers do
  def load_from_fixture(name) do
    path = Path.join([__DIR__, "fixtures", name])
    Sweetconfig.Utils.load_configs(path)
  end
end
