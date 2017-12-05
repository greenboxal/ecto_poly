defmodule EctoPoly.TestRepo.Migrations.AddTestSchema do
  use Ecto.Migration

  def change do
    create table("test_schema") do
      add :channel, :jsonb

      timestamps()
    end
  end
end
