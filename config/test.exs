use Mix.Config

config :ecto_poly, ecto_repos: [EctoPoly.TestRepo]

config :ecto_poly, EctoPoly.TestRepo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "postgres",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox
