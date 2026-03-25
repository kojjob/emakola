ExUnit.start(exclude: [:pending])
Ecto.Adapters.SQL.Sandbox.mode(Emakola.Repo, :manual)

# Initialize ETS table for cart storage (used by session-based cart tests)
Emakola.Cart.CartStore.init()

# Mox mocks
Mox.defmock(Emakola.HTTPClientMock, for: Emakola.HTTPClient)
Mox.defmock(Emakola.Payments.PaystackClientMock, for: Emakola.Payments.PaystackClientBehaviour)
Mox.defmock(Emakola.SMSProviderMock, for: Emakola.Notifications.SMSProvider)
Mox.defmock(Emakola.WhatsAppProviderMock, for: Emakola.Notifications.WhatsAppProvider)
