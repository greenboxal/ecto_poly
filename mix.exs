defmodule EctoPoly.Mixfile do
  use Mix.Project

  @version "1.0.6"
  @name "Ecto Poly"
  @description "Polymorphic embeds for Ecto. Forked from ecto_poly to make it compatible with Ecto 3.5+."
  @github "https://github.com/tableturn/ecto_poly"

  def project(),
    do: [
      name: @name,
      description: @description,
      version: @version,
      elixir: "~> 1.5",
      app: :ecto_poly_armory,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      docs: docs()
    ]

  def application(),
    do: [extra_applications: [:logger]]

  defp deps(),
    do: [
      {:ecto, ">= 2.0.0"},
      {:postgrex, "~> 0.11", only: [:dev, :test]},
      {:ecto_sql, "~> 3.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.19", only: :docs},
      {:inch_ex, ">= 0.0.0", only: :docs}
    ]

  defp package(),
    do: [
      licenses: ["MIT"],
      maintainers: ["Pierre Martin", "Jean Parpaillon"],
      links: %{"Github" => @github}
    ]

  defp docs(),
    do: [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @github
    ]

  defp aliases,
    do: [test: ["ecto.create --quiet", "ecto.migrate", "test"]]

  defp elixirc_paths(:test),
    do: ["lib", "test/support"]

  defp elixirc_paths(_),
    do: ["lib"]
end
