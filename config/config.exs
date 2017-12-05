use Mix.Config

config :ecto_poly, ecto_repos: []

if Mix.env == :test do
  import_config "test.exs"
end

