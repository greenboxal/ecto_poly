defmodule EctoPoly.SmsProvider do
  use EctoPoly, types: [twilio: EctoPoly.TwilioSmsProvider, test: EctoPoly.TestSmsProvider]
end
