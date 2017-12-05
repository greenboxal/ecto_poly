defmodule EctoPoly.TestChannelData do
  alias EctoPoly, as: EP

  use EctoPoly, types: [
    sms: EP.TestSmsChannel,
    email: EP.TestEmailChannel,
  ]
end
