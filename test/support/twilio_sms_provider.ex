defmodule EctoPoly.TwilioSmsProvider do
  use Ecto.Schema

  embedded_schema do
    field :key_id, :string
    field :key_secret, :string
  end
end
