defmodule EctoPoly.Mixfile do
  use Mix.Project

  @version "1.0.4"
  @github "https://github.com/greenboxal/phoenix_bert"

  def project do
    [
      name: "Ecto Poly",
      description: "Polymorphic embeds for Ecto",
      version: @version,
      elixir: "~> 1.5",
      app: :ecto_poly,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
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
      {:ecto, ">= 2.0.0"},
      {:postgrex, "~> 0.11", only: [:dev, :test]},
      {:jason, "~> 1.1"},
      {:ex_doc, "~> 0.19", only: :docs},
      {:inch_ex, ">= 0.0.0", only: :docs}
    ] ++ deps(Mix.env())
  end

  defp deps(env) when env in [:dev, :test], do: [{:ecto_sql, "~> 3.0"}]

  defp deps(_), do: [{:ecto, "~> 3.0"}]

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
    [test: ["ecto.create --quiet", "ecto.migrate", "test"]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
