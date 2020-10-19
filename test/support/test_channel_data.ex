defmodule EctoPoly.TestChannelData do
  use EctoPoly, types: [sms: EctoPoly.TestSmsChannel, email: EctoPoly.TestEmailChannel]
end
