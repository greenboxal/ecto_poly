defmodule EctoPoly.Mixfile do
  use Mix.Project

  @version "1.0.1"
  @github "https://github.com/greenboxal/phoenix_bert"

  def project do
    [
      name: "Ecto Poly",
      description: "Polymorphic embeds for Ecto",
      version: @version,
      elixir: "~> 1.5",
      app: :ecto_poly,
      start_permanent: Mix.env == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ecto, "~> 2.0"},
      {:postgrex, "~> 0.11"},
      {:poison, "~> 3.0"},
      {:ex_doc, "~> 0.15", only: :docs},
      {:inch_ex, ">= 0.0.0", only: :docs},
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Jonathan Lima"],
      links: %{"Github" => @github}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @github
    ]
  end

  defp aliases do
    ["test": ["ecto.create --quiet", "ecto.migrate", "test"]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]
end
