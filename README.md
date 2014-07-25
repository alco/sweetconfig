Sweetconfig
===========

[![Build Status](https://travis-ci.org/d0rc/sweetconfig.png?branch=master "Build Status")](http://travis-ci.org/d0rc/sweetconfig)

Place configuration YAML files in `priv/` directory of your root application.
Add following section to your `config.exs` file:


```elixir
config :sweetconfig,
	app: :name_of_your_application
```

Include `:sweetconfig` into your app deps list.

Now you can read configuration at any point in your app like this:

```elixir
Sweetconfig.get :somekey
Sweetconfig.get [:somekey, :somesubkey]
Sweetconfig.get :whatever, :default_value
```


## Subscribing to changes

It is possible to get notifications when a certain config value has changed
during config reload.

```elixir
path = [:root, :some, "nested", "value"]
Sweetconfig.subscribe path, self()
Sweetconfig.Utils.load_configs  # assume this changes the value at the path above
receive do
  {Sweetconfig.Pubsub, ^path, {:changed, old, new}} ->
    IO.inspect old
    IO.inspect new
end
```
