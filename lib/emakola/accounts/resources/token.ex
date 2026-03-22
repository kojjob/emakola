defmodule Emakola.Accounts.Token do
  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(Emakola.Repo)
  end

  actions do
    defaults([:read, :destroy])
  end
end
