ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Emakola.Repo, :manual)

# Mox mocks
Mox.defmock(Emakola.HTTPClientMock, for: Emakola.HTTPClient)
Mox.defmock(Emakola.SMSProviderMock, for: Emakola.Notifications.SMSProvider)
Mox.defmock(Emakola.WhatsAppProviderMock, for: Emakola.Notifications.WhatsAppProvider)
