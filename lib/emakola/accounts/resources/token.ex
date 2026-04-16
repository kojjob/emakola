defmodule Emakola.Accounts.Token do
  @moduledoc "Authentication token resource backing magic-link and password-reset flows via AshAuthentication."
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
