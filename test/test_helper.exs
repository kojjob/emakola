ExUnit.start(exclude: [:pending, :pdf])
Ecto.Adapters.SQL.Sandbox.mode(Emakola.Repo, :manual)

# Initialize ETS table for cart storage (used by session-based cart tests)
Emakola.Cart.CartStore.init()

# Mox mocks
Mox.defmock(Emakola.HTTPClientMock, for: Emakola.HTTPClient)
Mox.defmock(Emakola.Payments.PaystackClientMock, for: Emakola.Payments.PaystackClientBehaviour)
Mox.defmock(Emakola.Payments.HubtelClientMock, for: Emakola.Payments.HubtelClientBehaviour)
Mox.defmock(Emakola.SMSProviderMock, for: Emakola.Notifications.SMSProvider)
Mox.defmock(Emakola.WhatsAppProviderMock, for: Emakola.Notifications.WhatsAppProvider)
Mox.defmock(Emakola.WhatsAppChannelMock, for: Emakola.Notifications.Channels.WhatsAppBehaviour)
Mox.defmock(Emakola.SMSChannelMock, for: Emakola.Notifications.Channels.SMSBehaviour)
Mox.defmock(Emakola.StorageMock, for: Emakola.Storage)
