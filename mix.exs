defmodule Sweetconfig.Mixfile do
  use Mix.Project

  def project do
    [app: :sweetconfig,
     version: "0.0.1",
     elixir: "~> 0.14.0",
     deps: deps]
  end

  def application do
    [applications: [:yamler],
     mod: {Sweetconfig, []}]
  end

  defp deps do
    [
      {:yamler, github: "alco/yamler", branch: "elixir-types"}
    ]
  end
end
