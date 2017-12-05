defmodule EctoPoly.TestCase do
  use ExUnit.CaseTemplate, async: true

  setup tags do
    ensure_started!()
    
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoPoly.TestRepo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(EctoPoly.TestRepo, {:shared, self()})
    end

    :ok
  end

  defp ensure_started!() do
    Mix.Ecto.ensure_started(EctoPoly.TestRepo, [])
  end
end
