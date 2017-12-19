defmodule EctoPoly.TwilioSmsProvider do
  use Ecto.Schema

  embedded_schema do
    field :key_id, :string
    field :key_secret, :string
    field :date, :utc_datetime
    field :dates, {:array, :naive_datetime}
    field :time_by_name, {:map, :time}
    field :price, :decimal
  end
end
