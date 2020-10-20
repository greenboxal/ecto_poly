defmodule EctoPoly.TestSmsChannel do
  use Ecto.Schema

  alias Ecto.Changeset

  embedded_schema do
    field :number, :string
    field :provider, EctoPoly.SmsProvider
  end

  def changeset(struct, params) do
    struct
    |> Changeset.change()
    |> Changeset.cast(params, [:number])
    |> Changeset.validate_change(:number, fn
      :number, "0" <> _rest -> []
      :number, _ -> [number: "number must start with '0'"]
    end)
  end
end
