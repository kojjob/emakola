ExUnit.start(exclude: [:pending, :pdf])
Ecto.Adapters.SQL.Sandbox.mode(Emakola.Repo, :manual)

# Note: carts are now Postgres-backed (cart_items table) — no ETS init needed.

# Mox mocks
Mox.defmock(Emakola.HTTPClientMock, for: Emakola.HTTPClient)
Mox.defmock(Emakola.Payments.PaystackClientMock, for: Emakola.Payments.PaystackClientBehaviour)
Mox.defmock(Emakola.Payments.HubtelClientMock, for: Emakola.Payments.HubtelClientBehaviour)
Mox.defmock(Emakola.SMSProviderMock, for: Emakola.Notifications.SMSProvider)
Mox.defmock(Emakola.WhatsAppProviderMock, for: Emakola.Notifications.WhatsAppProvider)
Mox.defmock(Emakola.WhatsAppChannelMock, for: Emakola.Notifications.Channels.WhatsAppBehaviour)
Mox.defmock(Emakola.SMSChannelMock, for: Emakola.Notifications.Channels.SMSBehaviour)
Mox.defmock(Emakola.StorageMock, for: Emakola.Storage)
Mox.defmock(Emakola.PushProviderMock, for: Emakola.Notifications.PushProvider)
Mox.defmock(Emakola.Content.GeneratorMock, for: Emakola.Content.Generator)
Mox.defmock(Emakola.AI.ProviderMock, for: Emakola.AI.Provider)
