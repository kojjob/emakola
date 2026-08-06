defmodule Emakola.Mailer do
  use Swoosh.Mailer, otp_app: :emakola

  @default_domain "makola.io"

  @doc """
  Builds a Swoosh `from` tuple from the configured sending domain
  (`config :emakola, :mail_from_domain`, overridable at runtime via the
  `MAIL_FROM_DOMAIN` env var). Centralising it keeps the sending domain in
  one place, so a domain swap is a single env change rather than editing
  every mailer.

      from_address("Emakola")            #=> {"Emakola", "noreply@makola.io"}
      from_address("Emakola", "billing") #=> {"Emakola", "billing@makola.io"}
  """
  @spec from_address(String.t(), String.t()) :: {String.t(), String.t()}
  def from_address(name, local_part \\ "noreply") do
    domain = Application.get_env(:emakola, :mail_from_domain, @default_domain)
    {name, "#{local_part}@#{domain}"}
  end
end
