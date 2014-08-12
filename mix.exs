defmodule Sweetconfig.Mixfile do
  use Mix.Project

  def project do
    [app: :sweetconfig,
     version: "0.5.0-dev",
     elixir: "~> 0.14",
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
