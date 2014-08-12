Sweetconfig
===========

[![Build Status](https://travis-ci.org/d0rc/sweetconfig.png?branch=master "Build Status")](http://travis-ci.org/d0rc/sweetconfig)

Sweetconfig is a utility for reading multiple YAML configuration files and
exposing them as Elixir terms in a running application.


## Usage

Place configuration YAML files in `priv/` directory of your root application.

Add the following section to your `config.exs` file:

```elixir
config :sweetconfig,
	app: :name_of_your_application
```

Include Sweetconfig as a dependency in your project:

```elixir
def application do
  [applications: [:sweetconfig]]
end

defp deps do
  [{:sweetconfig, github: "inbetgames/sweetconfig"}]
end
```

Now you can read configuration at any point in your app like this:

```elixir
Sweetconfig.get :somekey
Sweetconfig.get [:somekey, :somesubkey]
Sweetconfig.get :whatever, :default_value
```


## YAML syntax extensions

Sweetconfig extends YAML syntax in a non-conforming way to provide some
conveniences for Elixir.

```yaml
map:
 a: "keys are atoms"
 b-c: "unless they have non-identifier characters"

list:
 - "this is a binary"
 - 'this is a char list'
 - [these, are, atoms]
 - Elixir.Alias

implicit:
 - can
 - be ambiguous
```

The config file above will be parsed into the following Elixir data:

```elixir
%{
  map: %{
    :a => "keys are atoms",
    "b-c" => "unless they have non-identifier characters"
  },
  list: [
    "this is a binary",
    'this is a char list',
    [:these, :are, :atoms],
    Elixir.Alias
  ],
  implicit: [
    :can,
    "be ambiguous"
  ],
}
```


## Subscribing to changes

It is possible to get notifications when a certain config value changes
during config reload.

```elixir
path = [:root, :some, "nested", "value"]

# subscribe to all events: when the value at path is either changed, added, or
# removed
Sweetconfig.subscribe path, self()

# subscribe only to 'added' events
Sweetconfig.subscribe :something_else, [:added], self()

# assume this changes the value at the path above and adds a new key
# :something_else
Sweetconfig.Utils.load_configs

receive do
  {Sweetconfig.Pubsub, ^path, {:changed, old, new}} ->
    IO.puts "Changed value at path: #{inspect path}"
    IO.inspect old
    IO.inspect new
end

receive do
  {Sweetconfig.Pubsub, [:something_else]=path, {:added, new}} ->
    IO.puts "New value at path: #{inspect path}"
    IO.inspect new
end
```


## Updating application env

By default Sweetconfig keeps loaded configs in its private ETS table. It is
possible to make it write selected configs to application env by passing a
corresponding option to `load_configs`

```elixir
Sweetconfig.load_configs(write_to_env: [app_name: [:key1, :key2]])

value = Application.get_env(:app_name, :key1)
```

or by setting the global `write_to_env` option in `config.exs`

```elixir
config :sweetconfig, write_to_env: [app_name: [:key1, :key2]]
```
