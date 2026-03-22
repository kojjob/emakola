ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Emakola.Repo, :manual)

# Mox mocks
Mox.defmock(Emakola.HTTPClientMock, for: Emakola.HTTPClient)
