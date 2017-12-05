defmodule EctoPoly.TestSmsChannel do
  use Ecto.Schema

  embedded_schema do
    field :number, :string
    field :provider, EctoPoly.SmsProvider
  end
end
