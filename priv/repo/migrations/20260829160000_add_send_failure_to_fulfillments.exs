defmodule Emakola.Repo.Migrations.AddSendFailureToFulfillments do
  @moduledoc """
  Makes a failed supplier notification visible to the merchant.

  Today a send failure lives only in `oban_jobs`. The worker burns three
  attempts, dead-letters, and the fulfilment sits `:pending` forever with the
  merchant never told the supplier did not hear. Given the production WhatsApp
  credentials are a placeholder, that is not a rare path — it is the normal one.

  `last_send_error` holds a LABEL, never the provider response body: that body
  can carry phone numbers and Meta account identifiers, which is exactly why
  `Channels.WhatsApp` logs "provider response omitted" rather than the payload.
  64 characters is enough for `"whatsapp:http_401"` and nowhere near enough to
  smuggle a payload into.
  """

  use Ecto.Migration

  def up do
    alter table(:fulfillments) do
      add(:last_send_error, :text)
      add(:last_send_error_at, :utc_datetime_usec)
    end
  end

  def down do
    alter table(:fulfillments) do
      remove(:last_send_error)
      remove(:last_send_error_at)
    end
  end
end
